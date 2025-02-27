# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Type;

use strict;
use warnings;

our @ObjectDependencies = qw(
    ClientRegistration
    Config
    SysConfig
    Cache
    DB
    Log
    Valid
);

=head1 NAME

Kernel::System::Type - type lib

=head1 SYNOPSIS

All type functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TypeObject = $Kernel::OM->Get('Type');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'Type';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    return $Self;
}

=item TypeAdd()

add a new ticket type

    my $ID = $TypeObject->TypeAdd(
        Name    => 'New Type',
        Comment => '...',               # optional
        ValidID => 1,
        UserID  => 123,
    );

=cut

sub TypeAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name ValidID UserID)) {
        if ( !$Param{$_} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
            }
            return;
        }
    }

    # check if a type with this name already exists
    if ( $Self->NameExistsCheck( Name => $Param{Name} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "A type with name '$Param{Name}' already exists!"
            );
        }
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Do(
        SQL => 'INSERT INTO ticket_type (name, valid_id, comments, '
            . ' create_time, create_by, change_time, change_by)'
            . ' VALUES (?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [ \$Param{Name}, \$Param{ValidID}, \$Param{Comment}, \$Param{UserID}, \$Param{UserID} ],
    );

    # get new type id
    return if !$DBObject->Prepare(
        SQL   => 'SELECT id FROM ticket_type WHERE name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }
    return if !$ID;

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Type',
        ObjectID  => $ID,
    );

    return $ID;
}

=item TypeGet()

get types attributes

    my %Type = $TypeObject->TypeGet(
        ID => 123,
    );

    my %Type = $TypeObject->TypeGet(
        Name => 'default',
    );

Returns:

    Type = (
        ID                  => '123',
        Name                => 'Service Request',
        Comment             => '...',
        ValidID             => '1',
        CreateTime          => '2010-04-07 15:41:15',
        CreateBy            => '321',
        ChangeTime          => '2010-04-07 15:59:45',
        ChangeBy            => '223',
    );

=cut

sub TypeGet {
    my ( $Self, %Param ) = @_;

    # either ID or Name must be passed
    if ( !$Param{ID} && !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ID or Name!',
        );
        return;
    }

    # check that not both ID and Name are given
    if ( $Param{ID} && $Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need either ID OR Name - not both!',
        );
        return;
    }

    # lookup the ID
    if ( $Param{Name} ) {
        $Param{ID} = $Self->TypeLookup(
            Type => $Param{Name},
        );
        if ( !$Param{ID} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "TypeID for Type '$Param{Name}' not found!",
            );
            return;
        }
    }

    # check cache
    my $CacheKey = 'TypeGet::ID::' . $Param{ID};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # ask the database
    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name, valid_id, comments, '
            . 'create_time, create_by, change_time, change_by '
            . 'FROM ticket_type WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # fetch the result
    my %Type;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        $Type{ID}         = $Data[0];
        $Type{Name}       = $Data[1];
        $Type{ValidID}    = $Data[2];
        $Type{Comment}    = $Data[3];
        $Type{CreateTime} = $Data[4];
        $Type{CreateBy}   = $Data[5];
        $Type{ChangeTime} = $Data[6];
        $Type{ChangeBy}   = $Data[7];
    }

    # no data found
    if ( !%Type ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "TypeID '$Param{ID}' not found!",
        );
        return;
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Type,
    );

    return %Type;
}

=item TypeUpdate()

update type attributes

    $TypeObject->TypeUpdate(
        ID      => 123,
        Name    => 'New Type',
        Comment => '...',           # optional
        ValidID => 1,
        UserID  => 123,
    );

=cut

sub TypeUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID Name ValidID UserID)) {
        if ( !$Param{$_} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
            }
            return;
        }
    }

    # check if a type with this name already exists
    if (
        $Self->NameExistsCheck(
            Name => $Param{Name},
            ID   => $Param{ID}
        )
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "A type with name '$Param{Name}' already exists!"
            );
        }
        return;
    }

    my %Type = $Self->TypeGet(
        ID => $Param{ID},
    );

    # check if the type is set as a default ticket type
    if (
        $Kernel::OM->Get('Config')->Get('Ticket::Type::Default') eq $Type{Name}
        && $Param{ValidID} != 1
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "The ticket type is set as a default ticket type, so it cannot be set to invalid!"
            );
        }
        return;
    }

    # sql
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE ticket_type SET name = ?, valid_id = ?, comments = ?, '
            . ' change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{ValidID}, \$Param{Comment}, \$Param{UserID}, \$Param{ID},
        ],
    );

    # check if the name of the default ticket type is updated
    if (
        $Kernel::OM->Get('Config')->Get('Ticket::Type::Default') eq $Type{Name}
        && $Type{Name} ne $Param{Name}
        )
    {

        # update default ticket type SySConfig item
        $Kernel::OM->Get('SysConfig')->ValueSet(
            Valid => 1,
            Key   => 'Ticket::Type::Default',
            Value => $Param{Name}
        );

    }

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Type',
        ObjectID  => $Param{ID},
    );

    return 1;
}

=item TypeList()

get type list

    my %List = $TypeObject->TypeList();

or

    my %List = $TypeObject->TypeList(
        Valid => 0,
    );

=cut

sub TypeList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    my $Valid = 1;
    if ( !$Param{Valid} && defined $Param{Valid} ) {
        $Valid = 0;
    }

    # check cache
    my $CacheKey = "TypeList::Valid::$Valid";
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # create the valid list
    my $ValidIDs = join ', ', $Kernel::OM->Get('Valid')->ValidIDsGet();

    # build SQL
    my $SQL = 'SELECT id, name FROM ticket_type';

    # add WHERE statement
    if ($Valid) {
        $SQL .= ' WHERE valid_id IN (' . $ValidIDs . ')';
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # ask database
    return if !$DBObject->Prepare(
        SQL => $SQL,
    );

    # fetch the result
    my %TypeList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $TypeList{ $Row[0] } = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%TypeList,
    );

    return %TypeList;
}

=item TypeLookup()

get id or name for a ticket type

    my $Type = $TypeObject->TypeLookup(
        TypeID => $TypeID,
        Silent => 0|1      # optional - do not log if not found (defautl 0)
    );

    my $TypeID = $TypeObject->TypeLookup(
        Type => $Type,
        Silent => 0|1      # optional - do not log if not found (defautl 0)
    );

=cut

sub TypeLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Type} && !$Param{TypeID} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Got no Type or TypeID!',
            );
        }
        return;
    }

    # get (already cached) type list
    my %TypeList = $Self->TypeList(
        Valid => 0,
    );

    my $Key;
    my $Value;
    my $ReturnData;
    if ( $Param{TypeID} ) {
        $Key        = 'TypeID';
        $Value      = $Param{TypeID};
        $ReturnData = $TypeList{ $Param{TypeID} };
    }
    else {
        $Key   = 'Type';
        $Value = $Param{Type};
        my %TypeListReverse = reverse %TypeList;
        $ReturnData = $TypeListReverse{ $Param{Type} };
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

=item NameExistsCheck()

    return 1 if another type with this name already exits

        $Exist = $TypeObject->NameExistsCheck(
            Name => 'Some::Template',
            ID => 1, # optional
        );

=cut

sub NameExistsCheck {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM ticket_type WHERE name = ?',
        Bind => [ \$Param{Name} ],
    );

    # fetch the result
    my $Flag;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( !$Param{ID} || $Param{ID} ne $Row[0] ) {
            $Flag = 1;
        }
    }
    if ($Flag) {
        return 1;
    }
    return 0;
}

sub TypeDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TypeID UserID)) {
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
        SQL  => 'DELETE FROM ticket_type WHERE id = ?',
        Bind => [ \$Param{TypeID} ],
    );

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Type',
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
