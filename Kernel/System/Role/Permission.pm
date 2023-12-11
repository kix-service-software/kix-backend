# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Role::Permission;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    ClientRegistration
    Config
    Cache
    DB
    Log
    User
    Valid
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
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
            }
            return;
        }
    }

    if ( !defined $Param{Value} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need Value!"
            );
        }
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
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "A permission with the same type and target already exists for this role.",
            );
        }
        return;
    }

    if ( !$Self->ValidatePermission(%Param) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "The permission target is invalid.",
            );
        }
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

    # update change_time and change_by on role object
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE roles SET '
            . 'change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [            
            \$Param{UserID}, \$Param{RoleID}
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
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
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

    # update change_time and change_by on role object
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE roles SET '
            . 'change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [            
            \$Param{UserID}, \$Data{RoleID}
        ],
    );    

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Role.Permission',
        ObjectID  => $Data{RoleID}.'::'.$Param{ID},
    );

    return 1;
}

=item PermissionList()

returns array of all PermissionIDs for a role

    my @PermissionIDs = $RoleObject->PermissionList(
        RoleID       => 1,                                    # optional, ignored if RoleIDs is given
        RoleIDs      => [1,2,3],                              # optional
        Types        => ['Resource', 'Base::Ticket'],         # optional
        Target       => '...'                                 # optional
        UsageContext => 'Customer'                            # optional, or 'Agent'
    );

the result looks like

    @PermissionIDs = (
        1,
        2,
        3
    );

=cut

sub PermissionList {
    my ( $Self, %Param ) = @_;

    my @RoleIDs = $Param{RoleIDs} ? $Param{RoleIDs} : $Param{RoleID} ? ( $Param{RoleID} ) : ();

    # create cache key
    my $CacheKey = 'PermissionList::' . join(',', @RoleIDs) . '::' . join(',', @{$Param{Types}||[]}) . '::' . ($Param{Target}||'') . '::' . ($Param{UsageContext}||'');

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    my $SQL = 'SELECT rp.id FROM role_permission rp, permission_type pt, roles r WHERE pt.id = rp.type_id AND r.id = rp.role_id';

    my @Bind;

    if( $Param{UsageContext} ) {
        $SQL .= ' AND r.usage_context IN (?, 3)';
        push @Bind, \Kernel::System::Role->USAGE_CONTEXT->{uc($Param{UsageContext})};
    }

    if ( @RoleIDs ) {
        $SQL .= ' AND rp.role_id IN (' . join( ', ', map {'?'} @RoleIDs ) . ')';
        push @Bind, map { \$_ } @RoleIDs;
    }

    if ( IsArrayRefWithData($Param{Types}) ) {
        $SQL .= ' AND pt.name IN (' . join( ', ', map {'?'} @{ $Param{Types} } ) . ')';
        push @Bind, map { \$_ } @{ $Param{Types} };
    }

    if ( $Param{Target} ) {
        $SQL .= ' AND rp.target LIKE ?';
        push @Bind, \$Param{Target};
    }

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => $SQL,
        Bind => \@Bind,
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

=item PermissionListGet()

returns a hash of all permissions for a role

    my @Permissions = $RoleObject->PermissionListGet(
        RoleID => 1,
        Types  => ['Resource', 'Base::Ticket'],         # optional
        Target => '...'                                 # optional
    );

the result looks like

    @Permissions = (
        {...},
        {...},
        {...}
    );

=cut

sub PermissionListGet {
    my ( $Self, %Param ) = @_;

    # create cache key
    my $CacheKey = 'PermissionListGet::' . ($Param{RoleID}||'') . '::' . join(',', @{$Param{Types}||[]}) . '::' . ($Param{Target}||'');

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    my @PermissionIDs = $Self->PermissionList(%Param);

    my @Result;
    foreach my $PermissionID ( @PermissionIDs ) {
        my %Permission = $Self->PermissionGet(
            ID => $PermissionID
        );
        if ( %Permission ) {
            push @Result, \%Permission;
        }
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
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Role.Permission',
        ObjectID  => $Data{RoleID}.'::'.$Param{ID},
    );

    return 1;

}

=item PermissionListForObject()

returns a list of directly assigned permissions for the given object (atm only BasePermissions are supported)

    my %Permissions = $UserObject->PermissionsListForObject(
        RelevantBasePermissions => [ 'Base::Ticket' ]
        Target                  => '/ticket/queues/1',
    );

returns
    [
        {...},
        {...}
    ]

=cut

sub PermissionListForObject {
    my ( $Self, %Param ) = @_;

    # atm only BasePermissions are supported...
    return if !$Param{RelevantBasePermissions};

    # check needed stuff
    foreach my $Key ( qw(Target) ) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            return;
        }
    }

    my %PermissionTypeList = reverse $Self->PermissionTypeList();

    my %BasePermissionTypes;
    foreach my $BasePermission ( @{$Param{RelevantBasePermissions}||[]} ) {
        $BasePermissionTypes{$PermissionTypeList{$BasePermission}} = $BasePermission;
    }

    my @Result;

    # get all relevant permissions for this object
    my @PermissionList = $Self->PermissionListGet(
        Types  => $Param{RelevantBasePermissions},
        Target => $Param{Target},
    );

    foreach my $Permission ( @PermissionList ) {
        my $ValueStr = $Self->GetReadablePermissionValue(
            Value  => $Permission->{Value},
            Format => 'Long'
        );

        push @Result, {
            Type       => 'Base',
            RoleID     => $Permission->{RoleID},
            Permission => $ValueStr,
        };
    }

    return @Result;
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
        Format => 'Short|Long|ExtraLong'          # default is Short
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

    if ( $Param{Format} && $Param{Format} =~ /Long/ ) {
        my %Permissions;
        foreach my $PermissionName ( reverse sort keys %{$Self->PERMISSION} ) {
            next if $PermissionName eq 'NONE';
            next if ($Permissions{WRITE} && $PermissionName =~ /CREATE|UPDATE|DELETE/);
            next if ($Param{Value} & $Self->PERMISSION->{$PermissionName}) != $Self->PERMISSION->{$PermissionName};
            $Permissions{$PermissionName} = 1;
        }
        if ( $Param{Format} eq 'ExtraLong' ) {
            $Result = (join(' + ', sort keys %Permissions) || 'NONE') . ' (0x'. (sprintf('%04x', $Param{Value})).')';
            $Result = 'NONE' if !$Result;
        }
        else {
            $Result = join('+', sort keys %Permissions);
        }
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
