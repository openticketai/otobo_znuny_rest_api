# --
# Kernel/System/FAQ/Event/OTAIFAQChanged.pm
# Copyright (C) Softoft, Tobias A. Bueck
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the GNU General Public License version 3 (GPL-3.0).
# --

package Kernel::System::FAQ::Event::OTAIFAQChanged;

use strict;
use warnings;

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

    my $FAQObject;
    eval {
        $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');
    };
    return 1 if !$FAQObject || $@;

    my $Data   = $Param{Data} || {};
    my $ItemID = $Data->{ItemID} || $Data->{FAQID} || $Data->{FAQItemID}
        || $Param{ItemID} || $Param{FAQID};
    return 1 if !$ItemID;

    my $Client = $Kernel::OM->Get('Kernel::System::OpenTicketAIConnector::WebhookClient');
    return 1 if !$Client->FAQWebhooksEnabled();
    return 1 if $Client->IsAPIUser( UserID => $Param{UserID} );

    $Client->Notify(
        EventType => 'faq_changed',
        Kind      => 'faq',
        ID        => $ItemID,
    );

    return 1;
}

1;
