# --
# Kernel/Modules/AdminOTAIApi.pm
# Copyright (C) Softoft, Tobias A. Bueck
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the GNU General Public License version 3 (GPL-3.0).
# --

package Kernel::Modules::AdminOTAIApi;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::OpenTicketAIConnector::Setup',
    'Kernel::System::OpenTicketAIConnector::Token',
    'Kernel::System::SysConfig',
    'Kernel::System::User',
    'Kernel::System::Web::Request',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TokenObject  = $Kernel::OM->Get('Kernel::System::OpenTicketAIConnector::Token');
    my $SetupObject  = $Kernel::OM->Get('Kernel::System::OpenTicketAIConnector::Setup');
    my $Subaction = $ParamObject->GetParam( Param => 'Subaction' ) || '';
    my $TokenOnce = '';
    my $TokenUser = '';
    my $Error     = '';

    if ( $Subaction eq 'SaveEnabled' || $Subaction eq 'Create' || $Subaction eq 'Revoke' ) {
        $LayoutObject->ChallengeTokenCheck();
    }

    if ( $Subaction eq 'SaveEnabled' ) {
        $Self->_SetEnabled( $ParamObject->GetParam( Param => 'ApiEnabled' ) ? 1 : 0 );
        return $LayoutObject->Redirect( OP => 'Action=AdminOTAIApi' );
    }
    elsif ( $Subaction eq 'Create' ) {
        my $Label    = $ParamObject->GetParam( Param => 'Label' ) || '';
        my $Lifetime = $ParamObject->GetParam( Param => 'Lifetime' ) || '';
        my $ExpiresAt = $TokenObject->ExpiresFromChoice($Lifetime);
        if ( !defined $ExpiresAt ) {
            $Error = 'Choose how long the token is valid.';
        }
        else {
            my $Created = $SetupObject->CreateSystemUser( Label => $Label );
            if ( !$Created ) {
                $Error = 'The system user could not be created.';
            }
            else {
                my $Issued = $TokenObject->Issue(
                    Kind      => 'api',
                    Label     => $Label,
                    UserID    => $Created->{UserID},
                    ExpiresAt => $ExpiresAt,
                );
                if ($Issued) {
                    $TokenOnce = $Issued->{Token};
                    $TokenUser = $Created->{Login};
                }
                else {
                    $Error = 'The system user was created, but the token was not.';
                }
            }
        }
    }
    elsif ( $Subaction eq 'Revoke' ) {
        $TokenObject->Revoke( ID => $ParamObject->GetParam( Param => 'ID' ) );
    }

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $Alias        = $ConfigObject->Get('ScriptAlias') || '';
    $Alias =~ s{^/+}{};
    my $DocsURL = '/' . $Alias . 'otai-api.pl/v1/docs';
    my $Enabled = $ConfigObject->Get('OpenTicketAIConnector::ApiEnabled');
    $Enabled = 1 if !defined $Enabled || $Enabled eq '';
    my $Lifetime = $Self->_SelectedLifetime($ParamObject);

    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminOTAIApi',
        Data         => {
            SystemUsers    => $Self->_SystemRows( $SetupObject, $TokenObject ),
            TokenOnce      => $TokenOnce,
            TokenUser      => $TokenUser,
            Error          => $Error,
            ApiEnabled     => $Enabled ? 1 : 0,
            DocsURL        => $DocsURL,
            Lifetime       => $Lifetime,
            Lifetimes      => $Self->_Lifetimes($Lifetime),
            ChallengeToken => $LayoutObject->{UserChallengeToken} || '',
        },
    );
    $Output .= $LayoutObject->Footer();
    return $Output;
}

sub _SystemRows {
    my ( $Self, $SetupObject, $TokenObject ) = @_;

    my @Rows;
    for my $User ( @{ $SetupObject->SystemUserSummaries() } ) {
        my $Tokens = $TokenObject->List(
            Kind   => 'api',
            UserID => $User->{UserID},
        );
        my @Active = grep { !$_->{Revoked} } @{ $Tokens || [] };
        my $Token  = $Active[0];
        for my $Extra ( @Active[ 1 .. $#Active ] ) {
            $TokenObject->Revoke( ID => $Extra->{ID} );
        }
        push @Rows, {
            %{$User},
            TokenID      => $Token ? $Token->{ID} : '',
            Expires      => $Token && $Token->{ExpiresAt} ? $Self->_Stamp( $Token->{ExpiresAt} ) : '',
            ExpiresNever => $Token && !$Token->{ExpiresAt} ? 1 : 0,
            LastUsed     => $Token ? $Self->_Stamp( $Token->{LastUsedAt} ) : '',
        };
    }
    return \@Rows;
}

sub _SelectedLifetime {
    my ( $Self, $ParamObject ) = @_;

    return $ParamObject->GetParam( Param => 'Lifetime' ) || '30d';
}

sub _Lifetimes {
    my ( $Self, $Selected ) = @_;

    my @Choices = (
        { Key => '7d',    Label => '7 days' },
        { Key => '30d',   Label => '30 days' },
        { Key => '90d',   Label => '90 days' },
        { Key => '1y',    Label => '1 year' },
        { Key => 'never', Label => 'Never' },
    );
    for my $Choice (@Choices) {
        $Choice->{Selected} = $Choice->{Key} eq $Selected ? 1 : 0;
    }
    return \@Choices;
}

sub _Stamp {
    my ( $Self, $Epoch ) = @_;

    return '' if !$Epoch || $Epoch !~ m{\A\d+\z};

    my $DateTimeObject = eval {
        $Kernel::OM->Create(
            'Kernel::System::DateTime',
            ObjectParams => {
                Epoch => $Epoch,
            },
        );
    };
    return $DateTimeObject->ToString() if $DateTimeObject;

    my $TimeObject = eval { $Kernel::OM->Get('Kernel::System::Time') };
    return '' if !$TimeObject;
    return $TimeObject->SystemTime2TimeStamp( SystemTime => $Epoch ) || '';
}

sub _SetEnabled {
    my ( $Self, $Value ) = @_;

    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
    my $Name            = 'OpenTicketAIConnector::ApiEnabled';
    my $LockGUID        = $SysConfigObject->SettingLock(
        Name   => $Name,
        Force  => 1,
        UserID => $Self->{UserID} || 1,
    );
    return if !$LockGUID;
    $SysConfigObject->SettingUpdate(
        Name              => $Name,
        IsValid           => 1,
        EffectiveValue    => $Value ? 1 : 0,
        ExclusiveLockGUID => $LockGUID,
        UserID            => $Self->{UserID} || 1,
    );
    $SysConfigObject->SettingUnlock( Name => $Name );
    $SysConfigObject->ConfigurationDeploy(
        Comments    => 'OpenTicketAI API on/off',
        UserID      => $Self->{UserID} || 1,
        Force       => 1,
        AllSettings => 1,
    );
    return 1;
}

1;
