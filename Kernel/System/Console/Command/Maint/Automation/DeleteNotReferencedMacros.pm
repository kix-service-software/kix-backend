# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Automation::DeleteNotReferencedMacros;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);
use Kernel::System::VariableCheck qw(IsHashRefWithData);

our @ObjectDependencies = (
    'Automation',
    'ObjectAction'
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete all not referenced (not used in jobs or object action and not as sub-macro) macros, their actions and their sub-macros (if not referenced or ignored).');
    $Self->AddOption(
        Name        => 'ignore-macro-id',
        Description => "Specify one or more macro ids to ignore.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Deleting dangling macros...</yellow>\n");

    my @IgnoreMacroIDs = @{ $Self->GetOption('ignore-macro-id') // [] };

    my $AutomationObject = $Kernel::OM->Get('Automation');

    my $DeletedMacroCount = 0;

    # check all macro ids
    my %AllMacros = $AutomationObject->MacroList();

    # automation have to know which ids should be ignored
    # => ignore potential sub macro of deletable macros (in recursive delete)
    $AutomationObject->{IgnoreMacroIDsForDelete} = \@IgnoreMacroIDs;

    if (IsHashRefWithData(\%AllMacros)) {
        for my $MacroID (keys %AllMacros) {

            # ignore id
            next if (grep { $_ == $MacroID } @IgnoreMacroIDs);

            # ignore subs of ignored ids
            next if $AutomationObject->IsSubMacroOf(
                ID     => $MacroID,
                IDList => \@IgnoreMacroIDs
            );

            # check if deletable
            next if !$AutomationObject->MacroIsDeletable(
                ID => $MacroID
            );

            my $Success = $AutomationObject->MacroDelete(
                ID => $MacroID,
            );

            if ( !$Success ) {
                $Self->PrintError("Unable to delete macro with id $MacroID\n");
                next;
            }

            $Self->Print("  $MacroID :: $AllMacros{$MacroID}\n");
            $DeletedMacroCount++;
        }
    }

    # reset ignore list
    delete $AutomationObject->{IgnoreMacroIDsForDelete};

    $Self->Print("<green>$DeletedMacroCount " . ($DeletedMacroCount == 1 ? 'macro has' : 'macros have') . " been deleted.</green>\n");
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
