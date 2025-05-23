# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::NotificationEvent;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'DB',
    'Log',
    'Valid',
    'YAML',
    'Cache'
);

=head1 NAME

Kernel::System::NotificationEvent - to manage the notifications

=head1 SYNOPSIS

All functions to manage the notification and the notification jobs.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $NotificationEventObject = $Kernel::OM->Get('NotificationEvent');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'NotificationEvent';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    return $Self;
}

=item NotificationList()

returns a hash of all notifications

    my %List = $NotificationEventObject->NotificationList(
        Type    => 'Ticket', # type of notifications; default: 'Ticket'
        Details => 1,        # include notification detailed data. possible (0|1) # ; default: 0
        All     => 1,        # optional: if given all notification types will be returned, even if type is given (possible: 0|1)
    );

=cut

sub NotificationList {
    my ( $Self, %Param ) = @_;

    $Param{Type} ||= 'Ticket';
    $Param{Details} = $Param{Details} ? 1 : 0;
    $Param{All}     = $Param{All}     ? 1 : 0;

    my $CacheObject = $Kernel::OM->Get('Cache');

    my $CacheKey    = $Self->{CacheType} . '::' . $Param{Type} . '::' . $Param{Details} . '::' . $Param{All};
    my $CacheResult = $CacheObject->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    if ( ref $CacheResult eq 'HASH' ) {
        return %{$CacheResult};
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    $DBObject->Prepare( SQL => 'SELECT id FROM notification_event' );

    my @NotificationList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @NotificationList, $Row[0];
    }

    my %Result;

    ITEMID:
    for my $ItemID ( sort @NotificationList ) {

        my %NotificationData = $Self->NotificationGet(
            ID     => $ItemID,
            UserID => 1,
        );

        $NotificationData{Data}->{NotificationType} ||= ['Ticket'];

        if ( !$Param{All} ) {
            next ITEMID if $NotificationData{Data}->{NotificationType}->[0] ne $Param{Type};
        }

        if ( $Param{Details} ) {
            $Result{$ItemID} = \%NotificationData;
        }
        else {
            $Result{$ItemID} = $NotificationData{Name};
        }
    }

    $CacheObject->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \%Result,
        TTL   => $Self->{CacheTTL},
    );

    return %Result;
}

=item NotificationGet()

returns a hash of the notification data

    my %Notification = $NotificationEventObject->NotificationGet(
        Name => 'NotificationName',
    );

    my %Notification = $NotificationEventObject->NotificationGet(
        ID => 1,
    );

Returns:

    %Notification = (
        ID      => 123,
        Name    => 'Agent::Move',
        Data => {
            Events => [ 'TicketQueueUpdate' ],
        },
        Filter => {
            AND => [
                {
                    Field => 'QueueID',
                    Operator => 'EQ',
                    Value => 1,
                }
            ]
        },
        Message => {
            en => {
                Subject     => 'Hello',
                Body        => 'Hello World',
                ContentType => 'text/plain',
            },
            de => {
                Subject     => 'Hallo',
                Body        => 'Hallo Welt',
                ContentType => 'text/plain',
            },
        },
        Comment    => 'An optional comment',
        ValidID    => 1,
        CreateTime => '2010-10-27 20:15:00',
        CreateBy   => 2,
        ChangeTime => '2010-10-27 20:15:00',
        ChangeBy   => 1,
        UserID     => 3,
    );

=cut

sub NotificationGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} && !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name or ID!',
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # general query structure
    my $SQL = '
        SELECT id, name, filter, valid_id, comments, create_time, create_by, change_time, change_by
        FROM notification_event
        WHERE ';

    if ( $Param{Name} ) {

        $DBObject->Prepare(
            SQL  => $SQL . 'name = ?',
            Bind => [ \$Param{Name} ],
        );
    }
    else {
        $DBObject->Prepare(
            SQL  => $SQL . 'id = ?',
            Bind => [ \$Param{ID} ],
        );
    }

    # get notification event data
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ID}         = $Row[0];
        $Data{Name}       = $Row[1];
        $Data{Filter}     = $Row[2];
        $Data{ValidID}    = $Row[3];
        $Data{Comment}    = $Row[4];
        $Data{CreateTime} = $Row[5];
        $Data{CreateBy}   = $Row[6];
        $Data{ChangeTime} = $Row[7];
        $Data{ChangeBy}   = $Row[8];
    }

    return if !%Data;

    if ( $Data{Filter} ) {
        # decode JSON
        $Data{Filter} = $Kernel::OM->Get('JSON')->Decode(
            Data => $Data{Filter}
        );
    }

    # get notification event item data
    $DBObject->Prepare(
        SQL => '
            SELECT event_key, event_value
            FROM notification_event_item
            WHERE notification_id = ?
            ORDER BY event_key, event_value ASC',
        Bind => [ \$Data{ID} ],
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @{ $Data{Data}->{ $Row[0] } }, $Row[1];
    }

    # get notification event message data
    $DBObject->Prepare(
        SQL => '
            SELECT subject, text, content_type, language
            FROM notification_event_message
            WHERE notification_id = ?',
        Bind => [ \$Data{ID} ],
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {

        # add to message hash with the language as key
        $Data{Message}->{ $Row[3] } = {
            Subject     => $Row[0],
            Body        => $Row[1],
            ContentType => $Row[2],
        };
    }

    return %Data;
}

=item NotificationAdd()

adds a new notification to the database

    my $ID = $NotificationEventObject->NotificationAdd(
        Name => 'Agent::OwnerUpdate',
        Data => {
            Events => [ 'TicketQueueUpdate' ],
        },
        Filter => {
            AND => [
                {
                    Field => 'QueueID',
                    Operator => 'EQ',
                    Value => 1,
                }
            ]
        },
        Message => {
            en => {
                Subject     => 'Hello',
                Body        => 'Hello World',
                ContentType => 'text/plain',
            },
            de => {
                Subject     => 'Hallo',
                Body        => 'Hallo Welt',
                ContentType => 'text/plain',
            },
        },
        Comment => 'An optional comment', # (optional)
        ValidID => 1,
        UserID  => 123,
    );

=cut

sub NotificationAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Name Data Message ValidID UserID)) {
        if ( !$Param{$Argument} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Argument!",
                );
            }
            return;
        }
    }

    # check if job name already exists
    my %Check = $Self->NotificationGet(
        Name => $Param{Name},
    );
    if (%Check) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't add notification '$Param{Name}', notification already exists!",
            );
        }
        return;
    }

    # check message parameter
    if ( !IsHashRefWithData( $Param{Message} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need Message!",
            );
        }
        return;
    }

    # check each argument for each message language
    for my $Language ( sort keys %{ $Param{Message} } ) {

        for my $Argument (qw(Subject Body ContentType)) {

            # error if message data is incomplete
            if ( !$Param{Message}->{$Language}->{$Argument} ) {
                if ( !$Param{Silent} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Need Message argument '$Argument' for language '$Language'!",
                    );
                }
                return;
            }

            # fix some bad stuff from some browsers (Opera)!
            $Param{Message}->{$Language}->{Body} =~ s/(\n\r|\r\r\n|\r\n|\r)/\n/g;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # prepare filter as JSON
    my $Filter;
    if ( $Param{Filter} ) {
        $Filter = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{Filter}
        );
    }

    # insert data into db
    return if !$DBObject->Do(
        SQL => '
            INSERT INTO notification_event
                (name, filter, valid_id, comments, create_time, create_by, change_time, change_by)
            VALUES (?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Filter, \$Param{ValidID}, \$Param{Comment},
            \$Param{UserID}, \$Param{UserID},
        ],
    );

    # get id
    $DBObject->Prepare(
        SQL  => 'SELECT id FROM notification_event WHERE name = ?',
        Bind => [ \$Param{Name} ],
    );

    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    # error handling
    if ( !$ID ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Could not get ID for just added notification '$Param{Name}'!",
            );
        }
        return;
    }

    # insert notification event item data
    for my $Key ( sort keys %{ $Param{Data} } ) {

        ITEM:
        for my $Item ( @{ $Param{Data}->{$Key} } ) {

            next ITEM if !defined $Item;
            next ITEM if $Item eq '';

            return if !$DBObject->Do(
                SQL => '
                    INSERT INTO notification_event_item
                        (notification_id, event_key, event_value)
                    VALUES (?, ?, ?)',
                Bind => [ \$ID, \$Key, \$Item ],
            );
        }
    }

    # insert notification event message data
    for my $Language ( sort keys %{ $Param{Message} } ) {

        my %Message = %{ $Param{Message}->{$Language} };

        return if !$DBObject->Do(
            SQL => '
                INSERT INTO notification_event_message
                    (notification_id, subject, text, content_type, language)
                VALUES (?, ?, ?, ?, ?)',
            Bind => [
                \$ID,
                \$Message{Subject},
                \$Message{Body},
                \$Message{ContentType},
                \$Language,
            ],
        );
    }

    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return $ID;
}

=item NotificationUpdate()

update a notification in database

    my $Ok = $NotificationEventObject->NotificationUpdate(
        ID      => 123,
        Name    => 'Agent::OwnerUpdate',
        Data => {
            Events => [ 'TicketQueueUpdate' ],
        },
        Filter => {
            AND => [
                {
                    Field => 'QueueID',
                    Operator => 'EQ',
                    Value => 1,
                }
            ]
        },
        Message => {
            en => {
                Subject     => 'Hello',
                Body        => 'Hello World',
                ContentType => 'text/plain',
            },
            de => {
                Subject     => 'Hallo',
                Body        => 'Hallo Welt',
                ContentType => 'text/plain',
            },
        },
        Comment => 'An optional comment',  # (optional)
        ValidID => 1,
        UserID  => 123,
    );

=cut

sub NotificationUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(ID Name Data Message ValidID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check message parameter
    if ( !IsHashRefWithData( $Param{Message} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Message!",
        );
        return;
    }

    # check each argument for each message language
    for my $Language ( sort keys %{ $Param{Message} } ) {

        for my $Argument (qw(Subject Body ContentType)) {

            # error if message data is incomplete
            if ( !$Param{Message}->{$Language}->{$Argument} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need Message argument '$Argument' for language '$Language'!",
                );
                return;
            }

            # fix some bad stuff from some browsers (Opera)!
            $Param{Message}->{$Language}->{Body} =~ s/(\n\r|\r\r\n|\r\n|\r)/\n/g;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # prepare filter as JSON
    my $Filter;
    if ( $Param{Filter} ) {
        $Filter = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{Filter}
        );
    }

    # update data in db
    return if !$DBObject->Do(
        SQL => '
            UPDATE notification_event
            SET name = ?, filter = ?, valid_id = ?, comments = ?, change_time = current_timestamp, change_by = ?
            WHERE id = ?',
        Bind => [
            \$Param{Name},    \$Filter,
            \$Param{ValidID}, \$Param{Comment},
            \$Param{UserID},  \$Param{ID},
        ],
    );

    # delete existing notification event item data
    $DBObject->Do(
        SQL  => 'DELETE FROM notification_event_item WHERE notification_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # add new notification event item data
    for my $Key ( sort keys %{ $Param{Data} } ) {

        ITEM:
        for my $Item ( @{ $Param{Data}->{$Key} } ) {

            next ITEM if !defined $Item;
            next ITEM if $Item eq '';

            $DBObject->Do(
                SQL => '
                    INSERT INTO notification_event_item
                        (notification_id, event_key, event_value)
                    VALUES (?, ?, ?)',
                Bind => [
                    \$Param{ID},
                    \$Key,
                    \$Item,
                ],
            );
        }
    }

    # delete existing notification event message data
    $DBObject->Do(
        SQL  => 'DELETE FROM notification_event_message WHERE notification_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # insert new notification event message data
    for my $Language ( sort keys %{ $Param{Message} } ) {

        my %Message = %{ $Param{Message}->{$Language} };

        $DBObject->Do(
            SQL => '
                INSERT INTO notification_event_message
                    (notification_id, subject, text, content_type, language)
                VALUES (?, ?, ?, ?, ?)',
            Bind => [
                \$Param{ID},
                \$Message{Subject},
                \$Message{Body},
                \$Message{ContentType},
                \$Language,
            ],
        );
    }

    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return 1;
}

=item NotificationDelete()

deletes an notification from the database

    $NotificationEventObject->NotificationDelete(
        ID     => 1,
        UserID => 123,
    );

=cut

sub NotificationDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(ID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check if job name exists
    my %Check = $Self->NotificationGet(
        ID => $Param{ID},
    );
    if ( !%Check ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't delete notification with ID '$Param{ID}'. Notification does not exist!",
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # delete notification event item
    my $DeleteOK = $DBObject->Do(
        SQL  => 'DELETE FROM notification_event_item WHERE notification_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # error handling
    if ( !$DeleteOK ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't delete notification_event_item with ID '$Param{ID}'!",
        );
        return;
    }

    # delete notification event message
    $DeleteOK = $DBObject->Do(
        SQL  => 'DELETE FROM notification_event_message WHERE notification_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # error handling
    if ( !$DeleteOK ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't delete notification_event_message with ID '$Param{ID}'!",
        );
        return;
    }

    # delete notification event
    $DeleteOK = $DBObject->Do(
        SQL  => 'DELETE FROM notification_event WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # error handling
    if ( !$DeleteOK ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't delete notification_event with ID '$Param{ID}'!",
        );
        return;
    }

    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # success
    $Kernel::OM->Get('Log')->Log(
        Priority => 'notice',
        Message  => "NotificationEvent notification '$Check{Name}' deleted (UserID=$Param{UserID}).",
    );

    return 1;
}

=item NotificationEventCheck()

returns array of notification affected by event

    my @IDs = $NotificationEventObject->NotificationEventCheck(
        Event => 'ArticleCreate',
    );

=cut

sub NotificationEventCheck {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Event} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name!',
        );
        return;
    }

    # get needed objects
    my $DBObject    = $Kernel::OM->Get('DB');
    my $ValidObject = $Kernel::OM->Get('Valid');

    my @ValidIDs = $ValidObject->ValidIDsGet();
    my $ValidIDString = join ', ', @ValidIDs;

    $DBObject->Prepare(
        SQL => "
            SELECT DISTINCT(nei.notification_id)
            FROM notification_event ne, notification_event_item nei
            WHERE ne.id = nei.notification_id
                AND ne.valid_id IN ( $ValidIDString )
                AND nei.event_key = 'Events'
                AND nei.event_value = ?
            ORDER BY nei.notification_id ASC",
        Bind => [ \$Param{Event} ],
    );

    my @IDs;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @IDs, $Row[0];
    }

    return @IDs;
}

=item NotificationEventList()

returns a hash with the NotificationIDs to events mapping

    my %EventToIDsMapping = $NotificationEventObject->NotificationEventList();

=cut

sub NotificationEventList {
    my ( $Self, %Param ) = @_;

    my $CacheKey = 'NotificationEventList';
    my $Cached = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    return %{$Cached} if ( ref $Cached eq 'HASH' );

    # get needed objects
    my $DBObject    = $Kernel::OM->Get('DB');
    my $ValidObject = $Kernel::OM->Get('Valid');

    my @ValidIDs = $ValidObject->ValidIDsGet();
    my $ValidIDString = join ', ', @ValidIDs;

    $DBObject->Prepare(
        SQL => "
            SELECT nei.event_value, nei.notification_id
            FROM notification_event ne, notification_event_item nei
            WHERE ne.id = nei.notification_id
                AND ne.valid_id IN ( $ValidIDString )
                AND nei.event_key = 'Events'",
    );

    my $Data = $DBObject->FetchAllArrayRef(
        Columns => [ 'Event', 'NotificationID' ]
    );

    my %Result;
    foreach my $Row ( @{$Data || []} ) {
        $Result{$Row->{Event}} //= [];
        push @{$Result{$Row->{Event}}}, $Row->{NotificationID};
    }

    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \%Result,
        TTL   => $Self->{CacheTTL},
    );

    return %Result;
}

=item NotificationImport()

import an Notification YAML file/content

    my $NotificationImport = $NotificationObject->NotificationImport(
        Content                   => $YAMLContent, # mandatory, YAML format
        OverwriteExistingNotifications => 0,            # 0 || 1
        UserID                    => 1,            # mandatory
    );

Returns:

    $NotificationImport = {
        Success      => 1,                         # 1 if success or undef if operation could not
                                                   #    be performed
        Message     => 'The Message to show.',     # error message
        AddedNotifications   => 'Notification1, Notification2',               # list of Notifications correctly added
        UpdatedNotifications => 'Notification3, Notification4',               # list of Notifications correctly updated
        NotificationErrors   => 'Notification5',                     # list of Notifications that could not be added or updated
    };

=cut

sub NotificationImport {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Content UserID)) {

        # check needed stuff
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return {
                Success => 0,
                Message => "$Needed is missing can not continue.",
            };
        }
    }

    my $NotificationData = $Kernel::OM->Get('YAML')->Load(
        Data => $Param{Content},
    );

    if ( ref $NotificationData ne 'ARRAY' ) {
        return {
            Success => 0,
            Message =>
                "Couldn't read Notification configuration file. Please make sure the file is valid.",
        };
    }

    my @UpdatedNotifications;
    my @AddedNotifications;
    my @NotificationErrors;

    my %CurrentNotifications = $Self->NotificationList(
        UserID => $Param{UserID},
    );
    my %ReverseCurrentNotifications = reverse %CurrentNotifications;

    Notification:
    for my $Notification ( @{$NotificationData} ) {

        next Notification if !$Notification;
        next Notification if ref $Notification ne 'HASH';

        if ( $Param{OverwriteExistingNotifications} && $ReverseCurrentNotifications{ $Notification->{Name} } ) {
            my $Success = $Self->NotificationUpdate(
                %{$Notification},
                ID     => $ReverseCurrentNotifications{ $Notification->{Name} },
                UserID => $Param{UserID},
            );

            if ($Success) {
                push @UpdatedNotifications, $Notification->{Name};
            }
            else {
                push @NotificationErrors, $Notification->{Name};
            }

        }
        else {

            # now add the Notification
            my $Success = $Self->NotificationAdd(
                %{$Notification},
                UserID => $Param{UserID},
            );

            if ($Success) {
                push @AddedNotifications, $Notification->{Name};
            }
            else {
                push @NotificationErrors, $Notification->{Name};
            }
        }
    }

    return {
        Success              => 1,
        AddedNotifications   => join( ', ', @AddedNotifications ) || '',
        UpdatedNotifications => join( ', ', @UpdatedNotifications ) || '',
        NotificationErrors   => join( ', ', @NotificationErrors ) || '',
    };
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
