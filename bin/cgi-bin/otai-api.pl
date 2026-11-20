#!/usr/bin/perl
# --
# bin/cgi-bin/otai-api.pl
# Copyright (C) Softoft, Tobias A. Bueck
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the GNU General Public License version 3 (GPL-3.0).
# --

use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/../..";
use lib "$RealBin/../../Kernel/cpan-lib";
use lib "$RealBin/../../Custom";

use Kernel::System::ObjectManager;

local $Kernel::OM = Kernel::System::ObjectManager->new();

$Kernel::OM->Get('Kernel::System::OpenTicketAIConnector::Rest')->Run();
