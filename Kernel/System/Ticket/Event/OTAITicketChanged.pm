# --
# Kernel/System/Ticket/Event/OTAITicketChanged.pm
# Copyright (C) Softoft, Tobias A. Bueck
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the GNU General Public License version 3 (GPL-3.0).
# --

package Kernel::System::Ticket::Event::OTAITicketChanged;

use strict;
use warnings;

use Kernel::System::OpenTicketAIConnector::TicketEventMap;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::OpenTicketAIConnector::WebhookClient',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Data     = $Param{Data} || {};
    my $TicketID = $Data->{TicketID} || $Param{TicketID};
    return 1 if !$TicketID;

    my $Client = $Kernel::OM->Get('Kernel::System::OpenTicketAIConnector::WebhookClient');
    return 1 if !$Client->TicketWebhooksEnabled();
    return 1 if $Client->IsAPIUser( UserID => $Param{UserID} );

    my $Event  = $Param{Event} || '';
    my $Mapped = Kernel::System::OpenTicketAIConnector::TicketEventMap::Map($Event);
    if ( !$Mapped ) {
        $Mapped = Kernel::System::OpenTicketAIConnector::TicketEventMap::ReviewActions(
            Event     => $Event,
            FieldName => $Data->{FieldName},
            OldValue  => $Data->{OldValue},
            Value     => $Data->{Value},
        );
    }
    return 1 if !$Mapped;

    $Client->Notify(
        EventType   => $Mapped->{event_type},
        Kind        => 'ticket',
        ID          => $TicketID,
        SourceEvent => $Event,
        Attribute   => $Mapped->{attribute},
        ArticleID   => $Data->{ArticleID},
        Value       => $Mapped->{value},
    );

    return 1;
}

1;
