# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Queue;

use strict;
use warnings;

use base qw(
    Kernel::System::Queue::FollowUp
    Kernel::System::EventHandler
);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::StandardTemplate',
    'Kernel::System::SysConfig',
    'Kernel::System::Valid',
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
    my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');

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
    my $GeneratorModule = $Kernel::OM->Get('Kernel::Config')->Get('Queue::PreferencesModule')
        || 'Kernel::System::Queue::PreferencesDB';
    if ( $Kernel::OM->Get('Kernel::System::Main')->Require($GeneratorModule) ) {
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
        UpdateTime          => 0,
        UpdateNotify        => 0,
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need AddressID!',
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

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
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

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

=item QueueStandardTemplateMemberAdd()

to add a template to a queue

    my $Success = $QueueObject->QueueStandardTemplateMemberAdd(
        QueueID            => 123,
        StandardTemplateID => 123,
        Active             => 1,        # to set/confirm (1) or remove (0) the relation
        UserID             => 123,
    );

=cut

sub QueueStandardTemplateMemberAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(QueueID StandardTemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # delete existing relation
    return if !$DBObject->Do(
        SQL => 'DELETE FROM queue_standard_template
            WHERE queue_id = ?
            AND standard_template_id = ?',
        Bind => [ \$Param{QueueID}, \$Param{StandardTemplateID} ],
    );

    # return if relation is not active
    if ( !$Param{Active} ) {
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
            Type => $Self->{CacheType},
        );
        return 1;
    }

    # insert new relation
    my $Success = $DBObject->Do(
        SQL => '
            INSERT INTO queue_standard_template (queue_id, standard_template_id, create_time,
                create_by, change_time, change_by)
            VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [ \$Param{QueueID}, \$Param{StandardTemplateID}, \$Param{UserID}, \$Param{UserID} ],
    );

    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Queue.StandardTemplate',
        ObjectID  => $Param{QueueID}.'::'.$Param{StandardTemplateID},
    );

    return $Success;
}

=item QueueStandardTemplateMemberList()

get std responses of a queue

    my %Templates = $QueueObject->QueueStandardTemplateMemberList( QueueID => 123 );

Returns:
    %Templates = (
        1 => 'Some Name',
        2 => 'Some Name',
    );

    my %Responses = $QueueObject->QueueStandardTemplateMemberList(
        QueueID       => 123,
        TemplateTypes => 1,
    );

Returns:
    %Responses = (
        Answer => {
            1 => 'Some Name',
            2 => 'Some Name',
        },
        # ...
    );

    my %Queues = $QueueObject->QueueStandardTemplateMemberList( StandardTemplateID => 123 );

Returns:
    %Queues = (
        1 => 'Some Name',
        2 => 'Some Name',
    );

=cut

sub QueueStandardTemplateMemberList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{QueueID} && !$Param{StandardTemplateID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got no StandardTemplateID or QueueID!',
        );
        return;
    }

    # get needed objects
    my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');

    my $TemplateTypes = $Param{TemplateTypes} || '0';

    my $CacheKey;

    if ( $Param{QueueID} ) {

        # check if this result is present (in cache)
        $CacheKey = "StandardTemplates::$Param{QueueID}::$TemplateTypes";
        my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return %{$Cache} if ref $Cache eq 'HASH';

        # get std. templates
        my $SQL = "SELECT st.id, st.name, st.template_type "
            . " FROM standard_template st, queue_standard_template qst WHERE "
            . " qst.queue_id IN ("
            . $DBObject->Quote( $Param{QueueID}, 'Integer' )
            . ") AND "
            . " qst.standard_template_id = st.id AND "
            . " st.valid_id IN ( ${\(join ', ', $ValidObject->ValidIDsGet())} )"
            . " ORDER BY st.name";

        return if !$DBObject->Prepare( SQL => $SQL );

        # fetch the result
        my %StandardTemplates;
        while ( my @Row = $DBObject->FetchrowArray() ) {

            if ( $Param{TemplateTypes} ) {
                $StandardTemplates{ $Row[2] }->{ $Row[0] } = $Row[1];
            }
            else {
                $StandardTemplates{ $Row[0] } = $Row[1];
            }
        }

        # store std templates (in cache)
        $Kernel::OM->Get('Kernel::System::Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => \%StandardTemplates,

        );
        return %StandardTemplates;
    }

    else {

        # check if this result is present (in cache)
        $CacheKey = "Queues::$Param{StandardTemplateID}";
        my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return %{$Cache} if ref $Cache eq 'HASH';

        # get queues
        my $SQL = "SELECT q.id, q.name "
            . " FROM queue q, queue_standard_template qst WHERE "
            . " qst.standard_template_id IN ("
            . $DBObject->Quote( $Param{StandardTemplateID}, 'Integer' )
            . ") AND "
            . " qst.queue_id = q.id AND "
            . " q.valid_id IN ( ${\(join ', ', $ValidObject->ValidIDsGet())} )"
            . " ORDER BY q.name";

        return if !$DBObject->Prepare( SQL => $SQL );

        # fetch the result
        my %Queues;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $Queues{ $Row[0] } = $Row[1];
        }

        # store queues (in cache)
        $Kernel::OM->Get('Kernel::System::Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => \%Queues,
        );

        return %Queues;
    }
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
    my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');

    # fetch all queues
    my $CacheKey;
    if ( $Param{UserID} ) {
        $CacheKey = "GetAllQueues::UserID::${Type}::$Param{UserID}";

        # check cache
        my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
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
        my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
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
        my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
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
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%MoveQueues,
    );

    return %MoveQueues;
}

=item GetAllCustomQueues()

get all custom queues of one user

    my @Queues = $QueueObject->GetAllCustomQueues( UserID => 123 );

=cut

sub GetAllCustomQueues {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!'
        );
        return;
    }

    # check cache
    my $CacheKey = 'GetAllCustomQueues::' . $Param{UserID};
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # search all custom queues
    return if !$DBObject->Prepare(
        SQL  => 'SELECT queue_id FROM personal_queues WHERE user_id = ?',
        Bind => [ \$Param{UserID} ],
    );

    # fetch the result
    my @QueueIDs;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @QueueIDs, $Row[0];
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \@QueueIDs,
    );

    return @QueueIDs;
}

=item GetAllSubQueues()

get all sub queues of a queue

    my %Queues = $QueueObject->GetAllSubQueues( QueueID => 123 );

=cut

sub GetAllSubQueues {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{QueueID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need QueueID!'
        );
        return;
    }

    # check cache
    my $CacheKey = 'GetAllSubQueues::' . $Param{QueueID};
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # search all custom queues
    return if !$DBObject->Prepare(
        SQL  => "SELECT q2.id, q2.name FROM queue q1, queue q2 WHERE q1.id = ? AND q2.id <> ? AND q2.name like q1.name||'::%'",
        Bind => [ \$Param{QueueID}, \$Param{QueueID} ],
    );

    # fetch the result
    my %QueueIDs;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $QueueIDs{$Row[0]} = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%QueueIDs,
    );

    return %QueueIDs;
}

=item QueueLookup()

get id or name for queue

    my $Queue = $QueueObject->QueueLookup( QueueID => $QueueID );

    my $QueueID = $QueueObject->QueueLookup( Queue => $Queue );

=cut

sub QueueLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Queue} && !$Param{QueueID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got no Queue or QueueID!'
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
    else {
        $Key   = 'Queue';
        $Value = $Param{Queue};
        my %QueueListReverse = reverse %QueueList;
        $ReturnData = $QueueListReverse{ $Param{Queue} };
    }

    # check if data exists
    if ( !$ReturnData ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Found no $Key for $Value!",
        );
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
                $Param{$_} = $Self->{QueueDefaults}->{$_} || 0;
            }
        }
    }

    for (qw(Name SystemAddressID ValidID UserID FollowUpID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Invalid Queue name '$Param{Name}'!",
        );
        return;
    }

    # check if a queue with this name already exists
    if ( $Self->NameExistsCheck( Name => $Param{Name} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A queue with name '$Param{Name}' already exists!"
        );
        return;
    }

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');

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
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    my $StandardTemplate2QueueByCreating = $ConfigObject->Get('StandardTemplate2QueueByCreating');

    # add default responses (if needed), add response by name
    if (
        $StandardTemplate2QueueByCreating
        && ref $StandardTemplate2QueueByCreating eq 'ARRAY'
        && @{$StandardTemplate2QueueByCreating}
        )
    {

        # get standard template object
        my $StandardTemplateObject = $Kernel::OM->Get('Kernel::System::StandardTemplate');

        ST:
        for my $ST ( @{$StandardTemplate2QueueByCreating} ) {

            my $StandardTemplateID = $StandardTemplateObject->StandardTemplateLookup(
                StandardTemplate => $ST,
            );

            next ST if !$StandardTemplateID;

            $Self->QueueStandardTemplateMemberAdd(
                QueueID            => $QueueID,
                StandardTemplateID => $StandardTemplateID,
                Active             => 1,
                UserID             => $Param{UserID},
            );
        }
    }

    # get standard template id
    my $StandardTemplateID2QueueByCreating = $ConfigObject->Get(' StandardTemplate2QueueByCreating');

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

    return $QueueID if !$StandardTemplateID2QueueByCreating;
    return $QueueID if ref $StandardTemplateID2QueueByCreating ne 'ARRAY';
    return $QueueID if !@{$StandardTemplateID2QueueByCreating};

    # add template by id
    for my $StandardTemplateID ( @{$StandardTemplateID2QueueByCreating} ) {

        $Self->QueueStandardTemplateMemberAdd(
            QueueID            => $QueueID,
            StandardTemplateID => $StandardTemplateID,
            Active             => 1,
            UserID             => $Param{UserID},
        );
    }

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
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
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
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
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
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
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    );

    return %Data;
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
        UnlockTimeOut       => ''
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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

    # DefaultSignKey   '' || 'string'
    $Param{DefaultSignKey} = $Param{DefaultSignKey} || '';

    # Calendar string  '', '1', '2', '3', '4', '5'  default ''
    $Param{Calendar} ||= '';

    # cleanup queue name
    $Param{Name} =~ s/(\n|\r)//g;
    $Param{Name} =~ s/\s$//g;

    # check queue name
    if ( $Param{Name} =~ /::$/i ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A queue with name '$Param{Name}' already exists!"
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

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
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
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
                $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
                    Type => $Self->{CacheType},
                );
            }
        }
    }

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Queue',
        ObjectID  => $Param{QueueID},
    );
    
    # check all SysConfig options
    return 1 if !$Param{CheckSysConfig};

    # check all SysConfig options and correct them automatically if necessary
    $Kernel::OM->Get('Kernel::System::SysConfig')->ConfigItemCheckAll();

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
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # sql query
    if ($Valid) {
        return if !$DBObject->Prepare(
            SQL => "SELECT id, name FROM queue WHERE valid_id IN "
                . "( ${\(join ', ', $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet())} )",
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
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
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
        $Kernel::OM->Get('Kernel::System::Cache')->Delete(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
    }

    my $Result = $Self->{PreferencesObject}->QueuePreferencesSet(%Param);

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
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
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL  => 'DELETE FROM queue WHERE id = ?',
        Bind => [ \$Param{QueueID} ],
    );

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
