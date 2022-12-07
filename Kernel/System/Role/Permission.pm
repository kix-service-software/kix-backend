# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Role::Permission;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
);

# just for convenience
use constant PERMISSION_CRUD => 0x000F;

# define permission bit values
use constant PERMISSION => {
    NONE   => 0x0000,
    CREATE => 0x0001,
    READ   => 0x0002,
    UPDATE => 0x0004,
    DELETE => 0x0008,
    WRITE  => 0x000D,       # combined permission used for base permissions (CREATE+UPDATE+DELETE)
    DENY   => 0xF000,
};

=head1 NAME

Kernel::System::Role::Permission - permission extension for roles lib

=head1 SYNOPSIS

All role functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item PermissionTypeList()

returns a list of valid system permissions.

    %PermissionTypeList = $RoleObject->PermissionTypeList(
        Valid => 1          # optional
    );

=cut

sub PermissionTypeList {
    my ( $Self, %Param ) = @_;

    # set default value
    my $Valid = $Param{Valid} ? 1 : 0;

    # create cache key
    my $CacheKey = 'PermissionTypeList::' . $Valid;

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $SQL = 'SELECT id, name FROM permission_type';

    if ( $Param{Valid} ) {
        $SQL .= ' WHERE valid_id = 1'
    }

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => $SQL,
    );

    my %Result;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $Result{$Row[0]} = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \%Result,
        TTL   => $Self->{CacheTTL},
    );

    return %Result;
}

=item PermissionTypeGet()

returns the requested permission type.

    %PermissionType = $RoleObject->PermissionTypeGet(
        ID => 1
    );

This returns something like:

    %PermissionType = (
        'ID'         => 2,
        'Name'       => '...',
        'Comment'    => '...',
        'ValidID'    => '1',
        'CreateTime' => '2010-04-07 15:41:15',
        'CreateBy'   => 1,
        'ChangeTime' => '2010-04-07 15:41:15',
        'ChangeBy'   => 1
    );

=cut

sub PermissionTypeGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ID!'
        );
        return;
    }

    # check cache
    my $CacheKey = 'PermissionTypeGet::' . $Param{ID};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => "SELECT id, name, comments, valid_id, create_time, create_by, change_time, change_by FROM permission_type WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    my %Result;

    # fetch the result
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        %Result = (
            ID         => $Row[0],
            Name       => $Row[1],
            Comment    => $Row[2],
            ValidID    => $Row[3],
            CreateTime => $Row[4],
            CreateBy   => $Row[5],
            ChangeTime => $Row[6],
            ChangeBy   => $Row[7],
        );
    }

    # no data found...
    if ( !%Result ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "PermissionType with ID $Param{ID} not found!",
        );
        return;
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Result,
    );

    return %Result;
}

=item PermissionTypeLookup()

get id for permission type parameters

    my $PermissionTypeID = $RoleObject->PermissionTypeLookup(
        Name => '...'
    );

=cut

sub PermissionTypeLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # create cache key
    my $CacheKey = 'PermissionTypeLookup::' . $Param{Name};

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'SELECT id FROM permission_type WHERE name = ?',
        Bind => [
            \$Param{Name},
        ]
    );

    my $Result;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $Result = $Row[0];
    }

    if ( $Result ) {
        # set cache
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            Key   => $CacheKey,
            Value => $Result,
            TTL   => $Self->{CacheTTL},
        );
    }

    return $Result;
}

=item PermissionLookup()

get id for permission parameters

    my $PermissionID = $RoleObject->PermissionLookup(
        RoleID => 1,
        TypeID => 1,
        Target => '/tickets'
    );

=cut

sub PermissionLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(RoleID TypeID Target)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # create cache key
    my $CacheKey = 'PermissionLookup::' . $Param{RoleID}.'::'.$Param{TypeID}.'::'.$Param{Target};

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'SELECT id FROM role_permission WHERE role_id = ? AND type_id = ? AND target = ?',
        Bind => [
            \$Param{RoleID}, \$Param{TypeID}, \$Param{Target},
        ]
    );

    my $Result;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $Result = $Row[0];
    }

    if ( $Result ) {
        # set cache
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            Key   => $CacheKey,
            Value => $Result,
            TTL   => $Self->{CacheTTL},
        );
    }

    return $Result;
}

=item PermissionGet()

returns a hash with permission data

    my %PermissionData = $RoleObject->PermissionGet(
        ID => 2,
    );

This returns something like:

    %PermissionData = (
        'ID'         => 2,
        'TypeID'     => 1,
        'Target'     => '/tickets',
        'Value'      => 0x000F,
        'isRequired' => 0,
        'Comment'    => 'Full permission on tickets resource',
        'ValidID'    => '1',
        'CreateTime' => '2010-04-07 15:41:15',
        'CreateBy'   => 1,
        'ChangeTime' => '2010-04-07 15:41:15',
        'ChangeBy'   => 1
    );

=cut

sub PermissionGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ID!'
        );
        return;
    }

    # check cache
    my $CacheKey = 'PermissionGet::' . $Param{ID};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => "SELECT id, role_id, type_id, target, value, is_required, comments, create_time, create_by, change_time, change_by FROM role_permission WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    my %Result;

    # fetch the result
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        %Result = (
            ID         => $Row[0],
            RoleID     => $Row[1],
            TypeID     => $Row[2],
            Target     => $Row[3],
            Value      => $Row[4],
            IsRequired => $Row[5],
            Comment    => $Row[6],
            CreateTime => $Row[7],
            CreateBy   => $Row[8],
            ChangeTime => $Row[9],
            ChangeBy   => $Row[10],
        );
    }

    # no data found...
    if ( !%Result ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Permission with ID $Param{ID} not found!",
        );
        return;
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Result,
    );

    return %Result;
}

=item PermissionAdd()

adds a new permission

    my $ID = $RoleObject->PermissionAdd(
        RoleID     => 123,
        TypeID     => 1,
        Target     => '/tickets',
        Value      => 0x000F,
        IsRequired => 0,                                       # optional
        Comment    => 'Full permission of resource tickets',   # optional
        UserID     => 123,
    );

=cut

sub PermissionAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(RoleID TypeID Target UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    if ( !defined $Param{Value} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Value!"
        );
        return;
    }

    $Param{IsRequired} ||= 0;

    # check if this is a duplicate after the change
    my $ID = $Self->PermissionLookup(
        RoleID => $Param{RoleID},
        TypeID => $Param{TypeID},
        Target => $Param{Target}
    );
    if ( $ID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A permission with the same type and target already exists for this role.",
        );
        return;
    }

    if ( !$Self->ValidatePermission(%Param) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The permission target is invalid.",
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # insert
    return if !$DBObject->Do(
        SQL => 'INSERT INTO role_permission (role_id, type_id, target, value, is_required, comments, '
            . 'create_time, create_by, change_time, change_by) '
            . 'VALUES (?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{RoleID}, \$Param{TypeID}, \$Param{Target}, \$Param{Value},
            \$Param{IsRequired}, \$Param{Comment}, \$Param{UserID}, \$Param{UserID}
        ],
    );

    # get new id
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM role_permission WHERE role_id = ? AND type_id = ? AND target = ?',
        Bind => [
            \$Param{RoleID}, \$Param{TypeID}, \$Param{Target},
        ],
    );

    # fetch the result
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Role.Permission',
        ObjectID  => $Param{RoleID}.'::'.$ID,
    );

    return $ID;
}

=item PermissionUpdate()

updates a permission

    my $Success = $RoleObject->PermissionUpdate(
        ID         => 123,
        TypeID     => 1,                                        # optional
        Target     => '/tickets',                               # optional
        Value      => 0x000F,                                   # optional
        IsRequired => 0,                                        # optional
        Comment    => 'Full permission of resource tickets',    # optional
        UserID     => 123,
    );

=cut

sub PermissionUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # get current data
    my %Data = $Self->PermissionGet(
        ID => $Param{ID},
    );

    # check if this is a duplicate after the change
    my $ID = $Self->PermissionLookup(
        RoleID => $Data{RoleID},
        TypeID => $Param{TypeID} || $Data{TypeID},
        Target => $Param{Target} || $Data{Target},
    );
    if ( $ID && $ID != $Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A permission with the same type and target already exists for this role.",
        );
        return;
    }

    my $ValidationResult = $Self->ValidatePermission(
        TypeID => $Param{TypeID} || $Data{TypeID},
        Target => $Param{Target} || $Data{Target},
        Value  => defined $Param{Value} ? $Param{Value} : $Data{Value},
    );
    if ( !$ValidationResult ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The permission target doesn't match the possible ones for given type.",
        );
        return;
    }

    # set default value
    $Param{Comment} ||= '';

    # check if update is required
    my $ChangeRequired;
    KEY:
    for my $Key ( qw(TypeID Target Value IsRequired Comment) ) {
        next KEY if defined $Data{$Key} && defined $Param{Key} && $Data{$Key} eq $Param{$Key};

        $ChangeRequired = 1;
    }

    return 1 if !$ChangeRequired;

    $Param{TypeID}     ||= $Data{TypeID};
    $Param{Target}     ||= $Data{Target};
    $Param{Value}      ||= $Data{Value} if !defined $Param{Value};
    $Param{IsRequired} ||= $Data{IsRequired} if !defined $Param{IsRequired};

    # update role in database
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE role_permission SET type_id = ?, target = ?, value = ?, is_required = ?, comments = ?, '
            . 'change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [
            \$Param{TypeID}, \$Param{Target}, \$Param{Value}, \$Param{IsRequired},
            \$Param{Comment}, \$Param{UserID}, \$Param{ID}
        ],
    );

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Role.Permission',
        ObjectID  => $Data{RoleID}.'::'.$Param{ID},
    );

    return 1;
}

=item PermissionList()

returns a hash of all permissions for a role

    my @Permissions = $RoleObject->PermissionList(
        RoleID => 1
    );

the result looks like

    @Permissions = (
        1,
        2,
        3
    );

=cut

sub PermissionList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(RoleID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # create cache key
    my $CacheKey = 'PermissionList::' . $Param{RoleID};

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'SELECT id FROM role_permission WHERE role_id = ?',
        Bind => [ \$Param{RoleID} ]
    );

    my @Result;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push(@Result, $Row[0]);
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \@Result,
        TTL   => $Self->{CacheTTL},
    );

    return @Result;
}

=item PermissionDelete()

delete a permission entry

    my $Success = $RoleObject->PermissionDelete(
        ID => 123,
    );

=cut

sub PermissionDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get current data
    my %Data = $Self->PermissionGet(
        ID => $Param{ID},
    );

    # get database object
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM role_permission WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Role.Permission',
        ObjectID  => $Data{RoleID}.'::'.$Param{ID},
    );

    return 1;

}

=item PermissionListForObject()

returns a two lists of directly assigned permissions für the given object

    my %Permissions = $UserObject->PermissionsListForObject(
        RelevantObjectPermissions => [ 'Queue-to-Ticket' ]
        Target       => '/queue/1',
        ObjectID     => 123
        ObjectIDAttr => 'QueueID',
    );

returns
    {
        Assigned => [],
        DependingObjects => [],
    }

=cut

sub PermissionListForObject {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    foreach my $Key ( qw(Target ObjectID ObjectIDAttr) ) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            return;
        }
    }

    # prepare relevant Object patterns
    my %RelevantObjectPermissions;
    if ( IsArrayRefWithData($Param{RelevantObjectPermissions}) ) {
        my $Config = $Kernel::OM->Get('Config')->Get('Permission::Object');
        if ( IsHashRefWithData($Config) ) {
            foreach my $Key ( @{$Param{RelevantObjectPermissions}} ) {
                foreach my $Pattern ( values %{$Config->{$Key}} ) {
                    my $PreparedPattern = $Pattern;
                    $PreparedPattern =~ s/<$Param{ObjectIDAttr}>/$Param{ObjectID}/g;
                    $RelevantObjectPermissions{$PreparedPattern} = 1;
                }
            }
        }
    }

    my %PermissionTypeList = reverse $Self->PermissionTypeList();

    # get all relevant permissions
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => "SELECT id FROM role_permission WHERE type_id IN (SELECT id FROM permission_type WHERE name IN ('Object', 'Object'))",
    );

    my @PermissionIDs;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push(@PermissionIDs, $Row[0]);
    }

    my @AssignedPermissions;
    my @DependingObjectsPermissions;
    foreach my $ID ( sort @PermissionIDs ) {
        my %Permission = $Self->PermissionGet(
            ID => $ID,
        );

        if ( !%Permission ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to get permission ID $ID!"
            );
            return;
        }

        # ignore permissions of type Resource without filters (non Object)
        next if ( $Permission{TypeID} == $PermissionTypeList{Resource} && $Permission{Target} !~ /[{}]/ );

        # ignore wildcard targets on type Object
        next if ( $PermissionTypeList{Object} && $Permission{Target} =~ /\*/ && $Permission{TypeID} == $PermissionTypeList{Object} );

        # prepare target
        my $Target = $Permission{Target};
        $Target =~ s/\//\\\//g;
        $Target =~ s/\{.+?\}//g;

        my @SplitParts = split(/\//, $Param{Target});
        my $ObjectID = $SplitParts[-1];

        # check for assigned permission
        if ( $Param{Target} =~ /^$Target/ ) {
            push(@AssignedPermissions, \%Permission);
        }

        # check for Object permission (depending objects)
        if ( $RelevantObjectPermissions{$Permission{Target}} ) {
            push(@DependingObjectsPermissions, \%Permission);
        }
    }

    return ( Assigned => \@AssignedPermissions, DependingObjects => \@DependingObjectsPermissions );
}

=item ValidatePermission()

returns true if the permission is valid

    my $Result = $RoleObject->ValidatePermission(
        TypeID => 3,
        Target => '...',
        Value  => 10
    );

=cut

sub ValidatePermission {
    my ( $Self, %Param ) = @_;

    # validate new Object permission
    my %PermissionTypeList = $Self->PermissionTypeList( Valid => 1 );

    # check type
    return if !$PermissionTypeList{$Param{TypeID}};

    if ( $PermissionTypeList{$Param{TypeID}} eq 'Object' ) {
        # check if the target contains a filter expression and the pattern matches the required format
        if ( $Param{Target} !~ /^.*?\{(\w+)\.(\w+)\s+!?(\w+)\s+(.*?)\}$/ && $Param{Target} !~ /^.*?\{\}$/ ) {
            return;
        }
    } elsif ( $PermissionTypeList{$Param{TypeID}} eq 'Property' ) {
        # check if the target contains a filter expression and the pattern matches the required format
        if ( $Param{Target} !~ /^.*?\{(\w+)\.\[(.*?)\](\s*IF\s+(.*?)\s*)?\}$/ && $Param{Target} !~ /^.*?\{\}$/ ) {
            return;
        }
    } elsif ( $PermissionTypeList{$Param{TypeID}} =~ /^Base::(.*?)$/ ) {
        # check if the target contains one of the supported object types and the value corresponds to an object id
        my $TargetObject = $Kernel::OM->Get($1);
        if ( !$TargetObject || !$TargetObject->can('BasePermissionValidate') || !$TargetObject->BasePermissionValidate(%Param)) {
            return;
        }
    }

    return 1;
}


=item GetReadablePermissionValue()

returns the permission value in a readable format

    my $ValueStr = $RoleObject->GetReadablePermissionValue(
        Value  => 123,
        Format => 'Short|Long'          # default is Short
    );

=cut

sub GetReadablePermissionValue {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Value)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $Result;

    if ( $Param{Format} && $Param{Format} eq 'Long' ) {
        my @Permissions;
        foreach my $PermissionName ( sort keys %{$Self->PERMISSION} ) {
            next if ($Param{Value} & $Self->PERMISSION->{$PermissionName}) != $Self->PERMISSION->{$PermissionName};
            push(@Permissions, $PermissionName);
        }
        $Result = (join(' + ', @Permissions) || 'NONE') . ' (0x'. (sprintf('%04x', $Param{Value})).')';
    }
    else {
        foreach my $PermissionName ( qw( CREATE READ UPDATE DELETE DENY ) ) {
            my $Short = substr($PermissionName, 0, 1);
            if ($PermissionName eq 'DENY') {
                $Short = 'X'
            }

            if ( ($Param{Value} & $Self->PERMISSION->{$PermissionName}) == $Self->PERMISSION->{$PermissionName} ) {
                $Result .= $Short;
            }
            else {
                $Result .= '-';
            }
        }
    }

    return $Result;
}

1;

=end Internal:





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
