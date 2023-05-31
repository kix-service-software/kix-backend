# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Watcher;

use strict;
use warnings;

use File::Basename;

use Kernel::System::VariableCheck qw(:all);

use vars qw(@ISA);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
);

=head1 NAME

Kernel::System::Watcher - watcher lib

=head1 SYNOPSIS

All watcher functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $WatcherObject = $Kernel::OM->Get('Watcher');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=on;
    $Self->{Debug} = $Param{Debug} || 0;

    $Self->{CacheType} = 'Watcher';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;


    my $BackendList = $Kernel::OM->Get('Config')->Get('Watcher::Backend');

    # load backends
    foreach my $Backend ( sort keys %{$BackendList} ) {
        my $Package = $BackendList->{$Backend}->{Module};

        if ( !$Kernel::OM->Get('Main')->Require($Package) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to require $Package!"
            );
        }

        my $BackendObject = $Package->new( %{$Self} );
        if ( !$BackendObject ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create instance of $Backend!"
            );
        }

        $Self->{Backends}->{$Backend} = $BackendObject;
    }

    return $Self;
}

=item WatcherGet()

get the data of a single watcher item

    my %Watcher = $WatcherObject->WatcherGet(
        ID => 123
    );

=cut

sub WatcherGet {
    my ( $Self, %Param ) = @_;
    my @BindObj;

    # check needed stuff
    for my $Needed (qw(ID)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my @WatcherList = $Self->WatcherList(
        ID => $Param{ID},
    );

    return if !@WatcherList;

    if ( !$WatcherList[0]->{WatchUserID} ) {
        $WatcherList[0]->{WatchUserID} = $WatcherList[0]->{UserID};
    }

    return %{$WatcherList[0]};
}

=item WatcherList()

to get a list of subscribed users or objects a user is watching

    my @WatcherList = $WatcherObject->WatcherList(
        Object  => 'Ticket'
        ObjectID    => 123,
        WatchUserID => 1,
    );

get list of users to notify

    my @WatcherList = $WatcherObject->WatcherList(
        Object => 'Ticket'
        ObjectID   => 123,
        Notify     => 1,
    );

=cut

sub WatcherList {
    my ( $Self, %Param ) = @_;
    my @BindObj;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    my $SQL = 'SELECT id, object, object_id, user_id, create_time, create_by, change_time, change_by FROM watcher WHERE 1=1';

    if ( $Param{ID} ) {
        # this is needed for WatcherGet method
        $SQL .= ' AND id = ?';
        push(@BindObj, \$Param{ID});
    }
    if ( $Param{Object} ) {
        $SQL .= ' AND object = ?';
        push(@BindObj, \$Param{Object});
    }
    if ( $Param{ObjectID} ) {
        $SQL .= ' AND object_id = ?';
        push(@BindObj, \$Param{ObjectID});
    }
    if ( $Param{WatchUserID} ) {
        $SQL .= ' AND user_id = ?';
        push(@BindObj, \$Param{WatchUserID});
    }

    # get all attributes of an watched ticket
    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@BindObj,
    );

    # fetch the result
    my $Data = $DBObject->FetchAllArrayRef(
        Columns => [ 'ID', 'Object', 'ObjectID', 'UserID', 'CreateTime', 'CreateBy', 'ChangeTime', 'ChangeBy' ]
    );

    if ( $Param{Notify} ) {

        foreach my $Row ( @{$Data || []} ) {

            # get user object
            my $UserObject = $Kernel::OM->Get('User');

            my %UserData = $UserObject->GetUserData(
                UserID => $Row->{UserID},
                Valid  => 1,
            );

            my @TmpArray;
            if ( $UserData{UserSendWatcherNotification} ) {
                push(@TmpArray, $Row);
            }
            $Data = \@TmpArray;
        }
    }

    return @{$Data || []};
}

=item WatcherCount()

get the number of subscribed users or objects a user is watching

    my $Count = $WatcherObject->WatcherCount(
        Object  => 'Ticket'         # optional
        ObjectID    => 123,         # optional
        WatchUserID => 1,           # optional, to check if this user is a watcher
    );

=cut

sub WatcherCount {
    my ( $Self, %Param ) = @_;
    my @BindObj;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    my $SQL = 'SELECT count(*) FROM watcher WHERE 1=1';

    if ( $Param{Object} ) {
        $SQL .= ' AND object = ?';
        push(@BindObj, \$Param{Object});
    }
    if ( $Param{ObjectID} ) {
        $SQL .= ' AND object_id = ?';
        push(@BindObj, \$Param{ObjectID});
    }
    if ( $Param{WatchUserID} ) {
        $SQL .= ' AND user_id = ?';
        push(@BindObj, \$Param{WatchUserID});
    }

    # get all attributes of an watched ticket
    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@BindObj,
    );

    # fetch the result
    my $Count = 0;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Count = $Row[0];
    }

    return $Count;
}

=item WatcherLookup()

get the ID of the watcher item

    my $WatcherID = $WatcherObject->WatcherLookup(
        Object  => 'Ticket'
        ObjectID    => 123,
        WatchUserID => 1,
    );

=cut

sub WatcherLookup {
    my ( $Self, %Param ) = @_;
    my @BindObj;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # get all attributes of an watched ticket
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM watcher WHERE object = ? AND object_id = ? AND user_id = ?',
        Bind => [
            \$Param{Object}, \$Param{ObjectID}, \$Param{WatchUserID}
        ],
    );

    # fetch the result
    my $WatcherID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $WatcherID = $Row[0];
    }

    return $WatcherID;
}

=item WatcherAdd()

subscribe a watcher

    my $Success = $TicketObject->WatcherAdd(
        Object      => 'Ticket'
        ObjectID    => 123,
        WatchUserID => 123,
        UserID      => 123,
    );

Events:
    TicketSubscribe (for Object 'Ticket')

=cut

sub WatcherAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Object ObjectID WatchUserID UserID)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db access
    return if !$DBObject->Do(
        SQL => 'DELETE FROM watcher WHERE object = ? AND object_id = ? AND user_id = ?',
        Bind => [ \$Param{Object}, \$Param{ObjectID}, \$Param{WatchUserID} ],
    );
    return if !$DBObject->Do(
        SQL => '
            INSERT INTO watcher (object, object_id, user_id, create_time, create_by, change_time, change_by)
            VALUES (?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [ \$Param{Object}, \$Param{ObjectID}, \$Param{WatchUserID}, \$Param{UserID}, \$Param{UserID} ],
    );

    # get new watcher id
    my $WatcherID;
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM watcher WHERE object = ? AND object_id = ? AND user_id = ?',
        Bind => [ \$Param{Object}, \$Param{ObjectID}, \$Param{WatchUserID} ],
    );

    # fetch the result
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $WatcherID = $Row[0];
    }

    # check if we have a backend for this object type and execute it
    if ( $Self->{Backends}->{$Param{Object}} ) {
        my$BackendResult = $Self->{Backends}->{$Param{Object}}->WatcherAdd(
            %Param,
            WatcherID => $WatcherID
        );
    }

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Watcher',
        ObjectID  => $Param{Object}.'::'.$Param{ObjectID}.'::'.$Param{WatchUserID},
    );

    return $WatcherID;
}

=item WatcherDelete()

remove a watcher

    my $Success = $WatcherObject->WatcherDelete(
        ID          => 123,
        Object      => 'Ticket'     # if no ID is given
        ObjectID    => 123,         # if no ID is given
        WatchUserID => 123,         # if no ID is given
        UserID      => 123,
        AllUsers    => 0|1,
    );

Events:
    TicketUnsubscribe

=cut

sub WatcherDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(UserID)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # only one of these parameters is needed
    if ( !$Param{ID} && !$Param{WatchUserID} && !$Param{AllUsers} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ID or WatchUserID or AllUsers param!"
        );
        return;
    }

    # get user object
    my $UserObject = $Kernel::OM->Get('User');

    if ( $Param{AllUsers} ) {
        my @Watchers = $Self->WatcherList(
            Object => $Param{Object},
            ObjectID   => $Param{ObjectID},
        );

        return if !$Kernel::OM->Get('DB')->Do(
            SQL  => 'DELETE FROM watcher WHERE object = ? AND object_id = ?',
            Bind => [ \$Param{Object}, \$Param{ObjectID} ],
        );

        # delete cache
        $Kernel::OM->Get('Cache')->CleanUp(
            Type => $Self->{CacheType}
        );

        foreach my $WatchUserID (@Watchers) {

            # check if we have a backend for this object type and execute it
            if ( $Self->{Backends}->{$Param{Object}} ) {
                my$BackendResult = $Self->{Backends}->{$Param{Object}}->WatcherDelete(
                    %Param,
                    WatchUserID => $WatchUserID
                );
            }

            # push client callback event
            $Kernel::OM->Get('ClientRegistration')->NotifyClients(
                Event     => 'DELETE',
                Namespace => 'Watcher',
                ObjectID  => $Param{Object}.'::'.$Param{ObjectID}.'::'.$WatchUserID,
            );
        }
    }
    elsif ( $Param{ID} ) {
        my %WatcherData = $Self->WatcherGet(
            ID => $Param{ID}
        );

        return if !$Kernel::OM->Get('DB')->Do(
            SQL  => 'DELETE FROM watcher WHERE id = ?',
            Bind => [ \$Param{ID} ],
        );

        # delete cache
        $Kernel::OM->Get('Cache')->CleanUp(
            Type => $Self->{CacheType}
        );

        # check if we have a backend for this object type and execute it
        if ( $Self->{Backends}->{$WatcherData{Object}} ) {
            my$BackendResult = $Self->{Backends}->{$WatcherData{Object}}->WatcherDelete(
                %Param,
                %WatcherData,
            );
        }

        # push client callback event
        $Kernel::OM->Get('ClientRegistration')->NotifyClients(
            Event     => 'DELETE',
            Namespace => 'Watcher',
            ObjectID  => $WatcherData{Object}.'::'.$WatcherData{ObjectID}.'::'.$WatcherData{WatchUserID},
        );
    }
    else {
        return if !$Kernel::OM->Get('DB')->Do(
            SQL  => 'DELETE FROM watcher WHERE object = ? AND object_id = ? AND user_id = ?',
            Bind => [ \$Param{Object}, \$Param{ObjectID}, \$Param{WatchUserID} ],
        );

        # delete cache
        $Kernel::OM->Get('Cache')->CleanUp(
            Type => $Self->{CacheType}
        );

        # check if we have a backend for this object type and execute it
        if ( $Self->{Backends}->{$Param{Object}} ) {
            my$BackendResult = $Self->{Backends}->{$Param{Object}}->WatcherDelete(
                %Param,
            );
        }

        # push client callback event
        $Kernel::OM->Get('ClientRegistration')->NotifyClients(
            Event     => 'DELETE',
            Namespace => 'Watcher',
            ObjectID  => $Param{Object}.'::'.$Param{ObjectID}.'::'.$Param{WatchUserID},
        );
    }

    return 1;
}

=item WatcherTransfer()

transfer all watchers from one object to the other (merge to target)

    my $Success = $TicketObject->WatcherTransfer(
        Object     => 'Ticket'
        SourceObjectID => 123,
        TargetObjectID => 123,
    );

=cut

sub WatcherTransfer {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Object SourceObjectID TargetObjectID)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # transfer watchers from source to target
    my @SourceWatcherList = $Self->WatcherList(
        Object => $Param{Object},
        ObjectID   => $Param{TargetObjectID},
    );
    my %SourceWatchers = map { $_->{UserID} => $_ } @SourceWatcherList;

    my @TargetWatcherList = $Self->WatcherList(
        Object => $Param{Object},
        ObjectID   => $Param{TargetObjectID},
    );
    my %TargetWatchers = map { $_->{UserID} => $_ } @TargetWatcherList;

    foreach my $UserID ( sort keys %SourceWatchers ) {
        next if $TargetWatchers{$UserID};

        return if !$DBObject->Do(
            SQL  => 'UPDATE watcher SET object_id = ? WHERE id = ?',
            Bind => [ \$Param{TargetObjectID}, \$SourceWatchers{$UserID}->{ID} ],
        );
    }

    # delete all remaining watchers from source
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM watcher WHERE object = ? AND object_id = ?',
        Bind => [ \$Param{Object}, \$Param{SourceObjectID} ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Watcher',
        ObjectID  => $Param{Object}.'::'.$Param{SourceObjectID},
    );
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Watcher',
        ObjectID  => $Param{Object}.'::'.$Param{TargetObjectID},
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
