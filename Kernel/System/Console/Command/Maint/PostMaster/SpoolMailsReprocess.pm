# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::PostMaster::SpoolMailsReprocess;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Config',
    'Log',
    'Main',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Reprocess mails from spool directory that could not be imported in the first place.');

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $SpoolDir = $Kernel::OM->Get('Config')->Get('Home') . '/var/spool';
    if ( !-d $SpoolDir ) {
        die "Spool directory $SpoolDir does not exist!\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Home     = $Kernel::OM->Get('Config')->Get('Home');
    my $SpoolDir = "$Home/var/spool";

    $Self->Print("<yellow>Processing mails in $SpoolDir...</yellow>\n");

    my @Files = $Kernel::OM->Get('Main')->DirectoryRead(
        Directory => $SpoolDir,
        Filter    => '*',
    );

    my $Success = 1;

    for my $File (@Files) {
        $Self->Print("  Processing <yellow>$File</yellow>... ");

        # Here we use a system call because Maint::PostMaster::Read has special exception handling
        #   and will die if certain problems occur.
        my $Result = system("$^X $Home/bin/kix.Console.pl Maint::PostMaster::Read <  $File ");

        # Exit code 0 == success
        if ( !$Result ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Successfully reprocessed email $File.",
            );
            unlink $File;
            $Self->Print("<green>Ok.</green>\n");
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Could not re-process email $File.",
            );
            $Self->Print("<red>Failed.</red>\n");
            $Success = 0;
        }
    }

    if ( !$Success ) {
        $Self->PrintError("There were problems importing the spool mails.");
        return $Self->ExitCodeError();
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
