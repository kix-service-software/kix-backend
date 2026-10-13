# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Automation::JobRun::Delete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = qw(
    Automation
    Time
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete job runs.');
    $Self->AddOption(
        Name        => 'all-jobs',
        Description => "Delete job runs of all jobs",
        Required    => 0,
        HasValue    => 0,
    );
    $Self->AddOption(
        Name        => 'job-id',
        Description => "Delete job runs of given job id(s)",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'all-runs',
        Description => "Delete all job runs of relevant jobs",
        Required    => 0,
        HasValue    => 0,
    );
    $Self->AddOption(
        Name        => 'older-than-days',
        Description => "Delete job runs older than XX days (24h) of relevant jobs",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $AllJobs = $Self->GetOption('all-jobs');
    my @JobIDs  = @{ $Self->GetOption('job-id')  // [] };
    if (
        !$AllJobs
        && !IsArrayRefWithData( \@JobIDs )
    ) {
        die
            "Please provide option --all-jobs, or --job-id.\n"
            . "For more details use --help\n";
    }
    if ( $AllJobs ) {
        my %Jobs = $Kernel::OM->Get('Automation')->JobList();
        $Self->{JobIDs} = [ sort( keys( %Jobs ) ) ];
    } else {
        for my $JobID ( @JobIDs ) {
            next if ( $Kernel::OM->Get('Automation')->JobLookup( ID => $JobID ) );

            die "Job ID $JobID does not exist.\n";
        }

        $Self->{JobIDs} = \@JobIDs;
    }

    my $AllRuns       = $Self->GetOption('all-runs');
    my $OlderThanDays = $Self->GetOption('older-than-days') // q{};
    if (
        !$AllRuns
        && !$OlderThanDays
    ) {
        die
            "Please provide option --all-runs, or --older-than-days.\n"
            . "For more details use --help\n";
    }

    if ( $AllRuns ) {
        $Self->{OlderThanDays} = 0;
    }
    else {
        $Self->{OlderThanDays} = $OlderThanDays;
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>Delete job runs...</yellow>' . "\n");

    for my $JobID ( @{ $Self->{JobIDs} } ) {
        $Self->Print(' <yellow>Handle job id ' . $JobID . '...</yellow>' . "\n");

        my @JobRunIDs = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType => 'Automation_JobRun',
            Result     => 'ARRAY',
            Search     => {
                'AND' => [
                    {
                        Field    => 'JobID',
                        Operator => 'EQ',
                        Value    => $JobID
                    },
                    {
                        'Field'    => 'StartTime',
                        'Operator' => 'LT',
                        'Value'    => '-' . $Self->{OlderThanDays} . 'd'
                    }
                ]
            },
            UserType   => 'Agent',
            UserID     => 1
        );

        $Self->Print('  <yellow>Delete ' . scalar( @JobRunIDs ) . ' job runs...</yellow>' . "\n");

        for my $RunID ( @JobRunIDs ) {
            my $Success = $Kernel::OM->Get('Automation')->JobRunDelete(
                JobID  => $JobID,
                RunID  => $RunID,
                UserID => 1,
            );
            if ( !$Success ) {
                $Self->PrintError("Unable to delete job run with id $RunID");
            }
        }
    }

    # show successfull output
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
