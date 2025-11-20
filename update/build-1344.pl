#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
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
use lib dirname($Bin) . '/plugins';
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Getopt::Std;

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1344',
    },
);

use vars qw(%INC);

# add the new job
_AddMobileProcessingStateResetJob();

sub _AddMobileProcessingStateResetJob {
    my ( $Self, %Param ) = @_;

    my $JobName = 'KIX Field Agent - Mobile Processing Rejected';

    my $LogObject        = $Kernel::OM->Get('Log');
    my $AutomationObject = $Kernel::OM->Get('Automation');

    # create execution plan
    my $ExecPlanID = $AutomationObject->ExecPlanAdd(
        Name       => "Event based Execution Plan for Job \"$JobName\"",
        Type       => 'EventBased',
        Parameters => {
            Event => [ 'TicketDynamicFieldUpdate_MobileProcessingState' ]
        },
        Comment    => "Event based Execution Plan for Job \"$JobName\"",
        ValidID    => 1,
        UserID     => 1
    );

    if ( !$ExecPlanID ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Unable to create execution plan for \"$JobName\" job!"
        );
        return;
    }

    # create macro
    my $MacroID = $AutomationObject->MacroAdd(
        Name       => "Macro for Job \"$JobName\"",
        Type       => 'Ticket',
        Comment    => "Macro for Job \"$JobName\"",
        ValidID    => 1,
        UserID     => 1
    );

    if ( !$MacroID ) {
        $LogObject->Log(
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
            Type       => 'LockSet',
            Parameters => {
                Lock => 'unlock'
            }
        },
        {
            Type       => 'OwnerSet',
            Parameters => {
                OwnerLoginOrID => 1
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
            $LogObject->Log(
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
    my $JobID = $AutomationObject->JobAdd(
        Name       => $JobName,
        Type       => 'Ticket',
        Filter     => {
            AND => [
                { Field => 'DynamicField_MobileProcessingState', Operator => 'IN', Value => ['rejected'] },
            ]
        },
        Comment    => Encode::decode_utf8('This job resets owner and lock state of a ticket, when its mobile processing state is set to "rejected".'),
        ValidID    => 1,
        UserID     => 1
    );

    if ( !$JobID ) {
        $LogObject->Log(
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
        $LogObject->Log(
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
        $LogObject->Log(
            Priority => 'error',
            Message  => "Unable to assign execution plan ($ExecPlanID) to \"$JobName\" job ($JobID)!"
        );
    }

    return 1;
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
