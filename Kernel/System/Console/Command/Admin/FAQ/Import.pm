# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::FAQ::Import;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Config',
    'CSV',
    'DB',
    'FAQ',
    'Main',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('FAQ import tool.');
    $Self->AddOption(
        Name        => 'separator',
        Description => "Defines the separator for data in CSV file (default ';').",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'quote',
        Description => "Defines the quote for data in CSV file (default '\"').",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddArgument(
        Name        => 'source-path',
        Description => "Specify the path to the file which containing FAQ items for importing.",
        Required    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AdditionalHelp(
        "<yellow>Format of the CSV file:\n
            title;category;language;statetype;field1;field2;field3;field4;field5;field6;keywords
        </yellow>\n"
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $SourcePath = $Self->GetArgument('source-path');
    if ( $SourcePath && !-r $SourcePath ) {
        die "File $SourcePath does not exist, can not be read.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Importing FAQ items...</yellow>\n");
    $Self->Print( "<yellow>" . ( '=' x 69 ) . "</yellow>\n" );

    my $SourcePath = $Self->GetArgument('source-path');
    $Self->Print("<yellow>Read File $SourcePath </yellow>\n\n");

    # read source file
    my $CSVStringRef = $Kernel::OM->Get('Main')->FileRead(
        Location => $SourcePath,
        Result   => 'SCALAR',
        Mode     => 'binmode',
    );

    if ( !$CSVStringRef ) {
        $Self->PrintError("Can't read file $SourcePath.\nImport aborted.\n");
        return $Self->ExitCodeError();
    }

    my $Separator = $Self->GetOption('separator') || ';';
    my $Quote     = $Self->GetOption('quote')     || '"';

    # read CSV data
    my $DataRef = $Kernel::OM->Get('CSV')->CSV2Array(
        String    => $$CSVStringRef,
        Separator => $Separator,
        Quote     => $Quote,
    );

    if ( !$DataRef ) {
        $Self->PrintError("Error occurred. Import impossible! See Syslog for details.\n");
        return $Self->ExitCodeError();
    }

    # get FAQ object
    my $FAQObject = $Kernel::OM->Get('FAQ');

    # get all FAQ language ids
    my $Languages = $Kernel::OM->Get('Config')->Get('DefaultUsedLanguages');

    my $LineCounter;
    my $SuccessCount    = 0;
    my $UnScuccessCount = 0;

    ROWREF:
    for my $RowRef ( @{$DataRef} ) {

        $LineCounter++;

        my (
            $Title, $CategoryString, $Language, $Visibility,
            $Field1, $Field2, $Field3, $Field4, $Field5, $Field6, $Keywords
        ) = @{$RowRef};

        # check language
        if ( !$Languages->{$Language} ) {
            $Self->PrintError("Error: Could not import line $LineCounter. Language '$Language' does not exist.\n");
            next ROWREF;
        }

        # get subcategories
        my @CategoryArray = split /::/, $CategoryString;

        # check each subcategory if it exists
        my $CategoryID;
        my $ParentID = 0;

        # get database object
        my $DBObject = $Kernel::OM->Get('DB');

        for my $Category (@CategoryArray) {

            # get the category id
            $DBObject->Prepare(
                SQL => 'SELECT id FROM faq_category '
                    . 'WHERE valid_id = 1 AND name = ? AND parent_id = ?',
                Bind  => [ \$Category, \$ParentID ],
                Limit => 1,
            );
            my @Result;
            while ( my @Row = $DBObject->FetchrowArray() ) {
                push( @Result, $Row[0] );
            }
            $CategoryID = $Result[0];

            # create category if it does not exist
            if ( !$CategoryID ) {
                $CategoryID = $FAQObject->CategoryAdd(
                    Name     => $Category,
                    ParentID => $ParentID,
                    ValidID  => 1,
                    UserID   => 1,
                );
            }

            # set new parent id
            $ParentID = $CategoryID;
        }

        # check category
        if ( !$CategoryID ) {
            $Self->PrintError(
                "Error: Could not import line $LineCounter. Category '$CategoryString' could not be created.\n"
            );
            next ROW;
        }

        # get config object
        my $ConfigObject = $Kernel::OM->Get('Config');

        # set content type
        my $ContentType = 'text/plain';
        if ( $ConfigObject->Get('Frontend::RichText') && $ConfigObject->Get('FAQ::Item::HTML') ) {
            $ContentType = 'text/html';
        }

        # add FAQ article
        my $FAQID = $FAQObject->FAQAdd(
            Title       => $Title,
            CategoryID  => $CategoryID,
            Language    => $Language,
            Visibility  => $Visibility,
            Field1      => $Field1,
            Field2      => $Field2,
            Field3      => $Field3,
            Field4      => $Field4,
            Field5      => $Field5,
            Field6      => $Field6,
            Keywords    => $Keywords || '',
            Approved    => 1,
            UserID      => 1,
            ContentType => $ContentType,
        );

        # check success
        if ($FAQID) {
            $SuccessCount++;
        }
        else {
            $UnScuccessCount++;
            $Self->PrintError("Could not import line $LineCounter.\n");
        }
    }

    if ($SuccessCount) {
        $Self->Print("<green>Successfully imported $SuccessCount FAQ item(s).</green>\n");
    }
    if ($UnScuccessCount) {
        $Self->Print("\n<red>Unsuccessfully imported $UnScuccessCount FAQ items(s).</red>\n\n");

        $Self->Print("<red>Import complete with errors.</red>\n");
        $Self->Print( "<yellow>" . ( '=' x 69 ) . "</yellow>\n" );

        $Self->Print("<red>Fail</red>\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("\n");

    $Self->Print("<green>Import complete.</green>\n");
    $Self->Print( "<yellow>" . ( '=' x 69 ) . "</yellow>\n" );

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
