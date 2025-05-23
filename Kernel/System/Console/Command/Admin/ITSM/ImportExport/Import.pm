# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::ITSM::ImportExport::Import;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = qw(
    Main
    ImportExport
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('The tool for importing config items');
    $Self->AddOption(
        Name        => 'template-number',
        Description => "Specify a template number to be imported.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
    );
    $Self->AddArgument(
        Name        => 'source',
        Description => "Specify the path to the file which containing the config item data for importing.",
        Required    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $SourcePath = $Self->GetArgument('source');
    if ( $SourcePath && !-r $SourcePath ) {
        die "File $SourcePath does not exist, can not be read.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $TemplateID = $Self->GetOption('template-number');

    # get template data
    my $TemplateList = $Kernel::OM->Get('ImportExport')->TemplateList(
        UserID => 1,
    );

    if ( !$TemplateList ) {
        $Self->PrintError("No existing templates found in the system!\n");
        $Self->PrintError("Import aborted..\n");
        return $Self->ExitCodeError();
    }

    my %Templates = map{ $_ => 1} @{$TemplateList};
    if ( !$Templates{$TemplateID} ) {
        $Self->PrintError("Template $TemplateID not found!.\n");
        $Self->PrintError("Import aborted..\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<yellow>Importing config items...</yellow>\n");
    $Self->Print( "<yellow>" . ( '=' x 69 ) . "</yellow>\n" );

    my $SourceContent;
    my $SourceFile = $Self->GetArgument('source');

    if ($SourceFile) {

        $Self->Print("<yellow>Read File $SourceFile.</yellow>\n");

        # read source file
        $SourceContent = $Kernel::OM->Get('Main')->FileRead(
            Location => $SourceFile,
            Result   => 'SCALAR',
            Mode     => 'binmode',
        );

        if ( !$SourceContent ) {
            $Self->PrintError("Can't read file $SourceFile.\nImport aborted.\n") if !$SourceContent;
            return $Self->ExitCodeError();
        }

    }

    # import data
    my $Result = $Kernel::OM->Get('ImportExport')->Import(
        TemplateID    => $TemplateID,
        SourceContent => $SourceContent,
        UserID        => 1,
        UsageContext  => 'Agent',
    );

    if ( !$Result ) {
        $Self->PrintError("\nError occurred. Import impossible! See the KIX log for details.\n");
        return $Self->ExitCodeError();
    }

    # print result
    $Self->Print("\n<green>Import of $Result->{Counter} $Result->{Object} records:</green>\n");
    $Self->Print( "<green>" . ( '-' x 69 ) . "</green>\n" );
    $Self->Print("<green>Success: $Result->{Success} succeeded</green>\n");
    if ( $Result->{Failed} ) {
        $Self->PrintError("$Result->{Failed} failed.\n");
    }
    else {
        $Self->Print("<green>Error: $Result->{Failed} failed.</green>\n");
    }

    for my $RetCode ( sort keys %{ $Result->{RetCode} } ) {
        my $Count = $Result->{RetCode}->{$RetCode} || 0;
        $Self->Print("<green>Import of $Result->{Counter} $Result->{Object} records: $Count $RetCode</green>\n");
    }
    if ( $Result->{Failed} ) {
        $Self->Print("<green>Last processed line number of import file: $Result->{Counter}</green>\n");
    }

    $Self->Print("<green>Import complete.</green>\n");
    $Self->Print( "<green>" . ( '-' x 69 ) . "</green>\n" );
    $Self->Print("<green>Done.</green>\n");

    return $Self->ExitCodeOk();
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
