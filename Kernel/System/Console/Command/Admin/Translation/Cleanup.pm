# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, http://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Translation::Cleanup;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

use Kernel::Language;
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Encode',
    'Main',
    'SysConfig',
    'Time',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete all translations in the database.');
    
    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Cleaning up translation database...</yellow>\n\n");

    my $Result = $Kernel::OM->Get('Translation')->CleanUp(
        UserID => 1,
    );

    if ( !$Result ) {
        $Self->PrintError("Error!\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");

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
