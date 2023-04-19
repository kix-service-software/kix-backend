# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::List;

use strict;
use warnings;

use Kernel::System::Console;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Config',
    'Main',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Lists available commands.');
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ProductName    = $Kernel::OM->Get('Config')->Get('ProductName');
    my $ProductVersion = $Kernel::OM->Get('Config')->Get('Version');

    my $UsageText = "<green>$ProductName</green> (<yellow>$ProductVersion</yellow>)\n\n";
    $UsageText .= "<yellow>Usage:</yellow>\n";
    $UsageText .= " kix.Console.pl command [options] [arguments]\n";
    $UsageText .= "\n<yellow>Options:</yellow>\n";
    GLOBALOPTION:
    for my $Option ( @{ $Self->{_GlobalOptions} // [] } ) {
        next GLOBALOPTION if $Option->{Invisible};
        my $OptionShort = "[--$Option->{Name}]";
        $UsageText .= sprintf " <green>%-40s</green> - %s", $OptionShort, $Option->{Description} . "\n";
    }
    $UsageText .= "\n<yellow>Available commands:</yellow>\n";

    my $PreviousCommandNameSpace = '';

    COMMAND:
    for my $Command ( $Kernel::OM->Get('Console')->CommandList() ) {

        my $Module = $Kernel::OM->GetModuleFor($Command);

        if ( $Kernel::OM->Get('Main')->Require( $Module, Silent => 1 ) ) {

            my $CommandObject = $Kernel::OM->Get($Command);
            my $CommandName   = $CommandObject->Name();

            # Group by toplevel namespace
            my ($CommandNamespace) = $CommandName =~ m/^([^:]+)::/smx;
            $CommandNamespace //= '';
            if ( $CommandNamespace ne $PreviousCommandNameSpace ) {
                $UsageText .= "<yellow>$CommandNamespace</yellow>\n";
                $PreviousCommandNameSpace = $CommandNamespace;
            }
            $UsageText .= sprintf( " <green>%-40s</green> - %s\n",
                $CommandName, $CommandObject->Description() );

            # KIXCore-capeIT
        }

        # EO KIXCore-capeIT
    }

    $Self->Print($UsageText);

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
