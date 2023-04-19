#!/usr/bin/perl
# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;

use Cwd;
use Getopt::Long;
use File::Basename;
use JSON::MaybeXS;
use Data::Dumper;

my %Options;
GetOptions(
    'source-directory=s' => \$Options{SourceDirectory},
    'allure-url=s'       => \$Options{AllureURL},
    'help'               => \$Options{Help},
);

# check required options
my %Missing;
foreach my $Option ( qw(SourceDirectory ) ) {
    $Missing{$Option} = 1 if !$Options{$Option};
}

# check if directory is given
if ( $Options{Help} || %Missing ) {
    print "allure2html - Generates a simple HTML table from pherkin Allure results.\n";
    print "Copyright (C) 2006-2022 c.a.p.e. IT GmbH, http//www.cape-it.de/\n";
    print "\n";
    print "Required Options:\n";
    print "  --source-directory - The directory where the pherkin allure output files are located.\n";
    print "  --allure-url - The URL to the detailed latest test results in allure. (optional)\n";
    exit -1;
}

# change working directory
my $Cwd = cwd();
chdir "$Options{SourceDirectory}";

my %Results;
foreach my $File ( glob("*-result.json") ) {

    my $Content = FileRead(
        Location => $File
    );
    if ( !$Content ) {
        print STDERR "ERROR: Unable to read file $File.\n";
        exit 1;
    }

    my $AllureResult = decode_json($Content);
    if ( IsHashRefWithData($AllureResult) ) {
        my $Resource;
        my $Method;
        foreach my $Label ( @{$AllureResult->{labels}} ) {
            next if $Label->{name} ne 'suite';
            if ( $Label->{value} =~ /^(\w+)\s+.*?\s+(\/.*?)\s+/ ) {
                $Method   = $1;
                $Resource = $2;
            }
            last;
        }
        my $uuid = $AllureResult->{uuid};
        $uuid =~ s/-//g;
        $Results{$Resource}->{$Method}->{UUID}   = $uuid;
        $Results{$Resource}->{$Method}->{Status} = $AllureResult->{status};

        if ( $Options{AllureURL} ) {
            $Results{$Resource}->{$Method}->{AllureLink} = $Options{AllureURL}.'/'.$Results{$Resource}->{$Method}->{UUID};
        }
    }
}

chdir $Cwd;

my $Date = localtime();

# generate HTML output
print "<html><head>
<style>
body {
    font-family: monospace;
    display: table;
    position: relative;
    -webkit-box-sizing: border-box;
    -moz-box-sizing: border-box;
    box-sizing: border-box;
    width: 100%;
    padding-top: 1em;
    height: 100%;
}
h1 {
    font-weight: 500;
    line-height: 20px;
}
table {
    border: 1px solid gray;
    border-spacing: 5px;
}
tr:hover {
    background-color: LemonChiffon;
}
.method {
    color: black;
    padding: 3px 6px;
}
.method.failed {
    background-color: red;
}
.method.passed {
    background-color: green;
}
.method.nil {
    background-color: lightgray;
    color: gray;
}
a {
    text-decoration: none;
    color: inherit;
    cursor: hand;
}
</style>
</head></body><div><h1>$Date</h1></div><table><tbody>\n";

my $Count = 0;
foreach my $Resource ( sort keys %Results ) {
    my $Row = '<tr><td class="count">'.++$Count.'</td><td class="resource">'.$Resource.'</td>';
    foreach my $Method ( qw(GET POST PATCH DELETE) ) {
        if ( exists $Results{$Resource}->{$Method} ) {
            if ( $Results{$Resource}->{$Method}->{AllureLink} ) {
                $Row .= '<td class="method '.$Results{$Resource}->{$Method}->{Status}.'"><a href="'.$Results{$Resource}->{$Method}->{AllureLink}.'" target="_new">'.$Method.'</a></td>';
            }
            else {
                $Row .= '<td class="method '.$Results{$Resource}->{$Method}->{Status}.'">'.$Method.'</td>';
            }
        }
        else {
            $Row .= '<td class="method nil">'.$Method.'</td>';
        }
    }
    print "$Row\n";
}
print "</tbody></html>";

sub FileRead {
    my %Param = @_;
    my $Content;

    my $Location = $Param{Location} || $Param{Directory}.'/'.$Param{Filename};

    if ( !open(HANDLE, '<', $Location) ) {
        return;
    }

    $Content = do { local $/; <HANDLE> };
    close(HANDLE);

    return $Content;
}

sub IsHashRefWithData {
    my $TestData = $_[0];

    return if scalar @_ ne 1;
    return if ref $TestData ne 'HASH';
    return if !%{$TestData};

    return 1;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
