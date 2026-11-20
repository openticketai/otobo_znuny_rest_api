# --
# Kernel/Modules/AdminOTAIApiDocs.pm
# Copyright (C) Softoft, Tobias A. Bueck
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the GNU General Public License version 3 (GPL-3.0).
# --

package Kernel::Modules::AdminOTAIApiDocs;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
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
    my $Alias        = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias') || '';
    $Alias =~ s{^/+}{};

    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminOTAIApiDocs',
        Data         => {
            DocsURL => '/' . $Alias . 'otai-api.pl/v1/docs',
        },
    );
    $Output .= $LayoutObject->Footer();
    return $Output;
}

1;
