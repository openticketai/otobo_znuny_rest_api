# --
# Kernel/System/OpenTicketAIConnector/TicketEventMap.pm
# Copyright (C) Softoft, Tobias A. Bueck
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the GNU General Public License version 3 (GPL-3.0).
# --
# Znuny / OTOBO hook names → OTAI ticket events.
# Keep in sync with otai_ts_connector.domain.ticket_event_map (OTRS keys).

package Kernel::System::OpenTicketAIConnector::TicketEventMap;

use strict;
use warnings;

my %ATTRIBUTE = (
    ArticleCreate          => 'notes',
    ArticleUpdate          => 'notes',
    ArticleSend            => 'notes',
    TicketTitleUpdate      => 'subject',
    TicketStateUpdate      => 'state',
    TicketQueueUpdate      => 'queue',
    TicketPriorityUpdate   => 'priority',
    TicketOwnerUpdate      => 'owner',
    TicketResponsibleUpdate => 'responsible',
    TicketLockUpdate       => 'lock',
    TicketTypeUpdate       => 'type',
    TicketServiceUpdate    => 'service',
    TicketCustomerUpdate   => 'customer',
    TicketPendingTimeUpdate => 'pending_time',
    TicketSLAUpdate        => 'sla',
    TicketMerge            => 'merge',
);

sub Map {
    my ($Event) = @_;
    return if !defined $Event || $Event eq '';

    if ( $Event eq 'TicketCreate' ) {
        return {
            event_type => 'ticket_created',
        };
    }
    if ( $Event eq 'TicketDelete' ) {
        return {
            event_type => 'ticket_deleted',
        };
    }

    my $Attribute = $ATTRIBUTE{$Event};
    return if !defined $Attribute;
    return {
        event_type => 'ticket_attribute_changed',
        attribute  => $Attribute,
    };
}

sub ReviewActions {
    my (%Param) = @_;

    return if ( $Param{Event} || '' ) ne 'TicketDynamicFieldUpdate';
    my $Name = $Param{FieldName} || '';
    return if $Name !~ /HumanReviewActions\z/;

    my $Delta = _JSONDelta( $Param{OldValue}, $Param{Value} );
    return if !defined $Delta || $Delta eq '' || $Delta eq '[]';
    return {
        event_type => 'ticket_attribute_changed',
        attribute  => $Name,
        value      => $Delta,
    };
}

sub _JSONDelta {
    my ( $Old, $New ) = @_;

    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');
    my $NewItems = eval { $JSONObject->Decode( Data => ( defined $New && $New ne '' ) ? $New : '[]' ) };
    my $OldItems = eval { $JSONObject->Decode( Data => ( defined $Old && $Old ne '' ) ? $Old : '[]' ) };
    $NewItems = [] if ref $NewItems ne 'ARRAY';
    $OldItems = [] if ref $OldItems ne 'ARRAY';
    my $Start = scalar @{$OldItems};
    $Start = scalar @{$NewItems} if $Start > scalar @{$NewItems};
    my @Delta = @{$NewItems}[ $Start .. $#{$NewItems} ];
    return $JSONObject->Encode( Data => \@Delta );
}

1;
