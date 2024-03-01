# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Role::User;

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

=head1 NAME

Kernel::System::Role::User - user functions for roles lib

=head1 SYNOPSIS

All role functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item RoleUserAdd()

add a user to the role

    my $Success = $RoleObject->RoleUserAdd(
        RoleID => 6,
        AssignUserID => 12,
        UserID => 123,
    );

=cut

sub RoleUserAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(AssignUserID RoleID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # check if relation already exists in database
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => <<'END',
SELECT role_id
FROM role_user
WHERE user_id = ?
    AND role_id = ?
END
        Bind  => [ \$Param{AssignUserID}, \$Param{RoleID} ],
        Limit => 1,
    );
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        return 1;
    }

    # insert new relation
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'INSERT INTO role_user '
            . '(user_id, role_id, create_time, create_by, change_time, change_by) '
            . 'VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [ \$Param{AssignUserID}, \$Param{RoleID}, \$Param{UserID}, \$Param{UserID} ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Role.User',
        ObjectID  => $Param{RoleID}.'::'.$Param{AssignUserID},
    );

    return 1;
}

=item BasePermissionAgentList()

returns a list with all users (is_agent=1) for given base permission

    my @UserList = $RoleObject->BasePermissionAgentList(
        Target  => 2,       # e.g. QueueID
        Value   => 6,       # Permission Value (CRUD)
    );

    @UserList = (
        1,
        2,
        3
    );

=cut

sub BasePermissionAgentList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    foreach my $Key ( qw(Target Value) ) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            return;
        }
    }

    # create cache key
    my $CacheKey = 'BasePermissionAgentList::' . $Param{Target} . '::' . $Param{Value};

    if( $Param{Strict} ) {
        $CacheKey .= '::' . $Param{Strict}
    }

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    my $SQL = << 'END';
        SELECT DISTINCT(ru.user_id)
        FROM role_user as ru
        JOIN role_permission as rp
            ON ru.role_id=rp.role_id
        JOIN permission_type as pt
            ON pt.id=rp.type_id
        JOIN users as u
            ON ru.user_id=u.id
        WHERE pt.name='Base::Ticket'
            AND rp.target IN ('*', ?)
            AND u.valid_id=1
            AND u.is_agent=1
END

    my @Bind = ( \$Param{Target}, \$Param{Value} );

    if ( $Param{Strict} ) {
        $SQL .= ' AND rp.value=?'
    } else {
        $SQL .= ' AND (rp.value&?)=?';
        push ( @Bind, \$Param{Value} );
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

=item RoleUserList()

returns a list with all users of a role

    my @UserList = $RoleObject->RoleUserList(
        RoleID => 123,
    );

    my @UserList = $RoleObject->RoleUserList(
        RoleIDs => [ 123, 345 ],
    );

    @UserList = (
        1,
        2,
        3
    );

=cut

sub RoleUserList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{RoleID} && !IsArrayRefWithData($Param{RoleIDs}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need RoleID or RoleIDs!"
        );
        return;
    }

    my @RoleIDs = IsArrayRefWithData($Param{RoleIDs}) ? @{$Param{RoleIDs}} : ( $Param{RoleID} );

    # create cache key
    my $CacheKey = 'RoleUserList::' . join(',', @RoleIDs);

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'SELECT DISTINCT(user_id) FROM role_user WHERE role_id IN ('.join( ', ', map {'?'} @RoleIDs ).') ORDER BY user_id',
        Bind => [ map { \$_ } @RoleIDs ],
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

=item UserRoleList()

return a list of all roles of a given user

    my @RoleIDs = $RoleObject->UserRoleList(
        UserID       => 123,                    # required
        UsageContext => 'Agent'|'Customer'      # optional, if not given, all assigned roles will be returned
        Valid        => 1                       # optional
    );

=cut

sub UserRoleList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # set default value
    my $Valid = $Param{Valid} ? 1 : 0;

    # check cache
    my $CacheKey = 'UserRoleList::' . $Param{UserID} . '::' . $Valid . '::' . ($Param{UsageContext} || '');
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');
    my @Bind     = ();
    push @Bind, \$Param{UserID};

    # create sql
    my $SQL = 'SELECT u.role_id, r.usage_context FROM role_user u LEFT JOIN roles r ON r.id = u.role_id WHERE u.user_id = ?';

    if ( $Valid ) {
        $SQL .= ' AND valid_id = 1';
    }

    # get data
    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    # fetch the result
    my @Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        # check if this role is valid for the given usage context
        next if ( $Param{UsageContext} && ($Row[1] & Kernel::System::Role->USAGE_CONTEXT->{uc($Param{UsageContext})}) != Kernel::System::Role->USAGE_CONTEXT->{uc($Param{UsageContext})} );

        push(@Result, $Row[0]);
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \@Result,
    );

    return @Result;
}

=item RoleUserDelete()

remove a user from the role

    my $Success = $RoleObject->RoleUserDelete(
        RoleID => 6,                    # required if UserID not given
        UserID => 12,                   # required if RoleID not given
        IgnoreContextRoles => 1,        # optional, don't delete the base roles assigned by the user context
    );

=cut

sub RoleUserDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{RoleID} && !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need either RoleID or UserID or both!"
        );
        return;
    }

    my $SQL = 'DELETE FROM role_user';

    my @Where;
    my @Bind;
    if ( $Param{IgnoreContextRoles} ) {
        my $RoleNameAgent    = 'Agent User';
        my $RoleNameCustomer = 'Customer';

        push( @Where, 'role_id NOT IN (SELECT id FROM roles WHERE name IN (?, ?))' );
        push( @Bind, \$RoleNameAgent, \$RoleNameCustomer );
    }
    if ( $Param{UserID} ) {
        push( @Where, 'user_id = ?' );
        push( @Bind, \$Param{UserID} );
    }
    if ( $Param{RoleID} ) {
        push( @Where, 'role_id = ?' );
        push( @Bind, \$Param{RoleID} );
    }

    if ( @Where ) {
        $SQL .= ' WHERE ' . join( ' AND ', @Where );
    }

    # delete existing RoleUser relation
    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Role.User',
        ObjectID  => ($Param{RoleID} || 'ALL').'::'.($Param{UserID} || 'ALL'),
    );

    return 1;
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
