# --
# Kernel/System/OpenTicketAIConnector/Setup.pm
# Copyright (C) Softoft, Tobias A. Bueck
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the GNU General Public License version 3 (GPL-3.0).
# --

package Kernel::System::OpenTicketAIConnector::Setup;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::GenericInterface::Webservice',
    'Kernel::System::Group',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::User',
    'Kernel::System::Valid',
);

our $DefaultAPIUserLogin = 'otai-webservice';

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Install {
    my ( $Self, %Param ) = @_;

    my $UserID = $Self->EnsureAPIUser();
    $Self->RemoveLegacyWebservices();

    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'notice',
        Message  => 'OpenTicketAIConnector setup: user='
            . ( $UserID ? $Self->APIUserLogin() : 'missing' ),
    );
    return $UserID ? 1 : 0;
}

sub Uninstall {
    my ( $Self, %Param ) = @_;

    $Self->RemoveLegacyWebservices();
    $Self->_InvalidateAPIUser();
    return 1;
}

sub APIUserLogin {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $Login        = $ConfigObject->Get('OpenTicketAIConnector::AgentUserLogin') || '';
    $Login =~ s{^\s+|\s+$}{}g;
    return $Login || $DefaultAPIUserLogin;
}

sub APIUserID {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('Kernel::System::User')->UserLookup(
        UserLogin => $Self->APIUserLogin(),
    ) || 0;
}

sub EnsureAPIUser {
    my ( $Self, %Param ) = @_;

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $Login      = $Self->APIUserLogin();
    my $Email      = $Kernel::OM->Get('Kernel::Config')->Get('OpenTicketAIConnector::AgentEmail') || '';
    $Email =~ s{^\s+|\s+$}{}g;
    $Email = $Login . '@openticketai.com' if !$Email;

    my %User = $UserObject->GetUserData(
        User  => $Login,
        Valid => 0,
    );
    my $UserID = $User{UserID};
    if ($UserID) {
        $Self->_EnsureAIAgentGroup( UserID => $UserID );
        $Self->_DropUsersGroup( UserID => $UserID );
        $Self->_MarkSystemUser( UserID => $UserID );
        return $UserID;
    }

    my $Password = $Kernel::OM->Get('Kernel::System::Main')->GenerateRandomString( Length => 32 );
    $UserID = $UserObject->UserAdd(
        UserTitle     => 'OTAI',
        UserFirstname => 'AI',
        UserLastname  => 'Agent',
        UserLogin     => $Login,
        UserPw        => $Password,
        UserEmail     => $Email,
        ValidID       => 1,
        ChangeUserID  => 1,
        UserID        => 1,
    );
    if ( !$UserID ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "OpenTicketAIConnector: failed to create API user '$Login'.",
        );
        return;
    }
    $Self->_EnsureAIAgentGroup( UserID => $UserID );
    $Self->_DropUsersGroup( UserID => $UserID );
    $Self->_MarkSystemUser( UserID => $UserID );
    return $UserID;
}

sub CreateSystemUser {
    my ( $Self, %Param ) = @_;

    my $Label = $Param{Label} || '';
    $Label =~ s{^\s+|\s+$}{}g;
    return if $Label eq '';

    my $Login = $Self->_UniqueLogin($Label);
    return if !$Login;

    my $First = $Label;
    $First = substr( $First, 0, 80 );
    my $Email    = $Login . '@openticketai.com';
    my $Password = $Kernel::OM->Get('Kernel::System::Main')->GenerateRandomString( Length => 32 );
    my $UserID   = $Kernel::OM->Get('Kernel::System::User')->UserAdd(
        UserTitle     => 'OTAI',
        UserFirstname => $First,
        UserLastname  => 'System',
        UserLogin     => $Login,
        UserPw        => $Password,
        UserEmail     => $Email,
        ValidID       => 1,
        ChangeUserID  => 1,
        UserID        => 1,
    );
    if ( !$UserID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "OpenTicketAIConnector: failed to create system user '$Login'.",
        );
        return;
    }
    $Self->_DropUsersGroup( UserID => $UserID );
    $Self->_MarkSystemUser( UserID => $UserID );
    return {
        UserID => $UserID,
        Login  => $Login,
        Label  => $Label,
    };
}

sub IsSystemUser {
    my ( $Self, %Param ) = @_;

    my $UserID = $Param{UserID} || 0;
    return 0 if !$UserID;
    my %Preferences = $Kernel::OM->Get('Kernel::System::User')->GetPreferences(
        UserID => $UserID,
    );
    return ( $Preferences{OTAISystemUser} || '' ) eq '1' ? 1 : 0;
}

sub SystemUserSummaries {
    my ( $Self, %Param ) = @_;

    $Self->EnsureAPIUser();
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    my $Types = $Kernel::OM->Get('Kernel::Config')->Get('System::Permission');
    $Types = [] if ref $Types ne 'ARRAY';
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');
    my @Rows;
    for my $UserID ( @{ $Self->_SystemUserIDs() } ) {
        my %User = $UserObject->GetUserData(
            UserID => $UserID,
            Valid  => 1,
        );
        next if !%User;
        my $Groups = $Self->_RightsRows(
            Types => $Types,
            Fetch => sub {
                my ($Type) = @_;
                return {
                    $GroupObject->PermissionUserGroupGet(
                        UserID => $UserID,
                        Type   => $Type,
                    ),
                };
            },
        );
        my $Roles = $Self->_RoleRows(
            UserID      => $UserID,
            Types       => $Types,
            GroupObject => $GroupObject,
        );
        my $Fullname = $User{UserFullname} || '';
        if ( $Fullname eq '' ) {
            $Fullname = join ' ', grep {$_} ( $User{UserFirstname}, $User{UserLastname} );
        }
        push @Rows, {
            UserID   => $UserID,
            Login    => $User{UserLogin} || '',
            Fullname => $Fullname,
            Groups   => $Self->_RightLabel($Groups),
            Roles    => $Self->_RoleLabel($Roles),
        };
    }
    @Rows = sort { lc( $a->{Login} ) cmp lc( $b->{Login} ) } @Rows;
    return \@Rows;
}

sub APIUserProfile {
    my ( $Self, %Param ) = @_;

    my $UserID = $Self->EnsureAPIUser() || 0;
    return if !$UserID;

    my %User = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $UserID,
    );
    return if !%User;

    my $Types = $Kernel::OM->Get('Kernel::Config')->Get('System::Permission');
    $Types = [] if ref $Types ne 'ARRAY';
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');
    my $Fullname = $User{UserFullname} || '';
    if ( $Fullname eq '' ) {
        $Fullname = join ' ', grep {$_} ( $User{UserFirstname}, $User{UserLastname} );
    }

    return {
        UserID   => $UserID,
        Login    => $User{UserLogin} || '',
        Fullname => $Fullname,
        Email    => $User{UserEmail} || '',
        Groups   => $Self->_RightsRows(
            Types => $Types,
            Fetch => sub {
                my ($Type) = @_;
                return {
                    $GroupObject->PermissionUserGroupGet(
                        UserID => $UserID,
                        Type   => $Type,
                    ),
                };
            },
        ),
        Roles => $Self->_RoleRows(
            UserID      => $UserID,
            Types       => $Types,
            GroupObject => $GroupObject,
        ),
    };
}

sub RemoveLegacyWebservices {
    my ( $Self, %Param ) = @_;

    my $WebserviceObject = eval { $Kernel::OM->Get('Kernel::System::GenericInterface::Webservice') };
    return 1 if !$WebserviceObject;

    my $List = $WebserviceObject->WebserviceList( Valid => 0 ) || {};
    my %Want = map { $_ => 1 } qw(OpenTicketAI OpenTicketAI-RuntimeEvents OpenTicketAI-SearchEvents);
    for my $ID ( keys %{$List} ) {
        my $Name = $List->{$ID} || '';
        next if !$Want{$Name};
        $WebserviceObject->WebserviceDelete(
            ID     => $ID,
            UserID => 1,
        );
    }
    return 1;
}

sub _EnsureAIAgentGroup {
    my ( $Self, %Param ) = @_;

    my $UserID = $Param{UserID} || return;
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');
    my %ByName      = reverse $GroupObject->GroupList( Valid => 0 );
    my $GroupID     = $ByName{'ai-agent'};
    if ( !$GroupID ) {
        $GroupID = $GroupObject->GroupAdd(
            Name    => 'ai-agent',
            Comment => 'OTAI API agent',
            ValidID => 1,
            UserID  => 1,
        );
    }
    return if !$GroupID;
    $GroupObject->PermissionGroupUserAdd(
        GID        => $GroupID,
        UID        => $UserID,
        Permission => { rw => 1 },
        UserID     => 1,
    );
    return $GroupID;
}

sub _MarkSystemUser {
    my ( $Self, %Param ) = @_;

    my $UserID = $Param{UserID} || return;
    return $Kernel::OM->Get('Kernel::System::User')->SetPreferences(
        UserID => $UserID,
        Key    => 'OTAISystemUser',
        Value  => '1',
    );
}

sub _SystemUserIDs {
    my ( $Self, %Param ) = @_;

    my $UserObject  = $Kernel::OM->Get('Kernel::System::User');
    my $Table       = $UserObject->{PreferencesTable}        || 'user_preferences';
    my $KeyColumn   = $UserObject->{PreferencesTableKey}     || 'preferences_key';
    my $ValueColumn = $UserObject->{PreferencesTableValue}   || 'preferences_value';
    my $UserColumn  = $UserObject->{PreferencesTableUserID}  || 'user_id';
    my $Key         = 'OTAISystemUser';
    my $Value       = '1';
    my $DB          = $Kernel::OM->Get('Kernel::System::DB');
    return [] if !$DB->Prepare(
        SQL  => "SELECT $UserColumn FROM $Table WHERE $KeyColumn = ? AND $ValueColumn = ?",
        Bind => [ \$Key, \$Value ],
    );
    my @IDs;
    while ( my @Row = $DB->FetchrowArray() ) {
        push @IDs, $Row[0] if $Row[0];
    }
    return \@IDs;
}

sub _UniqueLogin {
    my ( $Self, $Label ) = @_;

    my $Base = lc $Label;
    $Base =~ s{[^a-z0-9]+}{-}g;
    $Base =~ s{^-+|-+$}{}g;
    $Base = 'agent' if $Base eq '';
    $Base = "otai-$Base" if $Base !~ m{\Aotai-};
    $Base = substr( $Base, 0, 40 );

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    my $Login      = $Base;
    my $Number     = 2;
    while ( $UserObject->UserLoginExistsCheck( UserLogin => $Login ) ) {
        $Login = $Base . '-' . $Number;
        $Number++;
        return if $Number > 50;
    }
    return $Login;
}

sub _RightLabel {
    my ( $Self, $Rows ) = @_;

    my @Names = map { $_->{Name} . ' (' . $_->{Rights} . ')' } @{ $Rows || [] };
    return join ', ', @Names;
}

sub _RoleLabel {
    my ( $Self, $Rows ) = @_;

    my @Names;
    for my $Role ( @{ $Rows || [] } ) {
        my $Groups = join ', ', map { $_->{Name} } @{ $Role->{Groups} || [] };
        push @Names, $Groups ? "$Role->{Name} ($Groups)" : $Role->{Name};
    }
    return join ', ', @Names;
}

sub _DropUsersGroup {
    my ( $Self, %Param ) = @_;

    my $UserID = $Param{UserID} || return;
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');
    my $GroupID     = $GroupObject->GroupLookup( Group => 'users' );
    return 1 if !$GroupID;

    return $GroupObject->PermissionGroupUserAdd(
        GID        => $GroupID,
        UID        => $UserID,
        Permission => { rw => 0 },
        UserID     => 1,
    );
}

sub _RoleRows {
    my ( $Self, %Param ) = @_;

    my $GroupObject = $Param{GroupObject};
    my %Roles       = $GroupObject->PermissionUserRoleGet(
        UserID => $Param{UserID},
    );
    my @Rows;
    for my $RoleID ( sort { lc( $Roles{$a} ) cmp lc( $Roles{$b} ) } keys %Roles ) {
        push @Rows, {
            Name   => $Roles{$RoleID},
            Groups => $Self->_RightsRows(
                Types => $Param{Types},
                Fetch => sub {
                    my ($Type) = @_;
                    return {
                        $GroupObject->PermissionRoleGroupGet(
                            RoleID => $RoleID,
                            Type   => $Type,
                        ),
                    };
                },
            ),
        };
    }
    return \@Rows;
}

sub _RightsRows {
    my ( $Self, %Param ) = @_;

    my @Types = @{ $Param{Types} || [] };
    my %Seen;
    for my $Type (@Types) {
        my $Groups = $Param{Fetch}->($Type);
        next if ref $Groups ne 'HASH';
        for my $GroupID ( keys %{$Groups} ) {
            $Seen{$GroupID}{Name} = $Groups->{$GroupID};
            $Seen{$GroupID}{Rights}{$Type} = 1;
        }
    }

    my @Rows;
    for my $GroupID ( sort { lc( $Seen{$a}{Name} ) cmp lc( $Seen{$b}{Name} ) } keys %Seen ) {
        my $Rights = $Seen{$GroupID}{Rights};
        my $Label  = $Rights->{rw}
            ? 'rw'
            : join( ', ', grep { $Rights->{$_} } @Types );
        push @Rows, {
            Name   => $Seen{$GroupID}{Name},
            Rights => $Label,
        };
    }
    return \@Rows;
}

sub _InvalidateAPIUser {
    my ( $Self, %Param ) = @_;

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    my $UserID     = $Self->APIUserID();
    return 1 if !$UserID;
    my %User = $UserObject->GetUserData( UserID => $UserID );
    return 1 if !%User;
    my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');
    my $InvalidID   = $ValidObject->ValidLookup( Valid => 'invalid' );
    return 1 if !$InvalidID;
    $UserObject->UserUpdate(
        %User,
        ValidID      => $InvalidID,
        ChangeUserID => 1,
    );
    return 1;
}

1;
