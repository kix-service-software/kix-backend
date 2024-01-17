# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Dev::Tools::GeneralCatalogCSV2XML;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

use Kernel::Language;

our @ObjectDependencies = (
    'Config',
    'Encode',
    'Main',
    'SysConfig',
    'Time',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('create GeneralCatalog XML from CSV.');

    $Self->AddOption(
        Name        => 'file',
        Description => "The CSV file to convert.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $CSVFile = $Self->GetOption('file');
    if ( !-f $CSVFile ) {
        die "File $CSVFile does not exist or is not readable.\n";
    }

    $Self->Print("<yellow>generating XML...</yellow>\n\n");

    # read CSV file
    my $Content = $Kernel::OM->Get('Main')->FileRead(
        Location => $CSVFile,
    );
    if ( !$Content ) {
        $Self->PrintError('Could not read CSV file!');
        return $Self->ExitCodeError();
    }

    my $LinesRef = $Kernel::OM->Get('CSV')->CSV2Array(
        String => $$Content
    );

    # remove header line
    my @Lines = @{$LinesRef};
    shift @Lines;

    my $ID = 1;
    my @PrefList;
    foreach my $Line (@Lines) {
        my $Class = $Line->[0];
        my $Name  = $Line->[1];
        my $Functionality = $Line->[2];

        my $XML =
"    <Insert Table=\"general_catalog\">
        <Data Key=\"id\" Type=\"AutoIncrement\">$ID</Data>
        <Data Key=\"general_catalog_class\" Type=\"Quote\">$Class</Data>
        <Data Key=\"name\" Type=\"Quote\" Translatable=\"1\">$Name</Data>
        <Data Key=\"valid_id\">1</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>";

        $Self->Print("$XML\n");

        if ( $Functionality ) {
            my $PrefXML =
"   <Insert Table=\"general_catalog_preferences\">
        <Data Key=\"general_catalog_id\">$ID</Data>
        <Data Key=\"pref_key\" Type=\"Quote\">Functionality</Data>
        <Data Key=\"pref_value\" Type=\"Quote\">$Functionality</Data>
    </Insert>";

            push(@PrefList, $PrefXML);
        }

        $ID++;
    }

    if ( @PrefList ) {
        $Self->Print("\n<!-- general catalog preferences -->\n");
        foreach my $PrefXML ( @PrefList ) {
            $Self->Print("$PrefXML\n");
        }
    }
    $Self->Print("\n<green>Done.</green>\n");

    return $Self->ExitCodeOk();
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
