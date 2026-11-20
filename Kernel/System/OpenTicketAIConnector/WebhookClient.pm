# --
# Kernel/System/OpenTicketAIConnector/WebhookClient.pm
# Copyright (C) Softoft, Tobias A. Bueck
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the GNU General Public License version 3 (GPL-3.0).
# --
# Ticket and FAQ event modules on OTOBO and Znuny call this client.
# --

package Kernel::System::OpenTicketAIConnector::WebhookClient;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::OpenTicketAIConnector::EventNotifyCommon',
    'Kernel::System::WebUserAgent',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub TicketWebhooksEnabled {
    my ( $Self, %Param ) = @_;

    return $Self->_Common()->TicketWebhooksEnabled();
}

sub FAQWebhooksEnabled {
    my ( $Self, %Param ) = @_;

    return $Self->_Common()->FAQWebhooksEnabled();
}

sub IsConfigured {
    my ( $Self, %Param ) = @_;

    return $Self->_Common()->IsConfigured();
}

sub ConfigureEventWebhooks {
    my ( $Self, %Param ) = @_;

    return $Self->_Common()->PersistEnvSettings(
        UserID => $Param{UserID} || 1,
    );
}

sub IsAPIUser {
    my ( $Self, %Param ) = @_;

    return $Self->_Common()->IsAPIUser( UserID => $Param{UserID} );
}

sub Notify {
    my ( $Self, %Param ) = @_;

    my $EventType = $Param{EventType} || '';
    my $Kind      = $Param{Kind}      || '';
    my $ID        = $Param{ID};
    return if !$EventType || !$Kind || !defined $ID || $ID eq '';
    return if !$Self->_Common()->EventEnabled($EventType);

    my $URL = $Self->_Common()->WebhookURL();
    if ( !$URL ) {
        $URL = $EventType eq 'faq_changed'
            ? $Self->_Common()->SearchEventsURL()
            : $Self->_Common()->RuntimeEventsURL();
    }
    if ( !$URL ) {
        return;
    }

    my $Signed = $Self->_Common()->BuildSignedPayload(
        EventType   => $EventType,
        Kind        => $Kind,
        ID          => $ID,
        SourceEvent => $Param{SourceEvent} || '',
        Attribute   => $Param{Attribute},
        ArticleID   => $Param{ArticleID},
        Value       => $Param{Value},
    );
    my $Result = $Self->_Post(
        URL       => $URL,
        Signed    => $Signed,
        EventType => $EventType,
        ID        => $ID,
    );
    return if !$Result->{Sent};

    return 1;
}

sub SendSample {
    my ( $Self, %Param ) = @_;

    my $URL = $Self->_Common()->WebhookURL();
    if ( !$URL ) {
        $URL = $Self->_Common()->RuntimeEventsURL();
    }
    if ( !$URL ) {
        return {
            Success      => 0,
            Sent         => 0,
            Status       => '',
            ErrorMessage => 'No receiver URL',
        };
    }

    my $Signed = $Self->_Common()->BuildSignedPayload(
        EventType   => 'ticket_attribute_changed',
        Kind        => 'ticket',
        ID          => 'sample',
        SourceEvent => 'ArticleCreate',
        Attribute   => 'notes',
        ArticleID   => '7',
    );
    return $Self->_Post(
        URL       => $URL,
        Signed    => $Signed,
        EventType => 'ticket_attribute_changed',
        ID        => 'sample',
    );
}

sub _Post {
    my ( $Self, %Param ) = @_;

    my $URL       = $Param{URL}       || '';
    my $Signed    = $Param{Signed}    || {};
    my $EventType = $Param{EventType} || '';
    my $ID        = $Param{ID};
    if ( !$Signed->{Success} ) {
        return {
            Success      => 0,
            Sent         => 0,
            Status       => '',
            ErrorMessage => $Signed->{ErrorMessage} || 'Could not build the event',
        };
    }

    my $UserAgentObject = $Kernel::OM->Get('Kernel::System::WebUserAgent');
    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');

    my @Header;
    for my $Name ( sort keys %{ $Signed->{Header} || {} } ) {
        push @Header, "$Name: $Signed->{Header}->{$Name}";
    }

    my %Response;
    eval {
        %Response = $UserAgentObject->Request(
            URL     => $URL,
            Type    => 'POST',
            Timeout => 5,
            Data    => $Signed->{Body},
            Header  => \@Header,
        );
        1;
    };
    if ($@) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "OpenTicketAI webhook POST failed: $@",
        );
        return {
            Success      => 0,
            Sent         => 0,
            Status       => '',
            ErrorMessage => 'The test POST failed.',
        };
    }

    my $Status = $Response{Status} || '';
    if ( $Status !~ m{^2} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "OpenTicketAI webhook HTTP $Status for $EventType id=$ID",
        );
        return {
            Success      => 0,
            Sent         => 1,
            Status       => $Status,
            ErrorMessage => 'The test POST failed.',
        };
    }

    return {
        Success      => 1,
        Sent         => 1,
        Status       => $Status,
        ErrorMessage => '',
    };
}

sub _Common {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('Kernel::System::OpenTicketAIConnector::EventNotifyCommon');
}

1;
