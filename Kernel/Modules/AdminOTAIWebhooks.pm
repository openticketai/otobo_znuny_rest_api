# --
# Kernel/Modules/AdminOTAIWebhooks.pm
# Copyright (C) Softoft, Tobias A. Bueck
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the GNU General Public License version 3 (GPL-3.0).
# --

package Kernel::Modules::AdminOTAIWebhooks;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::OpenTicketAIConnector::EventNotifyCommon',
    'Kernel::System::OpenTicketAIConnector::Token',
    'Kernel::System::OpenTicketAIConnector::WebhookClient',
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
    my $Common       = $Kernel::OM->Get('Kernel::System::OpenTicketAIConnector::EventNotifyCommon');
    my $TokenObject  = $Kernel::OM->Get('Kernel::System::OpenTicketAIConnector::Token');
    my $Subaction    = $ParamObject->GetParam( Param => 'Subaction' ) || '';
    my $TokenOnce    = '';
    my $UserID       = $Self->{UserID} || 1;
    my $Tested       = 0;
    my $TestOk       = 0;
    my $TestStatus   = '';
    my $TestError    = '';

    if ( $Subaction eq 'Save' ) {
        $Common->SaveWebhookScreen(
            UserID => $UserID,
            URL    => $ParamObject->GetParam( Param => 'WebhookURL' ) || '',
            Events => {
                ticket_created           => $ParamObject->GetParam( Param => 'ticket_created' ) ? 1 : 0,
                ticket_attribute_changed => $ParamObject->GetParam( Param => 'ticket_attribute_changed' ) ? 1 : 0,
                ticket_deleted           => $ParamObject->GetParam( Param => 'ticket_deleted' ) ? 1 : 0,
                faq_changed              => $ParamObject->GetParam( Param => 'faq_changed' ) ? 1 : 0,
            },
        );
    }
    elsif ( $Subaction eq 'Generate' ) {
        my $Issued = $TokenObject->Issue(
            Kind   => 'webhook',
            Label  => 'webhook',
            UserID => 0,
        );
        if ($Issued) {
            $Common->SaveWebhookSecret(
                UserID => $UserID,
                Secret => $Issued->{Token},
            );
            $TokenOnce = $Issued->{Token};
        }
    }
    elsif ( $Subaction eq 'Revoke' ) {
        $TokenObject->Revoke( ID => $ParamObject->GetParam( Param => 'ID' ) );
        $Common->SaveWebhookSecret(
            UserID => $UserID,
            Secret => '',
        );
    }
    elsif ( $Subaction eq 'Test' ) {
        my $Result = $Kernel::OM->Get('Kernel::System::OpenTicketAIConnector::WebhookClient')->SendSample();
        $Tested     = 1;
        $TestOk     = $Result->{Success} ? 1 : 0;
        $TestStatus = $Result->{Status} || '';
        my $Message = $Result->{ErrorMessage} || '';
        if ( $Message eq 'No receiver URL' || $Message eq 'Webhook secret not configured' ) {
            $TestError = $Message;
        }
        elsif ( !$TestOk ) {
            $TestError = 'The test POST failed.';
        }
    }

    my $ActiveTokenID = '';
    for my $Row ( @{ $TokenObject->List( Kind => 'webhook' ) || [] } ) {
        next if $Row->{Revoked};
        $ActiveTokenID = $Row->{ID};
        last;
    }
    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminOTAIWebhooks',
        Data         => {
            WebhookURL               => $Common->WebhookURL() || '',
            RuntimeEventsURL         => $Common->RuntimeEventsURL() || '',
            SearchEventsURL          => $Common->SearchEventsURL() || '',
            ticket_created           => $Common->EventEnabled('ticket_created') ? 1 : 0,
            ticket_attribute_changed => $Common->EventEnabled('ticket_attribute_changed') ? 1 : 0,
            ticket_deleted           => $Common->EventEnabled('ticket_deleted') ? 1 : 0,
            faq_changed              => $Common->EventEnabled('faq_changed') ? 1 : 0,
            HasSecret                => $Common->WebhookSecret() ? 1 : 0,
            ActiveTokenID            => $ActiveTokenID,
            TokenOnce                => $TokenOnce,
            Tested                   => $Tested,
            TestOk                   => $TestOk,
            TestStatus               => $TestStatus,
            TestError                => $TestError,
            ChallengeToken           => $LayoutObject->{UserChallengeToken} || '',
        },
    );
    $Output .= $LayoutObject->Footer();
    return $Output;
}

1;
