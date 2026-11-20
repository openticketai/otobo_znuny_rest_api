# --
# Kernel/System/OpenTicketAIConnector/AgentLoginBlock.pm
# Copyright (C) Softoft, Tobias A. Bueck
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the GNU General Public License version 3 (GPL-3.0).
# --

package Kernel::System::OpenTicketAIConnector::AgentLoginBlock;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::AuthSession',
    'Kernel::System::OpenTicketAIConnector::Setup',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $UserID = $Self->{UserID} || 0;
    return if !$UserID;

    return if !$Kernel::OM->Get('Kernel::System::OpenTicketAIConnector::Setup')->IsSystemUser(
        UserID => $UserID,
    );

    if ( $Self->{SessionID} ) {
        $Kernel::OM->Get('Kernel::System::AuthSession')->RemoveSessionID(
            SessionID => $Self->{SessionID},
        );
    }

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $Output       = $LayoutObject->Header(
        Title => 'API user',
        Type  => 'Small',
    );
    $Output .= $LayoutObject->Notify(
        Priority => 'Error',
        Info     => Translatable(
            'This account is an API user and cannot sign in to the agent interface.'
        ),
    );
    $Output .= $LayoutObject->Footer( Type => 'Small' );
    return $Output;
}

1;
