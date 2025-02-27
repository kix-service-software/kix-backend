# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Lock;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'Valid',
);

=head1 NAME

Kernel::System::Lock - lock lib

=head1 SYNOPSIS

All lock functions.

The whole lock API is just for "reading" lock states. Per default you have "unlock", "lock" and "lock-tmp".
Usually you will not modify those lock states, because there is not usecase for this.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $LockObject = $Kernel::OM->Get('Lock');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'Lock';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    $Self->{ViewableLocks} = $Kernel::OM->Get('Config')->Get('Ticket::ViewableLocks')
        || die 'No Config entry "Ticket::ViewableLocks"!';

    return $Self;
}

=item LockViewableLock()

get list of viewable lock types (used to show available tickets)

    my @List = $LockObject->LockViewableLock(
        Type => 'Name', # ID|Name
    );

Returns:

    @List = ( 'unlock', 'lock', 'lock-tmp' );

    my @ListID = $LockObject->LockViewableLock(
        Type => 'ID', # ID|Name
    );

Returns:

    @List = ( 1, 2, 3 );

=cut

sub LockViewableLock {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check cache
    my $CacheKey = 'LockViewableLock::' . $Param{Type};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        TTL  => $Self->{CacheTTL},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    # sql
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => "
            SELECT id, name
            FROM ticket_lock_type
            WHERE name IN ( ${\(join ', ', @{$Self->{ViewableLocks}})} )
                AND valid_id IN ( ${\(join ', ', $Kernel::OM->Get('Valid')->ValidIDsGet())} )",
    );

    my @Name;
    my @ID;
    while ( my @Data = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push @Name, $Data[1];
        push @ID,   $Data[0];
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => 'LockViewableLock::Name',
        Value => \@Name,
    );
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => 'LockViewableLock::ID',
        Value => \@ID,
    );

    return @Name if $Param{Type} eq 'Name';
    return @ID;
}

=item LockLookup()

lock state lookup by ID or Name

    my $LockID = $LockObject->LockLookup( Lock => 'lock' );

    my $Lock = $LockObject->LockLookup( LockID => 2 );

=cut

sub LockLookup {
    my ( $Self, %Param ) = @_;

    # get (already cached) lock list
    my %LockList = $Self->LockList(
        UserID => 1,
    );

    my $Key;
    my $Value;
    my $ReturnData;
    if ( $Param{LockID} ) {
        $Key        = 'LockID';
        $Value      = $Param{LockID};
        $ReturnData = $LockList{ $Param{LockID} };
    }
    else {
        $Key   = 'Lock';
        $Value = $Param{Lock};
        my %LockListReverse = reverse %LockList;
        $ReturnData = $LockListReverse{ $Param{Lock} };
    }

    # check if data exists
    if ( !defined $ReturnData ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No $Key for $Value found!",
            );
        }
        return;
    }

    return $ReturnData;
}

=item LockList()

get lock state list

    my %List = $LockObject->LockList(
        UserID => 123,
    );

Returns:

    %List = (
        1 => 'unlock',
        2 => 'lock',
        3 => 'lock-tmp',
    );

=cut

sub LockList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'UserID!'
        );
        return;
    }

    # check cache
    my $CacheKey = 'LockList';
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        TTL  => $Self->{CacheTTL},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # sql
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT id, name FROM ticket_lock_type',
    );

    # fetch the result
    my %Data;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    );

    return %Data;
}

=item LockGet()

returns a hash with Lock data

    my %LockData = $LockObject->LockGet(
        LockID => 2,
    );

This returns something like:

    %LockData = (
        'Name'       => '...',
        'ID'         => 2,
        'ValidID'    => '1',
        'CreateTime' => '2010-04-07 15:41:15',CreateBy
        'CreateBy'   => 1,
        'ChangeTime' => '2010-04-07 15:41:15',ChangeBy
        'ChangeBy'   => 1,
    );

=cut

sub LockGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{LockID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'LockID!'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # sql
    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name, valid_id, '
            . 'create_time, create_by, change_time, change_by '
            . 'FROM ticket_lock_type WHERE id = ?',
        Bind  => [ \$Param{LockID} ],
    );

    # fetch the result
    my %Lock;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        $Lock{ID}         = $Data[0];
        $Lock{Name}       = $Data[1];
        $Lock{ValidID}    = $Data[2];
        $Lock{CreateTime} = $Data[3];
        $Lock{CreateBy}   = $Data[4];
        $Lock{ChangeTime} = $Data[5];
        $Lock{ChangeBy}   = $Data[6];
    }

    # no data found...
    if ( !%Lock ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Lock '$Param{LockID}' not found!",
        );
        return;
    }

    return %Lock;
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
