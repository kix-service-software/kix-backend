#!/usr/bin/perl
# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin).'/../../';
use lib dirname($RealBin).'/../../Kernel/cpan-lib';

use Getopt::Std;
use File::Path qw(mkpath);

use Kernel::System::ObjectManager;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'kix-upgrade-to-18.pl',
    },
);

use vars qw(%INC);

my %Opts;
getopt( 'f', \%Opts );

# do everything that is necessary 
my $XMLFile = $Kernel::OM->Get('Kernel::Config')->Get('Home').'/scripts/database/update/kix-upgrade-to-18.xml';
if ( ! -f "$XMLFile" ) {
    print STDERR "File \"$XMLFile\" doesn't exist!"; 
    exit 1;
}
my $XML = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
    Location => $XMLFile,
);
if (!$XML) {
    print STDERR "Unable to read file \"$XMLFile\"!"; 
    exit 1;
}

my @XMLArray = $Kernel::OM->Get('Kernel::System::XML')->XMLParse(
    String => $XML,
);
if (!@XMLArray) {
    print STDERR "Unable to parse file \"$XMLFile\"!"; 
    exit 1;
}

my @SQL = $Kernel::OM->Get('Kernel::System::DB')->SQLProcessor(
    Database => \@XMLArray,
);
if (!@SQL) {
    print STDERR "Unable to create SQL from file \"$XMLFile\"!"; 
    exit 1;
}

for my $SQL (@SQL) {
    my $Result = $Kernel::OM->Get('Kernel::System::DB')->Do( 
        SQL => $SQL 
    );
    if (!$Result) {
        print STDERR "Unable to execute SQL from file \"$XMLFile\"!"; 
    }
}

# execute post SQL statements (indexes, constraints)
my @SQLPost = $Kernel::OM->Get('Kernel::System::DB')->SQLProcessorPost();
for my $SQL (@SQLPost) {
    my $Result = $Kernel::OM->Get('Kernel::System::DB')->Do( 
        SQL => $SQL 
    );
    if (!$Result) {
        print STDERR "Unable to execute POST SQL!"; 
    }
}

exit 1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
