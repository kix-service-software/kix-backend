# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Installation::ListPlugins;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Installation',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List Plugins.');

    $Self->AddOption(
        Name        => 'init-order',
        Description => "Sort list by order of initialization.",
        Required    => 0,
        HasValue    => 0,
    );    

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing plugins...</yellow>\n");

    # get all plugins
    my @PluginList = $Kernel::OM->Get('Kernel::System::Installation')->PluginList(
        Valid     => 0,
        InitOrder =>  $Self->GetOption('init-order'), 
    );

    $Self->Print("#  Name                           Build Requires                                           Description\n");
    $Self->Print("-- ------------------------------ ----- -------------------------------------------------- --------------------------------------------------------------------------------\n");

    my $Count = 0;
    foreach my $Plugin ( @PluginList ) {
        $Self->Print(sprintf("%02i %-30s %-5s %-50s %-80s\n", ++$Count, $Plugin->{Product}, $Plugin->{BuildNumber}, ($Plugin->{Requires} || ''), $Plugin->{Description}));
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
