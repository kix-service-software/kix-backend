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

use Kernel::System::VariableCheck qw(:all);

use Kernel::System::ObjectManager;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new();

my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
my $MainObject      = $Kernel::OM->Get('Kernel::System::Main');

# read file with keys to remove
my $ContentRef = $MainObject->FileRead(
    Location => $ARGV[0],
    Result   => 'ARRAY'
);

if ( !$ContentRef ) {
    print STDERR "unable to read file $ARGV[0]!\n";
    return;
}

my @KeyList = @{$ContentRef};

# read all xml files
my @FileList = $MainObject->DirectoryRead(
    Directory => $Kernel::OM->Get('Kernel::Config')->Get('Home').'/Kernel/Config/Files',
    Filter    => [ '*.xml' ],
    Recursive => 1,
);

my %ConfigItemUsage;

foreach my $File (sort @FileList) {
    print STDERR "working file $File...\n";

    my $ContentRef = $MainObject->FileRead(
        Location => $File,
        Result   => 'ARRAY'
    );

    if ( !$ContentRef ) {
        print STDERR "unable to read file!\n";
        next;
    }

    my $Result = $ContentRef;

    print STDERR "    Lines before: ".@{$Result}."\n";    
    
    my $FileChanged = 0;
    foreach my $Key ( @KeyList ) {
        chomp($Key);

        my $Removing = 0;
        my $RemovedLines = 0;
        my $Index = 0;
        foreach my $Line ( @{$Result} ) {
            next if !$Line;
            
            if ( $Line =~ /<ConfigItem Name="$Key"/ ) {
                $FileChanged = 1;
                $Removing = 1;
                $RemovedLines = 0;
                print STDERR "    removing $Key\n";
            }

            if ( $Removing ) {
                $RemovedLines++;
                delete $Result->[$Index];
            }

            if ( $Removing && $Line =~ /<\/ConfigItem>/ ) {
                $Removing = 0;
                print STDERR "        removed $RemovedLines lines\n";
            }

            $Index++;
        }

        $Result = [ grep defined, @{$Result} ];
    }

    my @Content = grep defined, @{$Result};
    print STDERR "    Lines after: ".@Content."\n";    

    if ( $FileChanged ) {
        my $Result = $MainObject->FileWrite(
            Location => $File,
            Content  => \(join("", @Content)),
        );
    }
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
