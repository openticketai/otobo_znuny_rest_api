# --
# Kernel/System/OpenTicketAIConnector/EventNotifyCommon.pm
# Copyright (C) Softoft, Tobias A. Bueck
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the GNU General Public License version 3 (GPL-3.0).
# --

package Kernel::System::OpenTicketAIConnector::EventNotifyCommon;

use strict;
use warnings;


our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::JSON',
    'Kernel::System::Log',
    'Kernel::System::SysConfig',
    'Kernel::System::OpenTicketAIConnector::Setup',
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub TicketWebhooksEnabled {
    my ( $Self, %Param ) = @_;

    return $Self->FlagEnabled('OpenTicketAIConnector::WebhookTicketEnabled');
}

sub FAQWebhooksEnabled {
    my ( $Self, %Param ) = @_;

    return $Self->FlagEnabled('OpenTicketAIConnector::WebhookFAQEnabled');
}

sub FlagEnabled {
    my ( $Self, $Name ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $Value        = $ConfigObject->Get($Name);
    return 1 if !defined $Value;
    return 0 if $Value eq '0' || $Value eq '';
    return 1;
}

sub IsConfigured {
    my ( $Self, %Param ) = @_;

    my $Secret = $Self->WebhookSecret();
    return 0 if !$Secret;
    return 1 if $Self->WebhookURL();

    if ( $Self->TicketWebhooksEnabled() && !$Self->RuntimeEventsURL() ) {
        return 0;
    }
    if ( $Self->FAQWebhooksEnabled() && !$Self->SearchEventsURL() ) {
        return 0;
    }

    return 1;
}

sub RuntimeEventsURL {
    my ( $Self, %Param ) = @_;

    return $Self->_SettingOrEnv(
        Setting => 'OpenTicketAIConnector::RuntimeEventsURL',
        Env     => 'OTAI_RUNTIME_EVENTS_URL',
    );
}

sub SearchEventsURL {
    my ( $Self, %Param ) = @_;

    return $Self->_SettingOrEnv(
        Setting => 'OpenTicketAIConnector::SearchEventsURL',
        Env     => 'OTAI_SEARCH_EVENTS_URL',
    );
}

sub WebhookURL {
    my ( $Self, %Param ) = @_;

    my $URL = $Self->_SettingOrEnv(
        Setting => 'OpenTicketAIConnector::WebhookURL',
        Env     => 'OTAI_WEBHOOK_URL',
    );
    return $URL if $URL;
    return '';
}

sub EventEnabled {
    my ( $Self, $EventType ) = @_;

    return 0 if !$EventType;
    return $Self->FlagEnabled( 'OpenTicketAIConnector::Event::' . $EventType );
}

sub SaveWebhookSecret {
    my ( $Self, %Param ) = @_;

    return $Self->_UpdateAndDeploy(
        UserID => $Param{UserID} || 1,
        Name   => 'OpenTicketAIConnector::WebhookSecret',
        Value  => $Param{Secret} // '',
    );
}

sub SaveWebhookScreen {
    my ( $Self, %Param ) = @_;

    my $UserID = $Param{UserID} || 1;
    my $Events = $Param{Events} || {};
    $Self->_UpdateAndDeploy(
        UserID => $UserID,
        Name   => 'OpenTicketAIConnector::WebhookURL',
        Value  => $Param{URL} || '',
    );
    for my $Event (qw(ticket_created ticket_attribute_changed ticket_deleted faq_changed)) {
        $Self->_UpdateAndDeploy(
            UserID => $UserID,
            Name   => 'OpenTicketAIConnector::Event::' . $Event,
            Value  => $Events->{$Event} ? 1 : 0,
        );
    }
    return 1;
}

sub _UpdateAndDeploy {
    my ( $Self, %Param ) = @_;

    my $Updated = $Self->_UpdateStringSetting(%Param);
    return 1 if !$Updated;

    my %DeployResult = $Kernel::OM->Get('Kernel::System::SysConfig')->ConfigurationDeploy(
        Comments    => 'OpenTicketAI webhook screen',
        UserID      => $Param{UserID} || 1,
        Force       => 1,
        AllSettings => 1,
    );
    return $DeployResult{Success} ? 1 : 0;
}

sub WebhookSecret {
    my ( $Self, %Param ) = @_;

    return $Self->_SettingOrEnv(
        Setting => 'OpenTicketAIConnector::WebhookSecret',
        Env     => 'OTAI_API_TOKEN',
    );
}

sub SplitEventsURL {
    my ( $Self, %Param ) = @_;

    my $URL = $Param{URL} || '';
    $URL =~ s{^\s+|\s+$}{}g;
    return if !$URL;

    if ( $URL !~ m{\Ahttps?://}i ) {
        return;
    }

    if ( $URL =~ m{\A(https?://[^/]+)(/.*)?\z}i ) {
        my $Host = $1;
        my $Path = $2 // '/';
        return ( Host => $Host, Controller => $Path );
    }

    return;
}

sub IsAPIUser {
    my ( $Self, %Param ) = @_;

    my $UserID = $Param{UserID} || 0;
    return 0 if !$UserID;
    return 1 if $Kernel::OM->Get('Kernel::System::OpenTicketAIConnector::Setup')->IsSystemUser(
        UserID => $UserID,
    );

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    my %User       = $UserObject->GetUserData( UserID => $UserID );
    my $Login      = $User{UserLogin} || '';
    return 0 if !$Login;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my @Candidates;

    my $EnvLogin = $ENV{OTAI_TICKETSYSTEM_USERNAME} // '';
    $EnvLogin =~ s{^\s+|\s+$}{}g;
    push @Candidates, $EnvLogin if $EnvLogin;

    my $CfgLogin = $ConfigObject->Get('OpenTicketAIConnector::AgentUserLogin') || '';
    $CfgLogin =~ s{^\s+|\s+$}{}g;
    push @Candidates, $CfgLogin if $CfgLogin;

    push @Candidates, 'otai-webservice', 'open_ticket_ai';

    my $Needle = lc $Login;
    for my $Candidate (@Candidates) {
        return 1 if $Needle eq lc $Candidate;
    }

    return 0;
}

sub ActingUserID {
    my ( $Self, %Param ) = @_;

    my $Data = $Param{Data} || {};
    return $Data->{UserID} if $Data->{UserID};

    if ( $Data->{TicketID} ) {
        my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
            TicketID => $Data->{TicketID},
            UserID   => 1,
        );
        return $Ticket{ChangeBy} if $Ticket{ChangeBy};
    }

    my $ItemID = $Self->SubjectID(
        From => 'faq',
        Data => $Data,
    );
    return if !$ItemID;

    my $FAQObject;
    eval {
        $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');
    };
    return if !$FAQObject || $@;

    my %FAQ = $FAQObject->FAQGet(
        ItemID => $ItemID,
        UserID => 1,
    );
    return $FAQ{ChangedBy} if $FAQ{ChangedBy};
    return $FAQ{CreatedBy} if $FAQ{CreatedBy};

    return;
}

sub SubjectID {
    my ( $Self, %Param ) = @_;

    my $From = $Param{From} || '';
    my $Data = $Param{Data} || {};

    if ( $From eq 'ticket' ) {
        return $Data->{TicketID} if $Data->{TicketID};
        return;
    }

    if ( $From eq 'faq' ) {
        my $ItemID = $Data->{ItemID} || $Data->{FAQID} || $Data->{FAQItemID};
        return $ItemID if defined $ItemID && $ItemID ne '';
    }

    return;
}

sub BuildSignedPayload {
    my ( $Self, %Param ) = @_;

    my $EventType = $Param{EventType} || '';
    my $Kind      = $Param{Kind}      || '';
    my $ID        = $Param{ID};
    my $Source    = $Param{SourceEvent} || '';
    my $ArticleID = $Param{ArticleID};
    my $Attribute = $Param{Attribute};
    my $Value     = $Param{Value};
    if ( !$EventType || !$Kind || !defined $ID || $ID eq '' ) {
        return {
            Success      => 0,
            ErrorMessage => 'Missing event_type, kind, or id',
        };
    }

    my $Secret = $Self->WebhookSecret();
    if ( !$Secret ) {
        return {
            Success      => 0,
            ErrorMessage => 'Webhook secret not configured',
        };
    }

    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');
    my $Payload = {
        event_type => $EventType,
        subject    => { kind => $Kind, id => "$ID" },
    };
    if ( $Kind eq 'ticket' ) {
        $Payload->{source_event} = "$Source";
        if ( defined $Attribute && $Attribute ne '' ) {
            $Payload->{attribute} = "$Attribute";
        }
        if ( defined $ArticleID && $ArticleID ne '' ) {
            $Payload->{article_id} = "$ArticleID";
        }
        if ( defined $Value && $Value ne '' ) {
            $Payload->{value} = "$Value";
        }
    }
    my $Body = $JSONObject->Encode(
        Data     => $Payload,
        SortKeys => 1,
    );
    if ( !defined $Body || $Body eq '' ) {
        return {
            Success      => 0,
            ErrorMessage => 'Failed to encode OTAI event payload',
        };
    }

    return {
        Success => 1,
        Payload => $Payload,
        Body    => $Body,
        Header  => {
            'Content-Type'  => 'application/json',
            'Authorization' => "Bearer $Secret",
        },
    };
}

sub PersistEnvSettings {
    my ( $Self, %Param ) = @_;

    my $UserID = $Param{UserID} || 1;

    my $RuntimeEnv = $ENV{OTAI_RUNTIME_EVENTS_URL} // '';
    $RuntimeEnv =~ s{^\s+|\s+$}{}g;
    my $SearchEnv = $ENV{OTAI_SEARCH_EVENTS_URL} // '';
    $SearchEnv =~ s{^\s+|\s+$}{}g;
    my $SecretEnv = $ENV{OTAI_API_TOKEN} // '';
    $SecretEnv =~ s{^\s+|\s+$}{}g;

    return 1 if !$RuntimeEnv && !$SearchEnv && !$SecretEnv;

    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $Updated         = 0;

    if ($RuntimeEnv) {
        $Updated++ if $Self->_UpdateStringSetting(
            Name   => 'OpenTicketAIConnector::RuntimeEventsURL',
            Value  => $RuntimeEnv,
            UserID => $UserID,
        );
    }

    if ($SearchEnv) {
        $Updated++ if $Self->_UpdateStringSetting(
            Name   => 'OpenTicketAIConnector::SearchEventsURL',
            Value  => $SearchEnv,
            UserID => $UserID,
        );
    }

    if ($SecretEnv) {
        $Updated++ if $Self->_UpdateStringSetting(
            Name   => 'OpenTicketAIConnector::WebhookSecret',
            Value  => $SecretEnv,
            UserID => $UserID,
        );
    }

    return 1 if !$Updated;

    my %DeployResult = $SysConfigObject->ConfigurationDeploy(
        Comments    => 'OpenTicketAI: configure ticket/FAQ event webhooks',
        UserID      => $UserID,
        Force       => 1,
        AllSettings => 1,
    );
    if ( !$DeployResult{Success} ) {
        my $Err = $DeployResult{Error} // 'unknown error';
        $LogObject->Log(
            Priority => 'error',
            Message  => "OpenTicketAIConnector: event webhook ConfigurationDeploy failed: $Err",
        );
        return;
    }

    $LogObject->Log(
        Priority => 'notice',
        Message  => 'OpenTicketAIConnector: configured event webhooks '
          . '(ticket → Runtime /events, FAQ → Search /events).',
    );

    return 1;
}

sub _SettingOrEnv {
    my ( $Self, %Param ) = @_;

    my $Setting = $Param{Setting} || '';
    my $Env     = $Param{Env}     || '';

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $Value = $ConfigObject->Get($Setting) || '';
    $Value =~ s{^\s+|\s+$}{}g;
    if ( !$Value && $Env ) {
        $Value = $ENV{$Env} // '';
        $Value =~ s{^\s+|\s+$}{}g;
    }

    return $Value;
}

sub _UpdateStringSetting {
    my ( $Self, %Param ) = @_;

    my $Name   = $Param{Name}   || return;
    my $Value  = $Param{Value}  // return;
    my $UserID = $Param{UserID} || 1;

    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');

    my %Setting = $SysConfigObject->SettingGet( Name => $Name );
    if ( !%Setting || !$Setting{Name} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "OpenTicketAIConnector: SysConfig setting '$Name' not found.",
        );
        return;
    }

    my $LockGUID = $SysConfigObject->SettingLock(
        Name   => $Name,
        Force  => 1,
        UserID => $UserID,
    );
    if ( !$LockGUID ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "OpenTicketAIConnector: could not lock SysConfig '$Name'.",
        );
        return;
    }

    my %UpdateResult = $SysConfigObject->SettingUpdate(
        Name              => $Name,
        IsValid           => 1,
        EffectiveValue    => $Value,
        ExclusiveLockGUID => $LockGUID,
        UserID            => $UserID,
    );

    $SysConfigObject->SettingUnlock( Name => $Name );

    if ( !$UpdateResult{Success} ) {
        my $Err = $UpdateResult{Error} // 'unknown error';
        $LogObject->Log(
            Priority => 'error',
            Message  => "OpenTicketAIConnector: SettingUpdate failed for '$Name': $Err",
        );
        return;
    }

    return 1;
}

1;
