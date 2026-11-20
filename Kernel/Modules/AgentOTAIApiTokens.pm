# --
# Kernel/Modules/AgentOTAIApiTokens.pm
# Copyright (C) Softoft, Tobias A. Bueck
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the GNU General Public License version 3 (GPL-3.0).
# --

package Kernel::Modules::AgentOTAIApiTokens;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::OpenTicketAIConnector::Token',
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
    my $Subaction    = $ParamObject->GetParam( Param => 'Subaction' ) || '';
    my $TokenOnce    = '';
    my $UserID       = $Self->{UserID};

    if ( $Subaction eq 'Generate' && $UserID ) {
        my $Hours = $ParamObject->GetParam( Param => 'Hours' );
        my $Label = $ParamObject->GetParam( Param => 'Label' ) || '';
        my $Issued = $TokenObject->Issue(
            Kind      => 'agent',
            Label     => $Label,
            UserID    => $UserID,
            ExpiresAt => $TokenObject->ExpiresFromHours($Hours),
        );
        $TokenOnce = $Issued->{Token} if $Issued;
    }
    elsif ( $Subaction eq 'Revoke' && $UserID ) {
        $TokenObject->Revoke(
            ID     => $ParamObject->GetParam( Param => 'ID' ),
            UserID => $UserID,
        );
    }

    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentOTAIApiTokens',
        Data         => {
            TokenList      => $TokenObject->List( Kind => 'agent', UserID => $UserID ),
            TokenOnce      => $TokenOnce,
            Hours          => $TokenObject->TTLHours() || '',
            ChallengeToken => $LayoutObject->{UserChallengeToken} || '',
        },
    );
    $Output .= $LayoutObject->Footer();
    return $Output;
}

1;
