# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::ITSM::ImportExport::AutoCreateMapping;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'ImportExport::ITSMConfigItemCSVMappingAutoCreate',
    'GeneralCatalog'
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('The tool to automatic create a CSV-mapping for ITSM class definitions.');
    $Self->AddOption(
        Name        => 'class',
        Description => "Specify a single CI class name to create a CSV-mapping (e.g. \"--class Computer\").",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.+/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $AutoCreateObject     = $Kernel::OM->Get('ImportExport::ITSMConfigItemCSVMappingAutoCreate');
    my $GeneralCatalogObject = $Kernel::OM->Get('GeneralCatalog');

    my $ClassName = $Self->GetOption('class');

    $Self->Print("<yellow>Start create CSV-mapping...</yellow>\n");

    my @CIClassIDs;

    my $CIClassRef = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::Class',
        Valid => 0,
    );

    if (IsHashRefWithData($CIClassRef)) {
        if ( $ClassName ) {
            my %ReverseList = reverse %{$CIClassRef};
            my $ClassID = $ReverseList{$ClassName};

            if ($ClassID) {
                @CIClassIDs = ($ClassID);
            } else {
                $Self->PrintError("No CI class found with name \"$ClassName\".\n");
                return $Self->ExitCodeError();
            }
        } else {
            @CIClassIDs = keys %{$CIClassRef};
        }
    } else {
        $Self->Print("<yellow>No CI classes found.</yellow>\n");
    }

    for my $CurrKey ( @CIClassIDs ) {
        $Self->Print( "Create mapping for ClassID $CurrKey ...\n" );
        $AutoCreateObject->CSVMappingAutoCreate(
            ClassID         => $CurrKey,
            TemplateComment => 'console command'
        );
    }

    $Self->Print( "<green>Done.</green>\n" );
    return $Self->ExitCodeOk();
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
