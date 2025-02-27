#!/usr/bin/perl
# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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
use Kernel::System::Role::Permission;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1883',
    },
);

use vars qw(%INC);

# add the new job
_AddUnlockJob();

# add virtual fs ressource permission
_AddNewPermissions();

sub _AddUnlockJob {
    my ( $Self, %Param ) = @_;

    my $JobName = 'Owner Out Of Office - unlock ticket';

    my $AutomationObject = $Kernel::OM->Get('Automation');

    # create execution plan
    my $ExecPlanID1 = $AutomationObject->ExecPlanAdd(
        Name       => "Event based Execution Plan for Job \"$JobName\"",
        Type       => 'EventBased',
        Parameters => {
            Event => [ 'ArticleCreate' ]
        },
        Comment    => "Event based Execution Plan for Job \"$JobName\"",
        ValidID    => 1,
        UserID     => 1
    );
    if ( !$ExecPlanID1 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to create event based execution plan for \"$JobName\" job!"
        );
        return;
    }
    my $ExecPlanID2 = $AutomationObject->ExecPlanAdd(
        Name       => "Time based Execution Plan for Job \"$JobName\"",
        Type       => 'TimeBased',
        Parameters => {
            "Weekday" => ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'],
            "Time"    => ['00:00','06:00','12:00','18:00']
        },
        Comment    => "Time based Execution Plan for Job \"$JobName\"",
        ValidID    => 1,
        UserID     => 1
    );
    if ( !$ExecPlanID2 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to create time based execution plan for \"$JobName\" job!"
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
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to create macro for \"$JobName\" job!"
        );

        # removed created execution plan
        $AutomationObject->ExecPlanDelete(
            ID => $ExecPlanID1,
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
                OwnerLoginOrID => '1'
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

    my @ANDs1 = ( { Field => 'OwnerOutOfOffice', Operator => 'EQ', Type => "NUMERIC", Value => '1' } );
    my @ANDs2 = ( { Field => 'OwnerOutOfOffice', Operator => 'EQ', Type => "NUMERIC", Value => '1' } );

    my $LockID = $Kernel::OM->Get('Lock')->LockLookup( Lock => 'lock' );
    if ($LockID) {
        push(@ANDs1, { Field => 'LockID', Operator => 'EQ', Type => "NUMERIC", Value => $LockID });
        push(@ANDs2, { Field => 'LockID', Operator => 'EQ', Type => "NUMERIC", Value => $LockID });
    }

    my @StateTypeIDs1;
    my @StateTypeIDs2;
    my $ReminderStateTypeID = $Kernel::OM->Get('State')->StateTypeLookup(
        StateType => 'pending reminder',
    );
    if ($ReminderStateTypeID) {
        push(@StateTypeIDs1, $ReminderStateTypeID);
    }
    my $NewStateTypeID = $Kernel::OM->Get('State')->StateTypeLookup(
        StateType => 'new',
    );
    if ($NewStateTypeID) {
        push(@StateTypeIDs2, $NewStateTypeID);
    }
    my $OpenStateTypeID = $Kernel::OM->Get('State')->StateTypeLookup(
        StateType => 'open',
    );
    if ($OpenStateTypeID) {
        push(@StateTypeIDs2, $OpenStateTypeID);
    }
    if (@StateTypeIDs1) {
        push(@ANDs1, { Field => 'StateTypeID', Operator => 'IN', Type => "NUMERIC", Value => \@StateTypeIDs1 });
        push(@ANDs1, { Field => 'PendingTime', Operator => 'LT', Type => "DATETIME", Value => '-0m' });
    }
    if (@StateTypeIDs2) {
        push(@ANDs2, { Field => 'StateTypeID', Operator => 'IN', Type => "NUMERIC", Value => \@StateTypeIDs2 });
    }

    # create job
    my $JobID;

    if (
        @ANDs1
        && @ANDs2
    ) {
        $JobID = $AutomationObject->JobAdd(
            Name       => $JobName,
            Type       => 'Ticket',
            Filter     => [
                { AND => \@ANDs1 },
                { AND => \@ANDs2 }
            ],
            Comment    => Encode::decode_utf8('Unlock ticket when owner is out of office.'),
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
            ID => $ExecPlanID1,
        );
        $AutomationObject->ExecPlanDelete(
            ID => $ExecPlanID2,
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
        ExecPlanID => $ExecPlanID1,
        UserID     => 1
    );
    if (!$Result) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to assign event based execution plan ($ExecPlanID1) to \"$JobName\" job ($JobID)!"
        );
    }

    # assign execution plan to job
    $Result = $Kernel::OM->Get('Automation')->JobExecPlanAdd(
        JobID      => $JobID,
        ExecPlanID => $ExecPlanID1,
        UserID     => 1
    );
    if (!$Result) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to assign time based execution plan ($ExecPlanID2) to \"$JobName\" job ($JobID)!"
        );
    }

    return 1;
}

sub _AddNewPermissions {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Log');
    my $DBObject   = $Kernel::OM->Get('DB');
    my $RoleObject = $Kernel::OM->Get('Role');

    my %RoleList           = reverse $RoleObject->RoleList();
    my %PermissionTypeList = reverse $RoleObject->PermissionTypeList();

    # add new permissions
    my @NewPermissions = (
        {
            Role   => 'Customer',
            Type   => 'Resource',
            Target => '/virtualfs',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ},
        },
        {
            Role   => 'Customer Manager',
            Type   => 'Resource',
            Target => '/virtualfs',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ},
        },
        {
            Role   => 'Ticket Agent',
            Type   => 'Resource',
            Target => '/virtualfs',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ},
        },
        {
            Role   => 'FAQ Reader',
            Type   => 'Resource',
            Target => '/virtualfs',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ},
        }
    );

    my $PermissionID;
    my $AllPermsOK = 1;
    foreach my $Permission (@NewPermissions) {
        my $RoleID = $RoleList{$Permission->{Role}};
        if (!$RoleID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find role "'
                    . $Permission->{Role}
                    . q{"!}
            );
            next;
        }
        my $PermissionTypeID = $PermissionTypeList{$Permission->{Type}};
        if (!$PermissionTypeID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find permission type "'
                    . $Permission->{Type}
                    . q{"!}
            );
            next;
        }

        # check if permission is needed
        $PermissionID = $RoleObject->PermissionLookup(
            RoleID => $RoleID,
            TypeID => $PermissionTypeID,
            Target => $Permission->{Target}
        );
        next if ($PermissionID);

        $PermissionID = $RoleObject->PermissionAdd(
            RoleID     => $RoleID,
            TypeID     => $PermissionTypeID,
            Target     => $Permission->{Target},
            Value      => $Permission->{Value},
            IsRequired => 0,
            Comment    => q{},
            UserID     => 1,
        );

        if (!$PermissionID) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Unable to add permission (role=$Permission->{Role}, type=$Permission->{Type}, target=$Permission->{Target})!"
            );
            $AllPermsOK = 0;
        }
        else {
            $LogObject->Log(
                Priority => 'info',
                Message  => "Added permission (role=$Permission->{Role}, type=$Permission->{Type}, target=$Permission->{Target})."
            );
        }
    }


    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

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
