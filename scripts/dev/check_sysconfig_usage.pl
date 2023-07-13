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

use File::Basename;
use FindBin qw($RealBin);
use lib "$RealBin/../..";
use lib "$RealBin/../../Kernel/cpan-lib";
use lib "$RealBin/../../Custom";

use Kernel::System::VariableCheck qw(:all);

use Kernel::System::ObjectManager;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'check_sysconfig_usage',
    },
);

my $SysConfigObject = $Kernel::OM->Get('SysConfig');
my $MainObject      = $Kernel::OM->Get('Main');

my @FileList = $MainObject->DirectoryRead(
    Directory => $Kernel::OM->Get('Config')->Get('Home'),
    Filter    => [ '*.pm', '*.pl', '*.t' ],
    Recursive => 1,
);

my %ConfigItemUsage;

my $Count = 0;
foreach my $File (sort @FileList) {
    next if $File =~ /\/ZZZAAuto\.pm/;

    print STDERR ++$Count . ": checking file $File...\n";

    my $ContentRef = $MainObject->FileRead(
        Location => $File,
    );

    if ( !$$ContentRef ) {
        print STDERR "unable to read file!\n";
        next;
    }

    my $Content = $$ContentRef;

    foreach my $OptionName ( $SysConfigObject->OptionList() ) {
        my $Key = $OptionName;
        my $SubKey;

        if (!exists $ConfigItemUsage{$Key}) {
            $ConfigItemUsage{$Key} = {};
        }

        if ( $Key =~ /^(.*?)###(.*?)$/g ) {
            $Key = $1;
            $SubKey = $2;
        }

        if ( $Content =~ /$Key/m ) {
            if ( $SubKey && $Content =~ /$SubKey/m ) {
                print STDERR "     subkey $SubKey found\n";
                $ConfigItemUsage{$OptionName}->{$File} = 1;
            }
            else {
                print STDERR "     key $Key found\n";
                $ConfigItemUsage{$Key}->{$File} = 1;
            }
        }
    }
}

my $HTML = "<html>
<head>
<style>
table,td {
    width: 100%;
    border: 1px solid #a0a0a0;
    vertical-align: top;
}
th:first-child, td:first-child {
    width: 50px;
    text-align: right;
}
.used {
    background-color: #cbf774;
}
.unused {
    background-color: #ffaaaa;
}
.parentused {
    background-color: #fffc84;
}
</style>
</head>
<body>
<table cellspacing='0'>
<thead>
<tr>
<th>LfdNr.</th>
<th>Key</th>
<th>verwendet in</th>
</tr>
</thead>
<tbody>";

my $Index = 0;

my @Rows = (
    'LfdNr,Key,Verwendung,verwendet in'
);

foreach my $Key (sort keys %ConfigItemUsage) {
    my $Class = 'used';
    if (!IsHashRefWithData($ConfigItemUsage{$Key})) {
        $Class = "unused";
    }

    if ( $Key =~ /^(.*?)###(.*?)$/g ) {
        my $ParentKey = $1;
        if ($Class eq 'unused' && IsHashRefWithData($ConfigItemUsage{$ParentKey})) {
            # key is not explicitely used but the parent part of the key is used
            $Class = 'parentused';
        }
    }

    $HTML .= '<tr class="'.$Class.'">
<td>'.++$Index.'</td>
<td>'.$Key.'</td>
<td>'.(join('<br/>', sort keys %{$ConfigItemUsage{$Key}})).'</td>
</tr>';

    push(@Rows, "$Index,\"$Key\",\"$Class\",\"".(join("\n", sort keys %{$ConfigItemUsage{$Key}})).'"');
}
$HTML .= '</tbody></table></body></html>';

print $HTML;

$Kernel::OM->Get('Main')->FileWrite(
    Location => './sysconfig_usage.csv',
    Content  => \(join("\n", @Rows))
);

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
