# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Queue;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Queue::FollowUp
    Kernel::System::EventHandler
);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'Main',
    'StandardTemplate',
    'SysConfig',
    'Valid',
);

=head1 NAME

Kernel::System::Queue - queue lib

=head1 SYNOPSIS

All queue functions. E. g. to add queue or other functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $QueueObject = $Kernel::OM->Get('Queue');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{QueueID} = $Param{QueueID} || '';

    $Self->{CacheType} = 'Queue';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    # load generator preferences module
    my $GeneratorModule = $Kernel::OM->Get('Config')->Get('Queue::PreferencesModule')
        || 'Kernel::System::Queue::PreferencesDB';
    if ( $Kernel::OM->Get('Main')->Require($GeneratorModule) ) {
        $Self->{PreferencesObject} = $GeneratorModule->new();
    }

    # --------------------------------------------------- #
    #  default queue settings                             #
    #  these settings are used by the CLI version         #
    # --------------------------------------------------- #
    $Self->{QueueDefaults} = {
        Calendar            => '',
        UnlockTimeout       => 0,
        FirstResponseTime   => 0,
        FirstResponseNotify => 0,
        SolutionTime        => 0,
        SolutionNotify      => 0,
        SystemAddressID     => 1,
        Signature           => '',
        FollowUpID          => 1,
        FollowUpLock        => 0,
    };

    # init of event handler
    $Self->EventHandlerInit(
        Config => 'Queue::EventModulePost',
    );

    return $Self;
}

=item GetQueuesForEmailAddress()

get all queues where the given Email address is used as "sender address" as hash (id, RealName)

    my %QueueIDs = $QueueObject->GetQueuesForEmailAddress(
        AddressID  => 2,
    );

=cut

sub GetQueuesForEmailAddress {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{AddressID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need AddressID!',
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name FROM queue '
            . 'WHERE system_address_id = ? ',
        Bind  => [ \$Param{AddressID} ],
    );

    # fetch the result
    my %Queues;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Queues{$Row[0]} = $Row[1];
    }

    return %Queues;
}

=item GetSystemAddress()

get a queue system email address as hash (Email, RealName)

    my %Address = $QueueObject->GetSystemAddress(
        QueueID => 123,
    );

=cut

sub GetSystemAddress {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    my %Address;
    my $QueueID = $Param{QueueID} || $Self->{QueueID};

    return if !$DBObject->Prepare(
        SQL => 'SELECT sa.value0, sa.value1 FROM system_address sa, queue sq '
            . 'WHERE sq.id = ? AND sa.id = sq.system_address_id',
        Bind  => [ \$QueueID ],
        Limit => 1,
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Address{Email}    = $Row[0];
        $Address{RealName} = $Row[1];
    }

    # prepare realname quote
    if ( $Address{RealName} =~ /(,|@|\(|\)|:)/ && $Address{RealName} !~ /^("|')/ ) {
        $Address{RealName} =~ s/"/\"/g;
        $Address{RealName} = '"' . $Address{RealName} . '"';
    }

    return %Address;
}

=item GetAllQueues()

get all valid system queues

    my %Queues = $QueueObject->GetAllQueues();

get all system queues of a user with permission type (e. g. ro, move_into, rw, ...)

    my %Queues = $QueueObject->GetAllQueues( UserID => 123, Type => 'ro' );

=cut

sub GetAllQueues {
    my ( $Self, %Param ) = @_;

    my $Type = $Param{Type} || 'ro';

    # get needed objects
    my $ValidObject = $Kernel::OM->Get('Valid');
    my $DBObject    = $Kernel::OM->Get('DB');

    # fetch all queues
    my $CacheKey;
    if ( $Param{UserID} ) {
        $CacheKey = "GetAllQueues::UserID::${Type}::$Param{UserID}";

        # check cache
        my $Cache = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return %{$Cache} if $Cache;

        return if !$DBObject->Prepare(
            SQL => "SELECT id, name FROM queue WHERE "
                . " valid_id IN ( ${\(join ', ', $ValidObject->ValidIDsGet())} )",
        );
    }
    elsif ( $Param{ContactID} ) {

        $CacheKey = "GetAllQueues::ContactID::${Type}::$Param{ContactID}";

        # check cache
        my $Cache = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return %{$Cache} if $Cache;

        return if !$DBObject->Prepare(
            SQL => "SELECT id, name FROM queue WHERE "
                . " valid_id IN ( ${\(join ', ', $ValidObject->ValidIDsGet())} )",
        );
    }
    else {

        $CacheKey = 'GetAllQueues';

        # check cache
        my $Cache = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return %{$Cache} if $Cache;

        return if !$DBObject->Prepare(
            SQL => "SELECT id, name FROM queue WHERE valid_id IN "
                . "( ${\(join ', ', $ValidObject->ValidIDsGet())} )",
        );
    }

    my %MoveQueues;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $MoveQueues{ $Row[0] } = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%MoveQueues,
    );

    return %MoveQueues;
}

=item GetAllSubQueues()

get all sub queues of a queue

    my %Queues = $QueueObject->GetAllSubQueues( QueueID => 123 );

=cut

sub GetAllSubQueues {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{QueueID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need QueueID!'
        );
        return;
    }

    # check cache
    my $CacheKey = 'GetAllSubQueues::' . $Param{QueueID};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # search all custom queues
    return if !$DBObject->Prepare(
        SQL  => "SELECT q2.id, q2.name FROM queue q1, queue q2 WHERE q1.id = ? AND q2.id <> ? AND q2.name like CONCAT(q1.name, '::%')",
        Bind => [ \$Param{QueueID}, \$Param{QueueID} ],
    );

    # fetch the result
    my %QueueIDs;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $QueueIDs{$Row[0]} = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%QueueIDs,
    );

    return %QueueIDs;
}

=item QueueLookup()

get id or name for queue

    my $Queue = $QueueObject->QueueLookup(
        QueueID => $QueueID,
        Silent  => 0|1              # optional - do not log if not found (defautl 0)
    );

    my $QueueID = $QueueObject->QueueLookup(
        Queue => $Queue,
        Silent => 0|1               # optional - do not log if not found (defautl 0)
    );

    my $QueueID = $QueueObject->QueueLookup(
        SystemAddressID => $SystemAddressID,
        Silent          => 0|1      # optional - do not log if not found (defautl 0)
    );

=cut

sub QueueLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Queue} && !$Param{QueueID} && !$Param{SystemAddressID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Got no Queue or QueueID or SystemAddressID!'
        );
        return;
    }

    # get (already cached) queue data
    my %QueueList = $Self->QueueList(
        Valid => 0,
    );

    my $Key;
    my $Value;
    my $ReturnData;
    if ( $Param{QueueID} ) {
        $Key        = 'QueueID';
        $Value      = $Param{QueueID};
        $ReturnData = $QueueList{ $Param{QueueID} };
    }
    elsif ( $Param{Queue} ) {
        $Key   = 'Queue';
        $Value = $Param{Queue};
        my %QueueListReverse = reverse %QueueList;
        $ReturnData = $QueueListReverse{ $Param{Queue} };
    }
    elsif ( $Param{SystemAddressID} ) {
        foreach my $QueueID ( keys %QueueList ) {
            my %QueueData = $Self->QueueGet(
                QueueID => $QueueID
            );
            next if $QueueData{SystemAddressID} ne $Param{SystemAddressID};
            $ReturnData = $QueueID;
            last;
        }
    }

    # check if data exists
    if ( !$ReturnData && !$Param{Silent}) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Found no $Key for $Value!",
            );
        }
        return;
    }

    return $ReturnData;
}

=item QueueAdd()

add queue with attributes

    $QueueObject->QueueAdd(
        Name                => 'Some::Queue',
        ValidID             => 1,
        Calendar            => 'Calendar1', # (optional)
        UnlockTimeout       => 480,         # (optional)
        FollowUpID          => 3,           # possible (1), reject (2) or new ticket (3) (optional, default 0)
        FollowUpLock        => 0,           # yes (1) or no (0) (optional, default 0)
        DefaultSignKey      => 'key name',  # (optional)
        SystemAddressID     => 1,
        Signature           => '',
        Comment             => 'Some comment',
        UserID              => 123,
    );

=cut

sub QueueAdd {
    my ( $Self, %Param ) = @_;

    # check if this request is from web and not from command line
    if ( !$Param{NoDefaultValues} ) {
        for (
            qw(UnlockTimeout FollowUpLock SystemAddressID Signature FollowUpID FollowUpLock DefaultSignKey Calendar)
            )
        {

            # I added default values in the Load Routine
            if ( !$Param{$_} ) {
                $Param{$_} = exists $Self->{QueueDefaults}->{$_} ? $Self->{QueueDefaults}->{$_} : 0;
            }
        }
    }

    for (qw(Name SystemAddressID ValidID UserID FollowUpID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # cleanup queue name
    $Param{Name} =~ s/(\n|\r)//g;
    $Param{Name} =~ s/\s$//g;

    # check queue name
    if ( $Param{Name} =~ /::$/i ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Invalid Queue name '$Param{Name}'!",
        );
        return;
    }

    # check if a queue with this name already exists
    if ( $Self->NameExistsCheck( Name => $Param{Name} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A queue with name '$Param{Name}' already exists!"
        );
        return;
    }

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Config');
    my $DBObject     = $Kernel::OM->Get('DB');

    return if !$DBObject->Do(
        SQL => 'INSERT INTO queue (name, unlock_timeout, system_address_id, '
            . ' calendar_name, default_sign_key, signature, follow_up_id, '
            . ' follow_up_lock, valid_id, comments, create_time, create_by, '
            . ' change_time, change_by) VALUES '
            . ' (?, ?, ?, ?, ?, ?, ?, ?, ?, '
            . ' ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name},     \$Param{UnlockTimeout}, \$Param{SystemAddressID},
            \$Param{Calendar}, \$Param{DefaultSignKey}, \$Param{Signature},
            \$Param{FollowUpID},        \$Param{FollowUpLock},        \$Param{ValidID},
            \$Param{Comment},           \$Param{UserID},              \$Param{UserID},
        ],
    );

    # get new id
    return if !$DBObject->Prepare(
        SQL   => 'SELECT id FROM queue WHERE name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $QueueID = '';
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $QueueID = $Row[0];
    }

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # get queue data with updated name for QueueCreate event
    my %Queue = $Self->QueueGet( Name => $Param{Name} );

    # trigger event
    $Self->EventHandler(
        Event => 'QueueCreate',
        Data  => {
            Queue => \%Queue,
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Queue',
        ObjectID  => $QueueID,
    );

    return $QueueID;
}

=item QueueGet()

get queue attributes

    my %Queue = $QueueObject->QueueGet(
        ID    => 123,
    );

    my %Queue = $QueueObject->QueueGet(
        Name  => 'Some::Queue',
    );

=cut

sub QueueGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} && !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ID or Name!'
        );
        return;
    }

    # check runtime cache
    my $CacheKey;
    my $Key;
    my $Value;
    if ( $Param{ID} ) {
        $CacheKey = 'QueueGetID::' . $Param{ID};
        $Key      = 'ID';
        $Value    = $Param{ID};
    }
    else {
        $CacheKey = 'QueueGetName::' . $Param{Name};
        $Key      = 'Name';
        $Value    = $Param{Name};
    }

    # check cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # sql
    my @Bind;
    my $SQL = 'SELECT q.id, q.name, q.unlock_timeout, '
        . 'q.system_address_id, q.signature, q.comments, q.valid_id, '
        . 'q.follow_up_id, q.follow_up_lock, '
        . 'q.default_sign_key, q.calendar_name, q.create_by, q.create_time, q.change_by, q.change_time FROM queue q, '
        . 'system_address sa WHERE q.system_address_id = sa.id AND ';

    if ( $Param{ID} ) {
        $SQL .= 'q.id = ?';
        push @Bind, \$Param{ID};
    }
    else {
        $SQL .= 'q.name = ?';
        push @Bind, \$Param{Name};
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => 1,
    );

    # fetch the result
    my %Data;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %Data = (
            QueueID             => $Data[0],
            Name                => $Data[1],
            UnlockTimeout       => $Data[2],
            SystemAddressID     => $Data[3],
            Signature           => $Data[4],
            Comment             => $Data[5],
            ValidID             => $Data[6],
            FollowUpID          => $Data[7],
            FollowUpLock        => $Data[8],
            DefaultSignKey      => $Data[9],
            Calendar            => $Data[10] || '',
            CreateBy            => $Data[11],
            CreateTime          => $Data[12],
            ChangeBy            => $Data[13],
            ChangeTime          => $Data[14],
        );
    }

    # check if data exists
    if ( !%Data ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Found no $Key for $Value!",
        );
        return;
    }

    # get queue preferences
    my %Preferences = $Self->QueuePreferencesGet( QueueID => $Data{QueueID} );

    # merge hash
    if (%Preferences) {
        %Data = ( %Data, %Preferences );
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

=item QueueListGet()

get queue attributes of multiple queues

    my $QueueDataArrayRef = $QueueObject->QueueListGet(
        IDs => [...],
    );

=cut

sub QueueListGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !IsArrayRefWithData($Param{IDs}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need IDs array!'
        );
        return;
    }

    # check cache
    my $CacheKey = 'QueueListGet::' . join('::', @{$Param{IDs}});
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    # sql
    my @BindRefList = map { \$_ } @{$Param{IDs}};
    my $SQL = 'SELECT q.id, q.name, q.unlock_timeout, '
        . 'q.system_address_id, q.signature, q.comments, q.valid_id, '
        . 'q.follow_up_id, q.follow_up_lock, '
        . 'q.default_sign_key, q.calendar_name, q.create_by, q.create_time, q.change_by, q.change_time FROM queue q, '
        . 'system_address sa WHERE q.system_address_id = sa.id AND q.id IN ('.(join( ',', map { '?' } @{$Param{IDs}})).')';

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@BindRefList,
    );

    # fetch the result
    my $Result = $Kernel::OM->Get('DB')->FetchAllArrayRef(
        Columns => [
            'QueueID', 'Name', 'UnlockTimeout', 'SystemAddressID', 'Signature', 'Comment', 'ValidID',
            'FollowUpID', 'FollowUpLock', 'DefaultSignKey', 'Calendar', 'CreateBy', 'CreateTime', 'ChangeBy', 'ChangeTime'
        ],
    );

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => $Result,
    );

    return $Result;
}

=item QueueUpdate()

update queue attributes

    $QueueObject->QueueUpdate(
        QueueID             => 123,
        Name                => 'Some::Queue',
        ValidID             => 1,
        Calendar            => '1', # (optional) default ''
        SystemAddressID     => 1,
        Signature           => '',
        UserID              => 123,
        FollowUpID          => 1,
        Comment             => 'Some Comment2',
        DefaultSignKey      => ''
        UnlockTimeout       => ''
        FollowUpLock        => 1,
        ParentQueueID       => '',
        CheckSysConfig      => 0,   # (optional) default 1
    );

=cut

sub QueueUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (
        qw(QueueID Name ValidID SystemAddressID UserID FollowUpID)
        )
    {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check CheckSysConfig param
    if ( !defined $Param{CheckSysConfig} ) {
        $Param{CheckSysConfig} = 1;
    }

    # FollowUpLock 0 | 1
    $Param{FollowUpLock} = $Param{FollowUpLock} || 0;

    $Param{UnlockTimeout} = $Param{UnlockTimeout} || 0;

    # DefaultSignKey   '' || 'string'
    $Param{DefaultSignKey} = $Param{DefaultSignKey} || '';

    # Calendar string  '', '1', '2', '3', '4', '5'  default ''
    $Param{Calendar} ||= '';

    # cleanup queue name
    $Param{Name} =~ s/(\n|\r)//g;
    $Param{Name} =~ s/\s$//g;

    # check queue name
    if ( $Param{Name} =~ /::$/i ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Invalid Queue name '$Param{Name}'!",
        );
        return;
    }

    # check if queue name exists
    my %AllQueue = $Self->QueueList( Valid => 0 );
    my %OldQueue = $Self->QueueGet( ID => $Param{QueueID} );

    # check if a queue with this name already exists
    if (
        $Self->NameExistsCheck(
            ID   => $Param{QueueID},
            Name => $Param{Name}
        )
        )
    {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A queue with name '$Param{Name}' already exists!"
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # SQL
    return if !$DBObject->Do(
        SQL => '
            UPDATE queue
            SET name = ?, comments = ?, unlock_timeout = ?, follow_up_id = ?,
                follow_up_lock = ?, system_address_id = ?,
                calendar_name = ?, default_sign_key = ?, signature = ?,
                valid_id = ?, change_time = current_timestamp, change_by = ?
            WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{Comment}, \$Param{UnlockTimeout},
            \$Param{FollowUpID},        \$Param{FollowUpLock},        \$Param{SystemAddressID},
            \$Param{Calendar},          \$Param{DefaultSignKey},      \$Param{Signature},
            \$Param{ValidID},           \$Param{UserID},              \$Param{QueueID},
        ],
    );

    # get queue data with updated name for QueueUpdate event
    my %Queue = $Self->QueueGet( Name => $Param{Name} );

    # trigger event
    $Self->EventHandler(
        Event => 'QueueUpdate',
        Data  => {
            Queue    => \%Queue,
            OldQueue => \%OldQueue,
        },
        UserID => $Param{UserID},
    );

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # updated all sub queue names
    my @ParentQueue = split( /::/, $OldQueue{Name} );

    for my $QueueID ( sort keys %AllQueue ) {

        my @SubQueue = split( /::/, $AllQueue{$QueueID} );

        if ( $#SubQueue > $#ParentQueue ) {

            if ( $AllQueue{$QueueID} =~ /^\Q$OldQueue{Name}::\E/i ) {

                my $NewQueueName = $AllQueue{$QueueID};
                $NewQueueName =~ s/\Q$OldQueue{Name}\E/$Param{Name}/;

                return if !$DBObject->Do(
                    SQL => '
                        UPDATE queue
                        SET name = ?, change_time = current_timestamp, change_by = ?
                        WHERE id = ?',
                    Bind => [ \$NewQueueName, \$Param{UserID}, \$QueueID ],
                );

                # reset cache
                $Kernel::OM->Get('Cache')->CleanUp(
                    Type => $Self->{CacheType},
                );
            }
        }
    }

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Queue',
        ObjectID  => $Param{QueueID},
    );

    # check all SysConfig options
    #return 1 if !$Param{CheckSysConfig};

    # check all SysConfig options and correct them automatically if necessary
    #$Kernel::OM->Get('SysConfig')->ConfigItemCheckAll();

    return 1;
}

=item QueueList()

get all queues

    my %Queues = $QueueObject->QueueList();

    my %Queues = $QueueObject->QueueList( Valid => 1 );

=cut

sub QueueList {
    my ( $Self, %Param ) = @_;

    # set valid option
    my $Valid = $Param{Valid};
    if ( !defined $Valid || $Valid ) {
        $Valid = 1;
    }
    else {
        $Valid = 0;
    }

    # check cache
    my $CacheKey = 'QueueList::' . $Valid;
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # sql query
    if ($Valid) {
        return if !$DBObject->Prepare(
            SQL => "SELECT id, name FROM queue WHERE valid_id IN "
                . "( ${\(join ', ', $Kernel::OM->Get('Valid')->ValidIDsGet())} )",
        );
    }
    else {
        return if !$DBObject->Prepare(
            SQL => 'SELECT id, name FROM queue',
        );
    }

    # fetch the result
    my %Queues;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Queues{ $Row[0] } = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Queues,
    );

    return %Queues;
}

=item QueuePreferencesSet()

set queue preferences

    $QueueObject->QueuePreferencesSet(
        QueueID => 123,
        Key     => 'UserComment',
        Value   => 'some comment',
        UserID  => 123,
    );

=cut

sub QueuePreferencesSet {
    my ( $Self, %Param ) = @_;

    # delete cache
    my $Name = $Self->QueueLookup( QueueID => $Param{QueueID} );
    my @CacheKeys = (
        'QueueGetID::' . $Param{QueueID},
        'QueueGetName::' . $Name,
    );
    for my $CacheKey (@CacheKeys) {
        $Kernel::OM->Get('Cache')->Delete(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
    }

    my $Result = $Self->{PreferencesObject}->QueuePreferencesSet(%Param);

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Queue.Preference',
        ObjectID  => $Param{QueueID}.'::'.$Param{Key},
    );

    return $Result;
}

=item QueuePreferencesGet()

get queue preferences

    my %Preferences = $QueueObject->QueuePreferencesGet(
        QueueID => 123,
        UserID  => 123,
    );

=cut

sub QueuePreferencesGet {
    my ( $Self, %Param ) = @_;

    return $Self->{PreferencesObject}->QueuePreferencesGet(%Param);
}

sub DESTROY {
    my $Self = shift;

    # execute all transaction events
    $Self->EventHandlerTransaction();

    return 1;
}

=item NameExistsCheck()

return 1 if another queue with this name already exists

    $Exist = $QueueObject->NameExistsCheck(
        Name => 'Some::Queue',
        ID => 1, # optional
    );

=cut

sub NameExistsCheck {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM queue WHERE name = ?',
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

sub QueueDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(QueueID UserID)) {
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
        SQL  => 'DELETE FROM queue WHERE id = ?',
        Bind => [ \$Param{QueueID} ],
    );

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Queue',
        ObjectID  => $Param{QueueID},
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
