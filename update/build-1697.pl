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
        LogPrefix => 'framework_update-to-build-1697',
    },
);

use vars qw(%INC);

_AddNewPermissions();
_AddNewRole();

# allow only customer relevant user
sub _AddNewPermissions {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Log');
    my $DBObject = $Kernel::OM->Get('DB');
    my $RoleObject = $Kernel::OM->Get('Role');

    my %RoleList           = reverse $RoleObject->RoleList();
    my %PermissionTypeList = reverse $RoleObject->PermissionTypeList();

    # add new permissions
    my @NewPermissions = (
        {
            Role   => 'Superuser',
            Type   => 'Base::Ticket',
            Target => '*',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ} + Kernel::System::Role::Permission::PERMISSION->{WRITE},
        },
        {
            Role   => 'Ticket Agent',
            Type   => 'Base::Ticket',
            Target => '*',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ} + Kernel::System::Role::Permission::PERMISSION->{WRITE},
        },
        {
            Role   => 'Ticket Reader',
            Type   => 'Base::Ticket',
            Target => '*',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ},
        },
        {
            Role   => 'Customer',
            Type   => 'Base::Ticket',
            Target => '*',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ} + Kernel::System::Role::Permission::PERMISSION->{WRITE},
        },
    );

    my $PermissionID;
    my $AllPermsOK = 1;
    foreach my $Permission (@NewPermissions) {
        my $RoleID = $RoleList{$Permission->{Role}};
        if (!$RoleID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find role "'.$Permission->{Role}.'"!'
            );
            next;
        }
        my $PermissionTypeID = $PermissionTypeList{$Permission->{Type}};
        if (!$PermissionTypeID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find permission type "'.$Permission->{Type}.'"!'
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
            Comment    => '',
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


sub _AddNewRole {
    my ( $Self, %Param ) = @_;

    my $RoleObject = $Kernel::OM->Get('Role');

    my %RoleList = reverse $RoleObject->RoleList();
    my %PermissionTypeList = reverse $RoleObject->PermissionTypeList();

    my @NewRoles = (
        {
            Name => 'Ticket Agent Base Permission',
            Comment => Kernel::Language::Translatable('allows basic ticket access, but requires team specific roles with base permissions'),
            UsageContext => 1
        }
    );

    foreach my $Role ( @NewRoles ) {
        my $RoleID = $RoleObject->RoleAdd(
            %{$Role},
            ValidID => 1,
            UserID  => 1
        );
        if ( !$RoleID ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create role \"$Role->{Name}\"!",
            );
            next;
        } else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Created role \"$Role->{Name}\"",
            );
        }
    }

    # reload role list
    %RoleList = reverse $RoleObject->RoleList();

    my @NewPermissions = (
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/tickets',
            Value  => Kernel::System::Role::Permission::PERMISSION_CRUD
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/system/ticket/*',
            Value  => Kernel::System::Role::Permission::PERMISSION->{NONE}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/system/ticket',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/system/ticket/locks',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/system/ticket/priorities',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/system/ticket/queues',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/system/ticket/states',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/system/ticket/types',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/system/communication',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/system/communication/*',
            Value  => Kernel::System::Role::Permission::PERMISSION->{NONE}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/system/communication/channels',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/system/communication/sendertypes',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/system/communication/systemaddresses',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/organisations',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/contacts',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/links',
            Value  => Kernel::System::Role::Permission::PERMISSION_CRUD
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/system/textmodules',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/reporting',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/reporting/reports',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Object',
            Target => '/reporting/reports/*{Report.DefinitionID !IN [3,4,5,6,7,8]}',
            Value  => Kernel::System::Role::Permission::PERMISSION->{NONE}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/reporting/reportdefinitions',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/reporting/reportdefinitions/*',
            Value  => Kernel::System::Role::Permission::PERMISSION->{NONE}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/reporting/reportdefinitions/3',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/reporting/reportdefinitions/4',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/reporting/reportdefinitions/5',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/reporting/reportdefinitions/6',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/reporting/reportdefinitions/7',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/reporting/reportdefinitions/8',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/system/htmltopdf',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Resource',
            Target => '/system/htmltopdf/convert',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ}
        },
        {
            Role   => 'Ticket Agent Base Permission',
            Type   => 'Base::Ticket',
            Target => '*',
            Value  => Kernel::System::Role::Permission::PERMISSION->{NONE}
        }
    );

    foreach my $Permission (@NewPermissions) {
        my $RoleID = $RoleList{$Permission->{Role}};
        if (!$RoleID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find role "' . $Permission->{Role} . '"!'
            );
            next;
        }
        my $PermissionTypeID = $Permission->{TypeID} || $PermissionTypeList{$Permission->{Type}};
        if (!$PermissionTypeID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find permission type "' . $Permission->{Type} . '"!'
            );
            next;
        }

        my $PermissionID = $RoleObject->PermissionLookup(
            RoleID => $RoleID,
            TypeID => $PermissionTypeID,
            Target => $Permission->{Target}
        );
        # nothing to do if this permission already exists
        next if $PermissionID;

        $PermissionID = $RoleObject->PermissionAdd(
            UserID => 1,
            RoleID => $RoleID,
            TypeID => $PermissionTypeID,
            %{$Permission},
        );

        if (!$PermissionID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create permission (role=$Permission->{Role}, type=$Permission->{Type}, target=$Permission->{Target})!"
            );
        } else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Created permission ID $PermissionID!"
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
