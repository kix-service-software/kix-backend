# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Installation::Migrate::ListSources;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Migration',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List supported data sources.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing supported data sources...</yellow>\n");

    my $SourceList = $Kernel::OM->Get('Config')->Get('Migration::Sources');
    if ( !IsHashRefWithData($SourceList) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No registered sources available!',
        );
        return;
    }

    $Self->Print("Source                         Options\n");
    $Self->Print("------------------------------ --------------------------------------------------------------------------------\n");

    foreach my $Source ( sort keys %{$SourceList} ) {
        $Self->Print(sprintf("%-30s %-80s\n", $Source, ( $SourceList->{$Source}->{Options} || '')));
    }

    $Self->Print("<green>Done.</green>\n");

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
