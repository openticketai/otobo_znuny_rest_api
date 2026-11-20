# --
# Kernel/System/OpenTicketAIConnector/Catalog.pm
# Copyright (C) Softoft, Tobias A. Bueck
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the GNU General Public License version 3 (GPL-3.0).
# --

package Kernel::System::OpenTicketAIConnector::Catalog;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::CustomerCompany',
    'Kernel::System::CustomerUser',
    'Kernel::System::DynamicField',
    'Kernel::System::Group',
    'Kernel::System::Log',
    'Kernel::System::Priority',
    'Kernel::System::Queue',
    'Kernel::System::Service',
    'Kernel::System::State',
    'Kernel::System::SysConfig',
    'Kernel::System::Type',
    'Kernel::System::User',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub _NamedList {
    my ( $Self, $ObjectName, $ListMethod, $GetMethod ) = @_;

    my $Object = $Kernel::OM->Get($ObjectName);
    my %List   = $Object->$ListMethod( Valid => 0 );
    my @Items;
    for my $ID ( sort { $a <=> $b } keys %List ) {
        my %Row = $Object->$GetMethod(
            ID         => $ID,
            PriorityID => $ID,
            UserID     => 1,
        );
        next if !%Row;
        push @Items, {
            ID      => $ID + 0,
            Name    => $Row{Name} // $List{$ID},
            Comment => $Row{Comment} // '',
            Valid   => ( ( $Row{ValidID} // 1 ) == 1 ) ? 1 : 0,
        };
    }
    return { Item => \@Items };
}

sub Queues {
    my ( $Self, %Param ) = @_;
    return $Self->_NamedList( 'Kernel::System::Queue', 'QueueList', 'QueueGet' );
}

sub States {
    my ( $Self, %Param ) = @_;
    return $Self->_NamedList( 'Kernel::System::State', 'StateList', 'StateGet' );
}

sub Priorities {
    my ( $Self, %Param ) = @_;
    return $Self->_NamedList( 'Kernel::System::Priority', 'PriorityList', 'PriorityGet' );
}

sub Types {
    my ( $Self, %Param ) = @_;

    my $TypeObject = eval { $Kernel::OM->Get('Kernel::System::Type') };
    return { Item => [] } if !$TypeObject;
    return $Self->_NamedList( 'Kernel::System::Type', 'TypeList', 'TypeGet' );
}

sub Services {
    my ( $Self, %Param ) = @_;

    my $ServiceObject = eval { $Kernel::OM->Get('Kernel::System::Service') };
    return { Item => [] } if !$ServiceObject;
    my %List = $ServiceObject->ServiceList(
        Valid  => 0,
        UserID => $Param{UserID} || 1,
    );
    my @Items;
    for my $ID ( sort { $a <=> $b } keys %List ) {
        push @Items, {
            ID      => $ID + 0,
            Name    => $List{$ID},
            Comment => '',
            Valid   => 1,
        };
    }
    return { Item => \@Items };
}

sub _Dropdown {
    my ( $Self, $FieldType ) = @_;

    return 0 if !$FieldType;
    return 1 if $FieldType eq 'Dropdown' || $FieldType eq 'Multiselect';
    return 1 if $FieldType eq 'Einzelauswahl' || $FieldType eq 'Mehrfachauswahl';
    return 0;
}

sub DynamicFields {
    my ( $Self, %Param ) = @_;

    my $List = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid      => 0,
        ObjectType => ['Ticket'],
    ) || [];
    my @Items;
    for my $Field ( @{$List} ) {
        next if ref $Field ne 'HASH';
        my $FieldType = $Field->{FieldType} // '';
        push @Items, {
            Name       => $Field->{Name} // '',
            Label      => $Field->{Label} // $Field->{Name} // '',
            FieldType  => $FieldType,
            Valid      => ( ( $Field->{ValidID} // 1 ) == 1 ) ? 1 : 0,
            IsDropdown => $Self->_Dropdown($FieldType) ? 1 : 0,
            Comment    => $Field->{Comment} // '',
        };
    }
    return { Item => \@Items };
}

sub DynamicFieldValues {
    my ( $Self, %Param ) = @_;

    my $Name = $Param{Name} || '';
    return { Item => [] } if $Name eq '';

    my $Field = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet( Name => $Name );
    my $Values = {};
    if ( ref $Field eq 'HASH' && ref $Field->{Config} eq 'HASH' ) {
        $Values = $Field->{Config}->{PossibleValues} || {};
    }
    my @Items;
    for my $Key ( sort keys %{$Values} ) {
        push @Items, {
            Key   => "$Key",
            Value => $Values->{$Key} // "$Key",
        };
    }
    return { Item => \@Items };
}

sub Agents {
    my ( $Self, %Param ) = @_;

    my %Users = $Kernel::OM->Get('Kernel::System::User')->UserList(
        Type  => 'Short',
        Valid => 1,
    );
    my %Skip = map { $_ => 1 } qw(otai-webservice open_ticket_ai);
    my @Items;
    my $Count = 0;
    for my $ID ( sort { $a <=> $b } keys %Users ) {
        my $Login = $Users{$ID} || '';
        next if $Skip{$Login};
        $Count++;
        push @Items, {
            ID    => $ID + 0,
            Login => $Login,
        };
    }
    return {
        Count => $Count,
        Item  => \@Items,
    };
}

sub CustomerCompanies {
    my ( $Self, %Param ) = @_;

    my $Object = eval { $Kernel::OM->Get('Kernel::System::CustomerCompany') };
    return { Item => [] } if !$Object;
    my %List = $Object->CustomerCompanyList( Valid => 1 );
    my @Items;
    for my $ID ( sort keys %List ) {
        push @Items, {
            ID   => "$ID",
            Name => $List{$ID} || "$ID",
        };
    }
    return { Item => \@Items };
}

sub CustomerUsers {
    my ( $Self, %Param ) = @_;

    my $Object = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my %List   = $Object->CustomerUserList( Valid => 1 );
    my @Items;
    for my $Login ( sort keys %List ) {
        push @Items, {
            ID   => "$Login",
            Name => $List{$Login} || "$Login",
        };
    }
    return { Item => \@Items };
}

sub ConfigItems {
    my ( $Self, %Param ) = @_;

    my $UserID = $Param{UserID} || return;
    my $Object = eval { $Kernel::OM->Get('Kernel::System::ITSMConfigItem') };
    return if !$Object || !$Object->can('ConfigItemSearch');

    my @IDs = $Object->ConfigItemSearch(
        Result     => 'ARRAY',
        UserID     => $UserID,
        Permission => 'ro',
        SortBy     => 'ConfigItemID',
        OrderBy    => 'Up',
        Limit      => 1000000,
    );
    my @Items;
    for my $ID (@IDs) {
        my $Item = $Object->ConfigItemGet(
            ConfigItemID  => $ID,
            DynamicFields => 0,
        );
        next if ref $Item ne 'HASH';
        push @Items, {
            ConfigItemID => ( $Item->{ConfigItemID} || $ID ) + 0,
            Number       => $Item->{Number} || '',
            Name         => $Item->{Name} || '',
            ClassID      => ( $Item->{ClassID} || 0 ) + 0,
            Class        => $Item->{Class} || '',
            DeplState    => $Item->{DeplState} || '',
            InciState    => $Item->{InciState} || '',
            CreateTime   => $Item->{CreateTime} || '',
            ChangeTime   => $Item->{ChangeTime} || '',
        };
    }
    return { Item => \@Items };
}

sub _FAQ {
    my ( $Self, %Param ) = @_;

    my $FAQObject = eval { $Kernel::OM->Get('Kernel::System::FAQ') };
    return if !$FAQObject || $@;
    return $FAQObject;
}

sub _FaqLink {
    my ( $Self, $ItemID ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $HttpType     = $ConfigObject->Get('HttpType') || 'http';
    my $FQDN         = $ConfigObject->Get('FQDN') || '';
    my $ScriptAlias  = $ConfigObject->Get('ScriptAlias') || '';
    $ScriptAlias =~ s{^/+}{};
    $ScriptAlias =~ s{/+$}{};
    my $Path = 'customer.pl?Action=CustomerFAQZoom;ItemID=' . $ItemID;
    $Path = $ScriptAlias . '/' . $Path if $ScriptAlias;
    my $URL = $FQDN ? $HttpType . '://' . $FQDN . '/' . $Path : '/' . $Path;
    return ( $Path, $URL );
}

sub _Snippet {
    my ( $Self, $HTML ) = @_;

    return '' if !defined $HTML || $HTML eq '';
    my $Text = "$HTML";
    $Text =~ s{<[^>]+>}{}gs;
    $Text =~ s{\s+}{ }gs;
    $Text =~ s{^\s+|\s+$}{}g;
    $Text = substr( $Text, 0, 397 ) . '...' if length $Text > 400;
    return $Text;
}

sub Faqs {
    my ( $Self, %Param ) = @_;

    my $FAQObject = $Self->_FAQ();
    if ( !$FAQObject ) {
        return {
            Status  => 'faq_unavailable',
            Message => 'FAQ package is not installed or not loadable.',
            Item    => [],
        };
    }

    my $Query = $Param{What} || '*';
    $Query =~ s{^\s+|\s+$}{}g;
    $Query = '*' if $Query eq '';
    my $What = $Query;
    $What = '*' . $What . '*' if $What !~ m{[\*\?]};

    my $Limit = $Param{Limit} || 5;
    $Limit = 5  if $Limit !~ m{\A\d+\z} || $Limit < 1;
    $Limit = 20 if $Limit > 20;

    my @StateTypeNames = qw(public external internal);
    if ( $Param{Visibility} ) {
        @StateTypeNames = grep { m{\A(?:public|external|internal)\z} }
            map { lc } split /\s*,\s*/, $Param{Visibility};
        @StateTypeNames = qw(public external) if !@StateTypeNames;
    }

    my $InterfaceName = 'public';
    $InterfaceName = 'internal' if grep { $_ eq 'internal' } @StateTypeNames;
    $InterfaceName = 'external' if $InterfaceName eq 'public' && grep { $_ eq 'external' } @StateTypeNames;

    my $UserID    = $Param{UserID} || 1;
    my $Interface = $FAQObject->StateTypeGet(
        Name   => $InterfaceName,
        UserID => $UserID,
    );
    my $States = $FAQObject->StateTypeList(
        Types  => \@StateTypeNames,
        UserID => $UserID,
    );
    my @ItemIDs = $FAQObject->FAQSearch(
        Number           => '',
        Title            => '',
        What             => $What,
        Keyword          => '',
        OrderBy          => ['FAQID'],
        OrderByDirection => ['Down'],
        Limit            => $Limit,
        UserID           => $UserID,
        States           => $States,
        Interface        => $Interface,
    );

    my @Items;
    for my $ItemID (@ItemIDs) {
        my %FAQ = $FAQObject->FAQGet(
            ItemID     => $ItemID,
            ItemFields => 1,
            UserID     => $UserID,
        );
        next if !%FAQ;
        my ( $Path, $URL ) = $Self->_FaqLink($ItemID);
        push @Items, {
            ID      => $ItemID + 0,
            Number  => $FAQ{Number} // '',
            Title   => $FAQ{Title}  // '',
            Snippet => $Self->_Snippet( $FAQ{Field1} // '' ),
            URL     => $URL,
            Path    => $Path,
            State   => $FAQ{State} // '',
            Field1  => $FAQ{Field1} // '',
        };
        last if @Items >= $Limit;
    }
    return {
        Status => 'ok',
        Query  => $Query,
        Item   => \@Items,
    };
}

sub FaqGet {
    my ( $Self, %Param ) = @_;

    my $FAQObject = $Self->_FAQ();
    if ( !$FAQObject ) {
        return {
            Status => 'faq_unavailable',
            Item   => [],
        };
    }
    my $ItemID = $Param{ID} || return { Status => 'not_found', Item => [] };
    my $UserID = $Param{UserID} || 1;
    my %FAQ    = $FAQObject->FAQGet(
        ItemID     => $ItemID,
        ItemFields => 1,
        UserID     => $UserID,
    );
    return { Status => 'not_found', Item => [] } if !%FAQ;
    my ( $Path, $URL ) = $Self->_FaqLink($ItemID);
    return {
        Status => 'ok',
        Item   => [
            {
                ID      => $ItemID + 0,
                Number  => $FAQ{Number} // '',
                Title   => $FAQ{Title}  // '',
                Snippet => $FAQ{Field1} // '',
                URL     => $URL,
                Path    => $Path,
                State   => $FAQ{State} // '',
                Field1  => $FAQ{Field1} // '',
            },
        ],
    };
}

sub FaqUpdate {
    my ( $Self, %Param ) = @_;

    my $FAQObject = $Self->_FAQ();
    return { Status => 'faq_unavailable', Item => [] } if !$FAQObject;

    my $ItemID = $Param{ID} || return { Status => 'not_found', Item => [] };
    my $UserID = $Param{UserID} || 1;
    my %FAQ    = $FAQObject->FAQGet(
        ItemID     => $ItemID,
        ItemFields => 1,
        UserID     => $UserID,
    );
    return { Status => 'not_found', Item => [] } if !%FAQ;

    my $Title = defined $Param{Title} ? $Param{Title} : $FAQ{Title};
    my $Field1 = defined $Param{Field1} ? $Param{Field1} : $FAQ{Field1};
    my $OK = $FAQObject->FAQUpdate(
        %FAQ,
        ItemID => $ItemID,
        Title  => $Title,
        Field1 => $Field1,
        UserID => $UserID,
    );
    return { Status => 'error', Item => [] } if !$OK;
    return $Self->FaqGet(
        ID     => $ItemID,
        UserID => $UserID,
    );
}

sub CreateDynamicField {
    my ( $Self, %Param ) = @_;

    my $Name  = $Param{Name} || '';
    my $Label = $Param{Label} || $Name;
    return if $Name eq '';

    my $Possible = $Param{PossibleValues};
    return if ref $Possible ne 'HASH' || !%{$Possible};

    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $Existing           = $DynamicFieldObject->DynamicFieldGet( Name => $Name );
    my $UserID             = $Param{UserID} || 1;
    my $FieldID;
    my $Created = 0;

    if ( IsHashRefWithData($Existing) && $Existing->{ID} ) {
        my $Config = { %{ $Existing->{Config} || {} } };
        $Config->{PossibleValues} = $Possible;
        $FieldID = $Existing->{ID};
        my $Updated = $DynamicFieldObject->DynamicFieldUpdate(
            %{$Existing},
            Label   => $Label,
            Config  => $Config,
            ValidID => 1,
            UserID  => $UserID,
            Reorder => 0,
        );
        return if !$Updated;
    }
    else {
        $FieldID = $DynamicFieldObject->DynamicFieldAdd(
            Name       => $Name,
            Label      => $Label,
            FieldOrder => 200,
            FieldType  => 'Dropdown',
            ObjectType => 'Ticket',
            Config     => {
                DefaultValue       => '',
                PossibleValues     => $Possible,
                TranslatableValues => 0,
            },
            ValidID => 1,
            UserID  => $UserID,
        );
        return if !$FieldID;
        $Created = 1;
    }

    my @Items;
    for my $Key ( sort keys %{$Possible} ) {
        push @Items, {
            Key   => "$Key",
            Value => $Possible->{$Key} // "$Key",
        };
    }
    return {
        Name           => $Name,
        Label          => $Label,
        FieldID        => $FieldID + 0,
        Created        => $Created,
        Item           => \@Items,
        EnabledScreens => [],
    };
}

1;
