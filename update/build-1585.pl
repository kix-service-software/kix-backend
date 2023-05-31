#!/usr/bin/perl
# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
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
        LogPrefix => 'framework_update-to-build-1585',
    },
);

use vars qw(%INC);

# add the new job
_AddPeriodicReportsJob();

sub _AddPeriodicReportsJob {
    my ( $Self, %Param ) = @_;

    my $JobName = 'Periodic Reports';

    my $AutomationObject = $Kernel::OM->Get('Automation');

    # create execution plan
    my $ExecPlanID = $AutomationObject->ExecPlanAdd(
        Name       => "Event based Execution Plan for Job \"$JobName\"",
        Type       => 'TimeBased',
        Parameters => {
            "Weekday" => ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'],
            "Time"    => [
                        '00:00','00:15','00:30','00:45',
                        '01:00','01:15','01:30','01:45',
                        '02:00','02:15','02:30','02:45',
                        '03:00','03:15','03:30','03:45',
                        '04:00','04:15','04:30','04:45',
                        '05:00','05:15','05:30','05:45',
                        '06:00','06:15','06:30','06:45',
                        '07:00','07:15','07:30','07:45',
                        '08:00','08:15','08:30','08:45',
                        '09:00','09:15','09:30','09:45',
                        '10:00','10:15','10:30','10:45',
                        '11:00','11:15','11:30','11:45',
                        '12:00','12:15','12:30','12:45',
                        '13:00','13:15','13:30','13:45',
                        '14:00','14:15','14:30','14:45',
                        '15:00','15:15','15:30','15:45',
                        '16:00','16:15','16:30','16:45',
                        '17:00','17:15','17:30','17:45',
                        '18:00','18:15','18:30','18:45',
                        '19:00','19:15','19:30','19:45',
                        '20:00','20:15','20:30','20:45',
                        '21:00','21:15','21:30','21:45',
                        '22:00','22:15','22:30','22:45',
                        '23:00','23:15','23:30','23:45'
                    ]
        },
        Comment    => "Event based Execution Plan for Job \"$JobName\"",
        ValidID    => 1,
        UserID     => 1
    );
    if ( !$ExecPlanID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to create execution plan for \"$JobName\" job!"
        );
        next;
    }

    # create macro
    my $MacroID = $AutomationObject->MacroAdd(
        Name       => "Macro for Job \"$JobName\"",
        Type       => 'Reporting',
        Comment    => "Macro for Job \"$JobName\"",
        ValidID    => 1,
        UserID     => 1
    );

    if ( !$MacroID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to create macro for \"$JobName\" job!"
        );

        # removed created execution plan
        $AutomationObject->ExecPlanDelete(
            ID => $ExecPlanID,
        );
        return;
    }

    # create macro actions
    my @ActionIDs;
    my @MacroActionList = (
        {
            Type       => 'CreateReport',
            Parameters => {
                DefinitionID  => '${ObjectID}',
                OutputFormats => ['CSV']
            }
        }
    );

    for my $Action (@MacroActionList) {
        my $ActionID = $AutomationObject->MacroActionAdd(
            %{$Action},
            MacroID    => $MacroID,
            Comment    => "MacroAction for Job \"$JobName\"",
            ValidID    => 1,
            UserID     => 1
        );

        if ($ActionID) {
            push(@ActionIDs, $ActionID);
        } else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create macro action (\"$Action->{Type}\") for \"$JobName\" job!"
            );
        }
    }

    # set macro exec order
    if (@ActionIDs) {
        $AutomationObject->MacroUpdate(
            ID         => $MacroID,
            ExecOrder  => \@ActionIDs,
            UserID     => 1
        );
    }

    # create job
    my $JobID;

    $JobID = $AutomationObject->JobAdd(
        Name       => $JobName,
        Type       => 'Reporting',
        Filter     => {
            AND => [
                { Field => 'IsPeriodic', Operator => 'EQ', Type => "NUMERIC", Value => 1 }
            ]
        },
        Comment    => Encode::decode_utf8('Executes all reports that should be created periodically.'),
        ValidID    => 1,
        UserID     => 1
    );

    if ( !$JobID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to create \"$JobName\" job!"
        );

        # removed created actions, macro and execution plan
        for my $ActionID ( @ActionIDs ) {
            $AutomationObject->MacroActionDelete(
                ID => $ActionID,
            );
        }
        $AutomationObject->MacroDelete(
            ID => $MacroID,
        );
        $AutomationObject->ExecPlanDelete(
            ID => $ExecPlanID,
        );
        return;
    }

    # assign macro to job
    my $Result = $Kernel::OM->Get('Automation')->JobMacroAdd(
        JobID   => $JobID,
        MacroID => $MacroID,
        UserID  => 1
    );

    if (!$Result) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to assign macro ($MacroID) to \"$JobName\" job ($JobID)!"
        );
    }

    # assign execution plan to job
    $Result = $Kernel::OM->Get('Automation')->JobExecPlanAdd(
        JobID      => $JobID,
        ExecPlanID => $ExecPlanID,
        UserID     => 1
    );
    if (!$Result) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to assign execution plan ($ExecPlanID) to \"$JobName\" job ($JobID)!"
        );
    }
}

exit 0;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
