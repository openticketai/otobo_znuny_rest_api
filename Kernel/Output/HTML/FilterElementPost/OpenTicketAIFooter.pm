package Kernel::Output::HTML::FilterElementPost::OpenTicketAIFooter;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless $Self, $Type;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    return 1 if ref $Param{Data} ne 'SCALAR';

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    return 1 if !$ConfigObject->Get('OpenTicketAIConnector::CustomerFooter::Enabled');
    return 1 if ${ $Param{Data} } =~ m{class="OpenTicketAIPrivacyFooter"};

    my $Organization = $ConfigObject->Get('Organization') || '';
    $Organization =~ s{\A\s+|\s+\z}{}g;
    if ( !$Organization || $Organization eq 'Example Company' ) {
        $Organization = 'your organization';
    }

    my $WebPath = $ConfigObject->Get('Frontend::WebPath') || '/otobo-web/';
    $WebPath .= '/' if $WebPath !~ m{/\z};

    my $Company = _HTMLEscape($Organization);
    my $LogoURL = _HTMLEscape( $WebPath . 'common/img/OpenTicketAI.svg' );
    my $ContainerStyle = 'box-sizing:border-box;max-width:1120px;margin:22px auto 8px;padding:18px 22px;border:1px solid rgba(78,191,254,.28);border-radius:16px;background:linear-gradient(135deg,rgba(78,191,254,.10),rgba(184,58,254,.08));box-shadow:0 8px 28px rgba(31,41,55,.08);color:#172033;';
    if ( ( $Param{TemplateFile} || '' ) eq 'CustomerLogin' ) {
        $ContainerStyle = 'box-sizing:border-box;position:fixed;top:24px;right:24px;z-index:1000;width:calc(100% - 48px);max-width:520px;margin:0;padding:18px 22px;border:1px solid rgba(255,255,255,.55);border-radius:16px;background:rgba(255,255,255,.94);box-shadow:0 12px 38px rgba(20,29,52,.22);color:#172033;backdrop-filter:blur(14px);';
    }

    my $Footer = <<"HTML";
<div class="OpenTicketAIPrivacyFooter" role="note" style="$ContainerStyle">
    <div style="display:flex;align-items:center;gap:16px;flex-wrap:wrap;">
        <a href="https://www.openticketai.com/" target="_blank" rel="noopener noreferrer" aria-label="OpenTicketAI website" style="display:inline-flex;align-items:center;gap:11px;color:#172033;text-decoration:none;">
            <img src="$LogoURL" width="44" height="44" alt="OpenTicketAI" style="display:block;width:44px;height:44px;" />
            <strong style="font-size:15px;line-height:1.35;">Private AI, powered by OpenTicketAI</strong>
        </a>
        <p style="flex:1 1 360px;margin:0;font-size:13px;line-height:1.55;color:#465166;">
            AI processing runs entirely in the private, on-premises environment operated by <strong>$Company</strong>. Your ticket data stays there.
        </p>
    </div>
</div>
HTML

    ${ $Param{Data} } =~ s{(<div\s+id=(['"])oooFooter\2>)}{$Footer$1}i;

    return 1;
}

sub _HTMLEscape {
    my ($Value) = @_;

    $Value =~ s{&}{&amp;}g;
    $Value =~ s{<}{&lt;}g;
    $Value =~ s{>}{&gt;}g;
    $Value =~ s{"}{&quot;}g;
    $Value =~ s{'}{&#39;}g;

    return $Value;
}

1;
