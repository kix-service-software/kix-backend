#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;

use Getopt::Long;
use Text::CSV;

STDOUT->autoflush(1);

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();
my $CURRENT_YEAR = $year + 1900;

my %Options;
GetOptions(
    'csv-file=s'    => \$Options{CSVFile},
    'separator=s'   => \$Options{Separator},
    'quote-char=s'  => \$Options{QuoteChar},
    'escape-char=s' => \$Options{EscapeChar},
    'help'          => \$Options{Help},
);

# check if directory is given
if ( $Options{Help} ) {
    print "generate_permission_xml - Generate the permission XML from a CSV file.\n";
    print "Copyright (C) 2006-$CURRENT_YEAR KIX Service Software GmbH, https://www.kixdesk.com/\n";
    print "\n";
    print "Required Options:\n";
    print "  --csv-file    - The CSV file to convert. If omitted var/packagesetup/initial_permissions.csv will be used.\n";
    print "  --separator   - The CSV separator. Default: ;\n";
    print "  --quote-char  - The CSV quote character. Default: \"\n";
    print "  --escape-char - The CSV escape character. Default: \"\n";
    exit -1;
}

my %RoleList = (
    'Superuser'                     => 1,
    'System Admin'                  => 2,
    'Agent User'                    => 3,
    'Ticket Reader'                 => 4,
    'Ticket Agent'                  => 5,
    'Webform Ticket Creator'        => 6,
    'FAQ Reader'                    => 7,
    'FAQ Editor'                    => 8,
    'Asset Reader'                  => 9,
    'Asset Maintainer'              => 10,
    'Customer Reader'               => 11,
    'Customer Manager'              => 12,
    'Customer'                      => 13,
    'Report User'                   => 14,
    'Report Manager'                => 15,
    'Ticket Agent (Servicedesk)'    => 16,
    'Ticket Agent Base Permission'  => 17,
    'Textmodule Admin'              => 18,
    'FAQ Admin'                     => 19,
);

my %PermissionTypeList = (
    'Resource'     => 1,
    'Object'       => 2,
    'Property'     => 3,
    'Base::Ticket' => 4,
);

# define permission bit values
my %Permission = (
    NONE   => 0x0000,
    CREATE => 0x0001,
    READ   => 0x0002,
    UPDATE => 0x0004,
    DELETE => 0x0008,
    DENY   => 0xF000,
);

my $DisableWarnings = 0;
BEGIN { $SIG{'__WARN__'} = sub { warn $_[0] if !$DisableWarnings } }  # suppress warnings if not activated

my $File   = $Options{CSVFile} || 'var/packagesetup/initial_permissions.csv';
if ( !-f $File ) {
    die "File $File does not exist or is not readable.\n";
}

my @Lines = ReadCSV(
    %Options,
    CSVFile => $File,
);

# remove header line
shift @Lines;

foreach my $Line (@Lines) {
    # trim contents
    foreach my $Column ( @{$Line} ) {
        $Column =~ s/(^\s+|\s+$)//g;
    }
    my $Role   = $Line->[0];
    my $Type   = $Line->[1];
    my $Target = $Line->[2];
    my $Value  = 0
        + ( $Line->[3] ? $Permission{CREATE} : 0 )
        + ( $Line->[4] ? $Permission{READ}   : 0 )
        + ( $Line->[5] ? $Permission{UPDATE} : 0 )
        + ( $Line->[6] ? $Permission{DELETE} : 0 )
        + ( $Line->[7] ? $Permission{DENY}   : 0 );

    $Role   =~ s/ *$//g;
    $Target =~ s/ *$//g;

    my $XML =
        "<Insert Table=\"role_permission\">
    <Data Key=\"role_id\">$RoleList{$Role}</Data>
    <Data Key=\"type_id\">$PermissionTypeList{$Type}</Data>
    <Data Key=\"target\" Type=\"Quote\"><![CDATA[$Target]]></Data>
    <Data Key=\"value\">$Value</Data>
    <Data Key=\"create_by\">1</Data>
    <Data Key=\"create_time\">current_timestamp</Data>
    <Data Key=\"change_by\">1</Data>
    <Data Key=\"change_time\">current_timestamp</Data>
</Insert>";

    # output XML
    print "$XML\n";

}

sub ReadCSV {
    my %Param = @_;

    # create new csv backend object
    my $CSV = Text::CSV->new(
        {

            quote_char          => $Param{QuoteChar} // '"',
            escape_char         => $Param{EscapeChar} || '"',
            sep_char            => $Param{Separator} || ";",
            always_quote        => 0,
            binary              => 1,
            keep_meta_info      => 0,
            allow_loose_quotes  => 0,
            allow_loose_escapes => 0,
            allow_whitespace    => 0,
            verbatim            => 0,
        }
    );
    if ( !$CSV ) {
        die "Can't create CSV object!";
    }

    my @Lines;

    # parse all CSV data line by line (allows newlines in data fields)
    my $LineCounter = 1;
    open my $FileHandle, '<', $Param{CSVFile} || die "unable to open file $Param{CSVFile}";    ## no critic

    while ( my $ColRef = $CSV->getline($FileHandle) ) {
        $LineCounter++;

        # skip empty lines
        next if (!$ColRef->[0]);

        push @Lines, $ColRef;
    }

    # log error if occurred and exit
    if ( !$CSV->eof() ) {
        die 'Failed to parse CSV line ' . $LineCounter
                . ' (input: ' . $CSV->error_input()
                . ', error: ' . $CSV->error_diag() . ')';
    }

    return @Lines;
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
