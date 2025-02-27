#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1587',
    },
);

use vars qw(%INC);

# add referenced macro ids
_AddReferencedMacroIDs();

sub _AddReferencedMacroIDs {
    my ( $Self, %Param ) = @_;

    # get all macro action ids and parameters
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT id, parameters FROM macro_action'
    );

    my %MacroActions;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        my $Parameters = $Kernel::OM->Get('JSON')->Decode(
            Data => $Row[1]
        );
        if ($Parameters) {
            $MacroActions{$Row[0]} = $Parameters;
        }
    }

    my $ChangesDone;
    if (IsHashRefWithData(\%MacroActions)) {
        for my $ActionID (keys %MacroActions) {
            next if (!$ActionID);

            if(IsHashRefWithData($MacroActions{$ActionID}) && $MacroActions{$ActionID}->{MacroID}) {
                $ChangesDone = 1;

                # update MacroAction in database
                my $Success = $Kernel::OM->Get('DB')->Do(
                    SQL => 'UPDATE macro_action SET referenced_macro_id = ? WHERE id = ?',
                    Bind => [
                        \$MacroActions{$ActionID}->{MacroID}, \$ActionID
                    ],
                );
                if (!$Success) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Could not set referenced marco id of macro action $ActionID!"
                    );
                }
            }
        }
    }

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp() if ($ChangesDone);

    return 1;
}

exit 0;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
