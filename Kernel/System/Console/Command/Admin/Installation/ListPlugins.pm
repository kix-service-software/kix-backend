# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Installation::ListPlugins;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = qw(
    Installation
    ClientRegistration
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
    my @PluginList = $Kernel::OM->Get('Installation')->PluginList(
        Valid     => 0,
        InitOrder =>  $Self->GetOption('init-order'),
    );

    $Self->Print("Backend:\n\n");
    $Self->Print("#  Name                           Build-Patch Requires                                           Description\n");
    $Self->Print("-- ------------------------------ ----------- -------------------------------------------------- --------------------------------------------------------------------------------\n");

    my $Count = 0;
    foreach my $Plugin ( @PluginList ) {
        $Self->Print(sprintf("%02i %-30s %11s %-50s %-80s\n", ++$Count, $Plugin->{Product},"$Plugin->{BuildNumber}-$Plugin->{PatchNumber}", ($Plugin->{Requires} || ''), $Plugin->{Description}));
    }

    my @ClientIDs = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationList();
    if ( IsArrayRefWithData(\@ClientIDs) ) {
        CLIENT:
        foreach my $ClientID ( sort @ClientIDs ) {
            my %ClientData = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationGet(
                ClientID => $ClientID
            );

            next CLIENT if !IsArrayRefWithData($ClientData{Plugins});

            $Self->Print("\n\nClient $ClientID:\n\n");
            $Self->Print("#  Name                           Build-Patch Requires                                           Description\n");
            $Self->Print("-- ------------------------------ ----------- -------------------------------------------------- --------------------------------------------------------------------------------\n");

            my $Count = 0;
            foreach my $Plugin ( @{$ClientData{Plugins}} ) {
                $Self->Print(sprintf("%02i %-30s %11s %-50s %-80s\n", ++$Count, $Plugin->{Product}, "$Plugin->{BuildNumber}-$Plugin->{PatchNumber}", ($Plugin->{Requires} || ''), ($Plugin->{Description} || '')));
            }
        }
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
