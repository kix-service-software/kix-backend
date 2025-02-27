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
        LogPrefix => 'framework_update-to-build-1536',
    },
);

use vars qw(%INC);

# add the new job
_AddReopenJob();

sub _AddReopenJob {
    my ( $Self, %Param ) = @_;

    my $JobName = 'Customer Response - reopen from pending';

    my $AutomationObject = $Kernel::OM->Get('Automation');

    # create execution plan
    my $ExecPlanID = $AutomationObject->ExecPlanAdd(
        Name       => "Event based Execution Plan for Job \"$JobName\"",
        Type       => 'EventBased',
        Parameters => {
            Event => [ 'ArticleCreate' ]
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
        Type       => 'Ticket',
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
            Type       => 'StateSet',
            Parameters => {
                State => 'open'
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

    my @ANDs;

    my $SenderTypeID = $Kernel::OM->Get('Ticket')->ArticleSenderTypeLookup(
        SenderType => 'external'
    );
    if ($SenderTypeID) {
        push(@ANDs, { Field => 'SenderTypeID', Operator => 'EQ', Type => "NUMERIC", Value => $SenderTypeID });
    }

    my @StateTypeIDs;
    my $ReminderStateTypeID = $Kernel::OM->Get('State')->StateTypeLookup(
        StateType => 'pending reminder',
    );
    if ($ReminderStateTypeID) {
        push(@StateTypeIDs, $ReminderStateTypeID);
    }
    my $AutoStateTypeID = $Kernel::OM->Get('State')->StateTypeLookup(
        StateType => 'pending auto',
    );
    if ($AutoStateTypeID) {
        push(@StateTypeIDs, $AutoStateTypeID);
    }
    if (@StateTypeIDs) {
        push(@ANDs, { Field => 'StateTypeID', Operator => 'IN', Type => "NUMERIC", Value => \@StateTypeIDs });
    }

    my $ChannelID = $Kernel::OM->Get('Channel')->ChannelLookup( Name => 'note' );
    if ($ChannelID) {
        push(@ANDs, { Field => 'ChannelID', Operator => 'EQ', Type => "NUMERIC", Value => $ChannelID });
    }

    # create job
    my $JobID;

    if (@ANDs) {
        $JobID = $AutomationObject->JobAdd(
            Name       => $JobName,
            Type       => 'Ticket',
            Filter     => { AND => \@ANDs },
            Comment    => Encode::decode_utf8('Reopens ticket from pending by customer response.'),
            ValidID    => 1,
            UserID     => 1
        );
    } else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to prepare filter for \"$JobName\" job!"
        );
    }

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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
