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
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);
use Kernel::System::Role::Permission;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1849',
    },
);

use vars qw(%INC);

# sets the flag of the first value of dynamic fields and resource permissions
_SetFlagFirstValue();
_AddNewPermissions();

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
            Role   => 'Agent User',
            Type   => 'Resource',
            Target => '/objectsearch',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ},
        },
        {
            Role   => 'Customer',
            Type   => 'Resource',
            Target => '/objectsearch',
            Value  => Kernel::System::Role::Permission::PERMISSION->{READ},
        },
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

sub _SetFlagFirstValue {
    my ( $Self, %Param ) = @_;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => <<'END'
SELECT MIN(id)
FROM dynamic_field_value
GROUP BY object_id, field_id
END
    );

    # fetch the result
    my @IDs;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push(
            @IDs,
            $Row[0]
        );
    }

    if ( scalar(@IDs) ) {

        my @Conditions;
        # split IN statement with more than 900 elements in more statements combined with OR
        # because Oracle doesn't support more than 1000 elements for one IN statement.
        while ( @IDs ) {
            # remove section in the array
            my @IDPart = splice( @IDs, 0, 900 );

            # add condition part
            push(
                @Conditions,
                (
                    'id IN (' .
                    join( q{,}, @IDPart )
                    . ')'
                )
            );
        }

        my $Condition = join( q{ OR }, @Conditions );

        return if !$Kernel::OM->Get('DB')->Do(
            SQL => <<"END"
UPDATE dynamic_field_value
SET first_value = 1
WHERE $Condition
END
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
