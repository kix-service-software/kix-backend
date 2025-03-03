# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter;

use strict;
use warnings;

our @ObjectDependencies = qw(
    ClientRegistration
    DB
    Log
);

=head1 NAME

Kernel::System::PostMaster::Filter

=head1 SYNOPSIS

All postmaster database filters

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $FilterObject = $Kernel::OM->Get('PostMaster::Filter');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item FilterNameLookup()

return name of filter for given id

    $FilterName = $PMFilterObject->FilterNameLookup(
        ID => 1
    );

=cut

sub FilterNameLookup {
    my ( $Self, %Param ) = @_;

    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ID!"
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');
    return if !$DBObject->Prepare(
        SQL  => 'SELECT name FROM mail_filter WHERE id = ?',
        Bind => [ \$Param{ID} ]
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        return $Row[0];
    }

    return;
}

=item FilterIDLookup()

return id of filter for given name

    $FilterID = $PMFilterObject->FilterIDLookup(
        Name => 'some name'
    );

=cut

sub FilterIDLookup {
    my ( $Self, %Param ) = @_;

    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Name!"
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM mail_filter WHERE name = ?',
        Bind => [ \$Param{Name} ]
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        return $Row[0];
    }

    return;
}

=item FilterList()

get all filter (id, name)

    my %FilterList = $PMFilterObject->FilterList(
        Valid => 0, # just valid/all filters
    );

=cut

sub FilterList {
    my ( $Self, %Param ) = @_;

    # get valid object
    my $ValidObject = $Kernel::OM->Get('Valid');

    my $Where = $Param{Valid} ? ' WHERE valid_id IN ( ' . join ', ', $ValidObject->ValidIDsGet() . ' )' : '';

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare( SQL => 'SELECT id, name FROM mail_filter' . $Where );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    return %Data;
}

=item FilterAdd()

add a filter

    $PMFilterObject->FilterAdd(
        Name           => 'some name',
        StopAfterMatch => 0,
        ValidID        => 1,
        UserID         => 123,
        Comment        => '',             # optional
        Match          => {
            From => 'email@example.com',
            Subject => '^ADV: 123',
        },
        Set            => {
            'X-KIX-Queue' => 'Some::Queue',
        },
        Not            => {
            From => 1
        }
    );

=cut

sub FilterAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name StopAfterMatch ValidID UserID Match Set)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    if ( !$Param{Name}) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No valid name given!"
        );
        return;
    }

    $Param{Comment} = '' if ( !$Param{Comment} );

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # check if a filter with this name already exists
    if ( $Self->NameExistsCheck( Name => $Param{Name} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A filter with name '$Param{Name}' already exists!"
        );
        return;
    }

    return if !$DBObject->Do(
        SQL => 'INSERT INTO mail_filter (name, stop, comments, valid_id, create_time, create_by, change_time, change_by)'
            . ' VALUES (?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name},    \$Param{StopAfterMatch},
            \$Param{Comment}, \$Param{ValidID},
            \$Param{UserID},  \$Param{UserID}
        ],
    );

    # get new id
    return if !$DBObject->Prepare(
        SQL   => 'SELECT id FROM mail_filter WHERE name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1
    );

    # fetch the result
    my $FilterID = '';
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $FilterID = $Row[0];
    }

    # add properties
    return if !$Self->_addProperties( %Param, FilterID => $FilterID );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'MailFilter',
        ObjectID  => $FilterID
    );

    return $FilterID;
}

=item NameExistsCheck()

return 1 if another filter with this name already exists

    $Exist = $PMFilterObject->NameExistsCheck(
        Name => 'Some name',
        ID   => 1,             # optional
    );

=cut

sub NameExistsCheck {
    my ( $Self, %Param ) = @_;

    my $ID = $Self->FilterIDLookup( Name => $Param{Name} );

    if ( $ID && ( !$Param{ID} || $Param{ID} ne $ID ) ) {
        return 1;
    }

    return 0;
}

=item FilterUpdate()

update a mail filter

    $PMFilterObject->FilterUpdate(
        ID             => 1,
        Name           => 'some name',
        StopAfterMatch => 0,
        ValidID        => 1,
        UserID         => 123,
        Comment        => '',             # optional
        Match          => {
            From => 'email@example.com',
            Subject => '^ADV: 123',
        },
        Set            => {
            'X-KIX-Queue' => 'Some::Queue',
        },
        Not            => {
            From => 1
        }
    );

=cut

sub FilterUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID Name StopAfterMatch ValidID UserID Match Set)) {
        if ( !defined $Param{$_} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
            }
            return;
        }
    }
    if ( !$Param{Name}) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No valid name given!"
            );
        }
        return;
    }

    $Param{Comment} = '' if ( !$Param{Comment} );

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # check if a filter with this name already exists
    if ( $Self->NameExistsCheck( Name => $Param{Name}, ID => $Param{ID} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "A filter with name '$Param{Name}' already exists!"
            );
        }
        return;
    }

    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE mail_filter SET name = ?, stop = ?, comments = ?, valid_id = ?, '
            . ' change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [

            \$Param{Name},    \$Param{StopAfterMatch},
            \$Param{Comment}, \$Param{ValidID},
            \$Param{UserID},  \$Param{ID}
        ],
    );

    # delete existing properties
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM mail_filter_properties WHERE filter_id = ?',
        Bind => [ \$Param{ID} ]
    );

    # add properties
    return if !$Self->_addProperties( %Param, FilterID => $Param{ID} );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'MailFilter',
        ObjectID  => $Param{ID}
    );

    return $Param{ID};
}

=item FilterDelete()

delete a filter

    $PMFilterObject->FilterDelete(
        ID   => 132,
        Name => 'some name'   # needed if no ID given
    );

=cut

sub FilterDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} && !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ID or Name!"
        );
        return;
    }

    if ( !$Param{ID} ) {
        $Param{ID} = $Self->FilterIDLookup( Name => $Param{Name} );
    }
    return if !$Param{ID};

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Do(
        SQL  => 'DELETE FROM mail_filter_properties WHERE filter_id = ?',
        Bind => [ \$Param{ID} ]
    );

    return if !$DBObject->Do(
        SQL  => 'DELETE FROM mail_filter WHERE id = ?',
        Bind => [ \$Param{ID} ]
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'MailFilter',
        ObjectID  => $Param{ID}
    );

    return 1;
}

=item FilterGet()

get filter properties, returns HASH ref Match and Set

    my %Data = $PMFilterObject->FilterGet(
        ID   => 132,
        Name => 'some name'   # needed if no ID given
    );

Returns:

    %Filter = (
        ID             => 1,
        Name           => 'some name',
        StopAfterMatch => 1 | 0,
        Comment        => 'some comment',
        ValidID        => 1,
        CreateTime     => '2019-06-19 08:15:00';
        CreateBy       => 1;
        ChangeTime     => '2019-06-19 08:15:00';
        ChangeBy       => 1;
        Match          => {
            From => 'email@example.com',
            Subject => '^ADV: 123',
        },
        Set            => {
            'X-KIX-Queue' => 'Some::Queue',
        },
        Not            => {
            From => 1
        }
    );

=cut

sub FilterGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} && !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ID or Name!"
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    if ( $Param{ID} ) {
        return if !$DBObject->Prepare(
            SQL  => 'SELECT id, name, stop, comments, valid_id, create_time, create_by, change_time, change_by FROM mail_filter WHERE id = ?',
            Bind => [ \$Param{ID} ]
        );
    } else {
        return if !$DBObject->Prepare(
            SQL  => 'SELECT id, name, stop, comments, valid_id, create_time, create_by, change_time, change_by FROM mail_filter WHERE name = ?',
            Bind => [ \$Param{Name} ]
        );
    }

    my %Filter;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Filter{ID}             = $Row[0];
        $Filter{Name}           = $Row[1];
        $Filter{StopAfterMatch} = $Row[2];
        $Filter{Comment}        = $Row[3];
        $Filter{ValidID}        = $Row[4];
        $Filter{CreateTime}     = $Row[5];
        $Filter{CreateBy}       = $Row[6];
        $Filter{ChangeTime}     = $Row[7];
        $Filter{ChangeBy}       = $Row[8];
    }

    return if !$Filter{ID};

    return if !$DBObject->Prepare(
        SQL  => 'SELECT type, filter_key, filter_value, negate FROM mail_filter_properties WHERE filter_id = ?',
        Bind => [ \$Filter{ID} ]
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Filter{ $Row[0] }->{ $Row[1] } = $Row[2];

        if ( $Row[0] eq 'Match' ) {
            $Filter{Not}->{ $Row[1] } = $Row[3];
        }
    }

    return %Filter;
}

sub _addProperties {
    my ( $Self, %Param ) = @_;

    if ( !$Param{FilterID} ) {
        return;
    }

    my %Not = %{ $Param{Not} || {} };

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    for my $Type (qw(Match Set)) {
        my %Data = %{ $Param{$Type} };
        for my $Key ( sort keys %Data ) {
            return if !$DBObject->Do(
                SQL => 'INSERT INTO mail_filter_properties (filter_id, type, filter_key, filter_value, negate)'
                    . ' VALUES (?, ?, ?, ?, ?)',
                Bind => [ \$Param{FilterID}, \$Type, \$Key, \$Data{$Key}, \$Not{$Key} ]
            );
        }
    }

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
