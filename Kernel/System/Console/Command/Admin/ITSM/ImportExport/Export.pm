# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::ITSM::ImportExport::Export;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Main',
    'ImportExport',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('The tool for exporting config items');
    $Self->AddOption(
        Name        => 'template-number',
        Description => "Specify a template number to be exported.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
    );
    $Self->AddArgument(
        Name        => 'destination',
        Description => "Specify the path to a file where config item data should be exported.",
        Required    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $TemplateID = $Self->GetOption('template-number');

    # get template data
    my $TemplateData = $Kernel::OM->Get('ImportExport')->TemplateGet(
        TemplateID => $TemplateID,
        UserID     => 1,
    );

    if ( !$TemplateData->{TemplateID} ) {
        $Self->PrintError("Template $TemplateID not found!.\n");
        $Self->PrintError("Export aborted..\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<yellow>Exporting config items...</yellow>\n");
    $Self->Print( "<yellow>" . ( '=' x 69 ) . "</yellow>\n" );

    # export data
    my $Result = $Kernel::OM->Get('ImportExport')->Export(
        TemplateID   => $TemplateID,
        UserID       => 1,
        UsageContext => 'Agent',
    );

    if ( !$Result ) {
        $Self->PrintError("Error occurred. Export impossible! See Syslog for details.\n");
        return $Self->ExitCodeError();
    }

    $Self->Print( "<green>" . ( '-' x 69 ) . "</green>\n" );
    $Self->Print("<green>Success: $Result->{Success} succeeded</green>\n");
    if ( $Result->{Failed} ) {
        $Self->PrintError("$Result->{Failed} failed.\n");
    }
    else {
        $Self->Print("<green>Error: $Result->{Failed} failed.</green>\n");
    }

    my $DestinationFile = $Self->GetArgument('destination');

    if ($DestinationFile) {

        my $FileContent = join "\n", @{ $Result->{DestinationContent} };

        # save destination content to file
        my $Success = $Kernel::OM->Get('Main')->FileWrite(
            Location => $DestinationFile,
            Content  => \$FileContent,
        );

        if ( !$Success ) {
            $Self->PrintError("Can't write file $DestinationFile.\nExport aborted.\n");
            return $Self->ExitCodeError();
        }

        $Self->Print("<green>File $DestinationFile saved.</green>\n");

    }

    $Self->Print("<green>Export complete.</green>\n");
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
