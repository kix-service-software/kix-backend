# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Database::MySQL::InnoDBMigration;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'DB',
    'PID',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Converts all MySQL database tables to InnoDB.');
    $Self->AddOption(
        Name        => 'force',
        Description => "Actually do the migration now.",
        Required    => 0,
        HasValue    => 0,
    );
    $Self->AddOption(
        Name        => 'force-pid',
        Description => "Start even if another process is still registered in the database.",
        Required    => 0,
        HasValue    => 0,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    if ( $Kernel::OM->Get('DB')->{'DB::Type'} ne 'mysql' ) {
        die "This script can only be run on mysql databases.\n";
    }

    my $PIDCreated = $Kernel::OM->Get('PID')->PIDCreate(
        Name  => $Self->Name(),
        Force => $Self->GetOption('force-pid'),
        TTL   => 60 * 60 * 24 * 3,
    );
    if ( !$PIDCreated ) {
        my $Error = "Unable to register the process in the database. Is another instance still running?\n";
        $Error .= "You can use --force-pid to override this check.\n";
        die $Error;
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Force = $Self->GetOption('force');
    if ($Force) {
        $Self->Print("<yellow>Converting all database tables to InnoDB...</yellow>\n");
    }
    else {
        $Self->Print("<yellow>Checking for tables that need to be converted to InnoDB...</yellow>\n");
    }

    # Get all tables that have MyISAM
    $Kernel::OM->Get('DB')->Prepare(
        SQL => "SHOW TABLE STATUS WHERE ENGINE = 'MyISAM'",
    );

    my @Tables;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push @Tables, $Row[0];
    }

    # Turn off foreign key checks.
    if (@Tables) {
        my $Result = $Kernel::OM->Get('DB')->Do(
            SQL => "SET foreign_key_checks = 0",
        );
        if ( !$Result ) {
            $Self->PrintError('Could not disable foreign key checks.');
            return $Self->ExitCodeError();
        }
    }

    $Self->Print( "<yellow>" . scalar @Tables . "</yellow> tables need to be converted.\n" );
    if ( !$Force ) {
        if (@Tables) {
            $Self->Print("You can re-run this script with <green>--force</green> to start the migration.\n");
            $Self->Print("<red>This operation can take a long time.</red>\n");
        }
        return $Self->ExitCodeOk();
    }

    # Now convert the tables.
    for my $Table (@Tables) {
        $Self->Print("  Changing table <yellow>$Table</yellow> to engine InnoDB...\n");
        my $Result = $Kernel::OM->Get('DB')->Do(
            SQL => "ALTER TABLE $Table ENGINE = InnoDB",
        );
        if ( !$Result ) {
            $Self->PrintError("Could not convert table $Table to engine InnoDB.");
            return $Self->ExitCodeError();
        }
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

sub PostRun {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('PID')->PIDDelete( Name => $Self->Name() );
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
