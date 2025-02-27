# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::ImportExport::ListMappings;

use strict;
use warnings;

use Kernel::System::Console;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'ImportExport'
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Lists available config item csv mappings.');
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $TemplateListRef = $Kernel::OM->Get('ImportExport')->TemplateList(
        UserID => 1,
    );

    my $TemplateListString = sprintf("%-6s %-60s %-20s %-20s %s\n", 'ID', 'Name', 'Type', 'Object', 'Validity');
    $TemplateListString .= sprintf(
        "%6.6s %60.60s %20.20s %20.20s %s\n",
         '--------------------',
         '--------------------------------------------------------------------------------',
         '------------------------------',
         '------------------------------',
         '--------------------',
    );

    if ( $TemplateListRef && ref($TemplateListRef) eq 'ARRAY' ) {
        my %ValidList = $Kernel::OM->Get('Valid')->ValidList();
        for my $CurrTemplateID ( @{$TemplateListRef} ) {
            my $TemplateDataRef = $Kernel::OM->Get('ImportExport')->TemplateGet(
                TemplateID => $CurrTemplateID,
                UserID     => 1,
            );
            if (
                $TemplateDataRef
                && ref($TemplateDataRef) eq 'HASH'
                && $TemplateDataRef->{Object}
                && $TemplateDataRef->{Name}
                )
            {
                $TemplateListString .= sprintf(
                    "%-6s %-60.60s %-20.20s %-20.20s %s\n",
                    $CurrTemplateID, $TemplateDataRef->{Name}, $TemplateDataRef->{Format},$TemplateDataRef->{Object},
                    %ValidList ? $ValidList{$TemplateDataRef->{ValidID}} : $TemplateDataRef->{ValidID}
                );
            }
        }
    }

    $Self->Print($TemplateListString);

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
