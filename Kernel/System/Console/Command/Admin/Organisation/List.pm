# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Organisation::List;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Organisation',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List organisations.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing organisations...</yellow>\n");

    # get all organisations
    my @OrganisationIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Organisation',
        Result     => 'ARRAY',
        UserType   => 'Agent',
        UserID     => 1,
    );

    my %ValidStr = (
        1 => 'yes',
        2 => 'no',
        3 => 'no(temp)',
    );

    $Self->Print("    ID Number                                   Name                                                         Valid\n");
    $Self->Print("------ ---------------------------------------- ------------------------------------------------------------ --------\n");

    foreach my $ID ( @OrganisationIDs ) {
        my %Organisation = $Kernel::OM->Get('Organisation')->OrganisationGet(
            ID => $ID
        );

        my $Valid = $ValidStr{$Organisation{ValidID}};

        $Self->Print(sprintf("%6i %-40s %-60s %-8s\n",
            $Organisation{ID}, $Organisation{Number}, $Organisation{Name}, $Valid));
    }

    $Self->Print("<green>Done</green>\n");
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
