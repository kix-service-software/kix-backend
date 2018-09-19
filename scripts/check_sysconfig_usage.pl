#!/usr/bin/perl
# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib "$RealBin/../..";
use lib "$RealBin/../../Kernel/cpan-lib";
use lib "$RealBin/../../Custom";

use Kernel::System::ObjectManager;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'check_sysconfig_usage',
    },
);

my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
my $MainObject      = $Kernel::OM->Get('Kernel::System::Main');

my @FileList = $MainObject->DirectoryRead(
    Directory => $Kernel::OM->Get('Kernel::Config')->Get('Home'),
    Filter    => [ '*.pm', '*.pl', '*.t' ],
    Recursive => 1,
);

my %ConfigItemUsage;

my $Count = 0;
foreach my $File (sort @FileList) {
    next if $File =~ /\/ZZZAAuto\.pm/;

    print STDERR ++$Count . ": checking file $File...\n";

    my $Content = $MainObject->FileRead(
        Location => $File,
    );

    if ( !$$Content ) {
        print STDERR "unable to read file!\n";
        next;
    }

    foreach my $ConfigItem ( @{ $SysConfigObject->{XMLConfig} } ) {
        next if !$ConfigItem->{Name};

        my $Key = $ConfigItem->{Name};
        my $SubKey;

        if (!exists $ConfigItemUsage{$Key}) {
            $ConfigItemUsage{$Key} = {};
        }

        if ( $Key =~ /^(.*?)###(.*?)$/g ) {
            $Key = $1;
            $SubKey = $2;
        }

        if ( $$Content =~ /$Key/g ) {
            if ( $SubKey && $$Content =~ /$SubKey/g ) {
                print STDERR "    $ConfigItem->{Name}\n";
                $ConfigItemUsage{$ConfigItem->{Name}}->{$File} = 1;                
            }
            else {
                print STDERR "    $Key\n";                
                $ConfigItemUsage{$Key}->{$File} = 1;
            }
        }
    }
}

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
print Dumper(\%ConfigItemUsage);

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
