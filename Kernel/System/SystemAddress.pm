# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SystemAddress;

use strict;
use warnings;

our @ObjectDependencies = qw(
    ClientRegistration
    Cache
    DB
    Log
    Valid
);

=head1 NAME

Kernel::System::SystemAddress - all system address functions

=head1 SYNOPSIS

Global module to add/edit/update system addresses.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $SystemAddressObject = $Kernel::OM->Get('SystemAddress');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{DBObject} = $Kernel::OM->Get('DB');

    $Self->{CacheType} = 'SystemAddress';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    return $Self;
}

=item SystemAddressAdd()

add system address with attributes

    my $ID = $SystemAddressObject->SystemAddressAdd(
        Name     => 'info@example.com',
        Realname => 'Hotline',
        ValidID  => 1,
        Comment  => 'some comment',
        UserID   => 123,
    );

=cut

sub SystemAddressAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Name ValidID Realname UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # insert new system address
    return if !$Self->{DBObject}->Do(
        SQL => 'INSERT INTO system_address (value0, value1, valid_id, comments, '
            . ' create_time, create_by, change_time, change_by)'
            . ' VALUES (?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{Realname}, \$Param{ValidID}, \$Param{Comment},
            \$Param{UserID}, \$Param{UserID},
        ],
    );

    # get system address id
    $Self->{DBObject}->Prepare(
        SQL   => 'SELECT id FROM system_address WHERE value0 = ? AND value1 = ?',
        Bind  => [ \$Param{Name}, \$Param{Realname}, ],
        Limit => 1,
    );

    # fetch the result
    my $ID;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $ID = $Row[0];
    }

    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'SystemAddress',
        ObjectID  => $ID,
    );

    return $ID;
}

=item SystemAddressGet()

get system address with attributes

    my %SystemAddress = $SystemAddressObject->SystemAddressGet(
        ID => 1,
    );

returns:

    %SystemAddress = (
        'ID'         => 1,
        'Name'       => 'info@example.com'
        'Realname'   => 'Hotline',
        'Comment'    => 'some comment',
        'ValidID'    => 1,
        'CreateTime' => '2010-11-29 11:04:04',
        'ChangeTime' => '2010-12-07 12:33:56',
    )

=cut

sub SystemAddressGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ID!"
        );
        return;
    }

    my $CacheKey = 'SystemAddressGet::' . $Param{ID};

    my $Cached = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    if ( ref $Cached eq 'HASH' ) {
        return %{$Cached};
    }

    # get system address
    return if !$Self->{DBObject}->Prepare(
        SQL => 'SELECT value0, value1, comments, valid_id, change_time, change_by, create_time, create_by'
            . ' FROM system_address WHERE id = ?',
        Bind  => [ \$Param{ID} ],
        Limit => 1,
    );

    # fetch the result
    my %Data;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        %Data = (
            ID         => $Param{ID},
            Name       => $Data[0],
            Realname   => $Data[1],
            Comment    => $Data[2],
            ValidID    => $Data[3],
            ChangeTime => $Data[4],
            ChangeBy   => $Data[5],
            CreateTime => $Data[6],
            CreateBy   => $Data[7],
        );
    }

    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    );

    return %Data;
}

=item SystemAddressUpdate()

update system address with attributes

    $SystemAddressObject->SystemAddressUpdate(
        ID       => 1,
        Name     => 'info@example.com',
        Realname => 'Hotline',
        ValidID  => 1,
        Comment  => 'some comment',
        UserID   => 123,
    );

=cut

sub SystemAddressUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ID Name ValidID Realname UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    return if !$Self->{DBObject}->Do(
        SQL => 'UPDATE system_address SET value0 = ?, value1 = ?, comments = ?, valid_id = ?, '
            . ' change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{Realname}, \$Param{Comment}, \$Param{ValidID},
            \$Param{UserID}, \$Param{ID},
        ],
    );


    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'SystemAddress',
        ObjectID  => $Param{ID},
    );

    return 1;
}

=item SystemAddressList()

get a list of system addresses

    my %List = $SystemAddressObject->SystemAddressList(
        Valid => 0,  # optional, defaults to 1
    );

returns:

    %List = (
        '1' => 'sales@example.com',
        '2' => 'purchasing@example.com',
        '3' => 'service@example.com',
    );

=cut

sub SystemAddressList {
    my ( $Self, %Param ) = @_;

    my $Valid = 1;
    if ( !$Param{Valid} && defined $Param{Valid} ) {
        $Valid = 0;
    }

    my $CacheKey = 'SystemAddressList::' . $Valid;

    my $Cached = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    if ( ref $Cached eq 'HASH' ) {
        return %{$Cached};
    }

    my $ValidSQL = '';
    if ($Valid) {
        my $ValidIDs = join ',', $Kernel::OM->Get('Valid')->ValidIDsGet();
        $ValidSQL = " WHERE valid_id IN ($ValidIDs)";
    }

    # get system address
    return if !$Self->{DBObject}->Prepare(
        SQL => "
            SELECT id, value0
            FROM system_address
            $ValidSQL",
    );

    my %List;

    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        $List{ $Data[0] } = $Data[1];
    }

    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%List,
    );

    return %List;
}

=item SystemAddressIsLocalAddress()

Checks if the given address is a local (system) address. Returns true
for local addresses.

    if ( $SystemAddressObject->SystemAddressIsLocalAddress( Address => 'info@example.com' ) ) {
        # is local
    }
    else {
        # is not local
    }

=cut

sub SystemAddressIsLocalAddress {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Address)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    $Param{Name} = $Param{Address};

    return $Self->SystemAddressLookup(%Param);
}


=item SystemAddressLookup()

returns the name or the SystemAddress id

    my $SystemAddressName = $SystemAddressObject->SystemAddressLookup(
        SystemAddressID => 123,
    );

    or

    my $SystemAddressID = $SystemAddressObject->SystemAddressLookup(
        Name => 'SystemAddress Name',
    );

=cut

sub SystemAddressLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{SystemAddressID} && !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need SystemAddressID or Name!',
        );
        return;
    }

    my $CacheKey = 'SystemAddressLookup::' . ($Param{SystemAddressID} || '') . '::' . ($Param{Name} || '');

    my $Cached = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cached if $Cached;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    if ( $Param{SystemAddressID} ) {
        # lookup
        $DBObject->Prepare(
            SQL => "SELECT value0 FROM system_address WHERE id = ?",
            Bind  => [ \$Param{SystemAddressID}, ],
            Limit => 1,
        );

        # fetch the result
        my $Name = '';
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $Name = $Row[0];
        }

        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => $Name,
        );

        return $Name;
    }
    else {

        # lookup
        $DBObject->Prepare(
            SQL => "SELECT id FROM system_address WHERE value0 = ?",
            Bind  => [ \$Param{Name} ],
            Limit => 1,
        );

        # fetch the result
        my $SystemAddressID = '';
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $SystemAddressID = $Row[0];
        }

        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => $SystemAddressID,
        );

        return $SystemAddressID;
    }
}

sub SystemAddressDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(SystemAddressID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');
    return if !$DBObject->Prepare(
        SQL  => 'DELETE FROM system_address WHERE id = ?',
        Bind => [ \$Param{SystemAddressID} ],
    );

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'SystemAddress',
        ObjectID  => $Param{ID},
    );

    return 1;
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
