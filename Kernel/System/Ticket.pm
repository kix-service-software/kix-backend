# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket;

use strict;
use warnings;

use File::Path;
use utf8;
use Encode ();
use Time::HiRes;

use Kernel::Language qw(Translatable);
use Kernel::System::AsynchronousExecutor;
use Kernel::System::PreEventHandler;
use Kernel::System::EventHandler;
use Kernel::System::Ticket::Article;
use Kernel::System::Ticket::ArticleStorage;
use Kernel::System::Ticket::TicketIndex;
use Kernel::System::Ticket::BasePermission;
use Kernel::System::VariableCheck qw(:all);

use vars qw(@ISA);

our @ObjectDependencies = (
    'ClientRegistration',
    'Config',
    'Cache',
    'Contact',
    'DB',
    'DynamicField',
    'DynamicField::Backend',
    'Email',
    'HTMLUtils',
    'LinkObject',
    'Lock',
    'Log',
    'Main',
    'Priority',
    'Queue',
    'State',
    'TemplateGenerator',
    'Time',
    'Type',
    'User',
    'Valid',
);

=head1 NAME

Kernel::System::Ticket - ticket lib

=head1 SYNOPSIS

All ticket functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TicketObject = $Kernel::OM->Get('Ticket');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=on;
    $Self->{Debug} = $Param{Debug} || 0;

    $Self->{CacheType} = 'Ticket';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    @ISA = qw(
        Kernel::System::Ticket::Article
        Kernel::System::Ticket::ArticleStorage
        Kernel::System::Ticket::TicketIndex
        Kernel::System::Ticket::BasePermission
        Kernel::System::PreEventHandler
        Kernel::System::EventHandler
        Kernel::System::PerfLog
        Kernel::System::AsynchronousExecutor
    );

    # init of pre-event handler
    $Self->PreEventHandlerInit(
        Config     => 'Ticket::EventModulePre',
        BaseObject => 'Ticket',
        Objects    => {
            %{$Self},
        },
    );

    # init of event handler
    $Self->EventHandlerInit(
        Config => 'Ticket::EventModulePost',
    );

    # load ticket number generator
    my $GeneratorModule = $Kernel::OM->Get('Config')->Get('Ticket::NumberGenerator')
        || 'Kernel::System::Ticket::Number::AutoIncrement';
    if ( !$Kernel::OM->Get('Main')->RequireBaseClass($GeneratorModule) ) {
        die "Can't load ticket number generator backend module $GeneratorModule! $@";
    }


    # load article search index module
    my $SearchIndexModule = $Kernel::OM->Get('Config')->Get('Ticket::SearchIndexModule')
        || 'Kernel::System::Ticket::ArticleSearchIndex::RuntimeDB';
    if ( !$Kernel::OM->Get('Main')->RequireBaseClass($SearchIndexModule) ) {
        die "Can't load ticket search index backend module $SearchIndexModule! $@";
    }

    # load ticket extension modules
    my $CustomModule = $Kernel::OM->Get('Config')->Get('Ticket::CustomModule');
    if ($CustomModule) {

        my %ModuleList;
        if ( ref $CustomModule eq 'HASH' ) {
            %ModuleList = %{$CustomModule};
        }
        else {
            $ModuleList{Init} = $CustomModule;
        }

        MODULEKEY:
        for my $ModuleKey ( sort keys %ModuleList ) {

            my $Module = $ModuleList{$ModuleKey};

            next MODULEKEY if !$Module;
            next MODULEKEY if !$Kernel::OM->Get('Main')->RequireBaseClass($Module);
        }
    }

    # init of article backend
    $Self->ArticleStorageInit();

    return $Self;
}

=item TicketCreateNumber()

creates a new ticket number

    my $TicketNumber = $TicketObject->TicketCreateNumber();

=cut

# use it from Kernel/System/Ticket/Number/*.pm

=item TicketCheckNumber()

checks if ticket number exists, returns ticket id if number exists.

returns the merged ticket id if ticket was merged.
only into a depth of maximum 10 merges

    my $TicketID = $TicketObject->TicketCheckNumber(
        Tn => '200404051004575',
    );

=cut

sub TicketCheckNumber {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Tn} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need TN!'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db query
    return if !$DBObject->Prepare(
        SQL   => 'SELECT id FROM ticket WHERE tn = ?',
        Bind  => [ \$Param{Tn} ],
        Limit => 1,
    );

    my $TicketID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $TicketID = $Row[0];
    }

    # get main ticket id if ticket has been merged
    return if !$TicketID;

    # do not check deeper than 10 merges
    my $Limit = 10;
    my $Count = 1;
    MERGELOOP:
    for ( 1 .. $Limit ) {
        my %Ticket = $Self->TicketGet(
            TicketID      => $TicketID,
            DynamicFields => 0,
        );

        return $TicketID if $Ticket{StateType} ne 'merged';

        # get ticket history
        my @Lines = $Self->HistoryGet(
            TicketID => $TicketID,
            UserID   => 1,
        );

        HISTORYLINE:
        for my $Data ( reverse @Lines ) {
            next HISTORYLINE if $Data->{HistoryType} ne 'Merged';
            if ( $Data->{Name} =~ /^.*\(\d+?\/(\d+?)\)$/ ) {
                $TicketID = $1;
                $Count++;
                next MERGELOOP if ( $Count <= $Limit );

                # returns no found Ticket after 10 deep-merges, so it should create a new one
                return;
            }
        }

        return $TicketID;
    }
}

=item TicketCreate()

creates a new ticket

    my $TicketID = $TicketObject->TicketCreate(
        Title          => 'Some Ticket Title',
        Queue          => 'Raw',                             # or QueueID => 123
        Lock           => 'unlock',
        Priority       => '3 normal',                        # or PriorityID => 2
        State          => 'new',                             # or StateID => 5
        OrganisationID => '123465',                          # optional
        ContactID      => 123 || 'customer@example.com',     # optional
        OwnerID        => 123,                               # optional
        TimeUnit       => 123,                               # optional
        UserID         => 123
    );

or

    my $TicketID = $TicketObject->TicketCreate(
        TN             => $TicketObject->TicketCreateNumber(),  # optional
        Title          => 'Some Ticket Title',
        Queue          => 'Raw',                                # or QueueID => 123
        Lock           => 'unlock',
        Priority       => '3 normal',                           # or PriorityID => 2
        State          => 'new',                                # or StateID => 5
        Type           => 'Incident',                           # or TypeID = 1 or Ticket type default (Ticket::Type::Default), optional
        OrganisationID => '123465',                             # optional
        ContactID      => '123' || 'customer@example.com',      # optional
        OwnerID        => 123,                                  # optional
        ResponsibleID  => 123,                                  # optional
        ArchiveFlag    => 'y',                                  # (y|n) optional
        UserID         => 123
    );

Events:
    TicketCreate

=cut

sub TicketCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(OwnerID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # set default values if no values are specified
    my $Age = $Kernel::OM->Get('Time')->SystemTime();

    my $ArchiveFlag = 0;
    if ( $Param{ArchiveFlag} && $Param{ArchiveFlag} eq 'y' ) {
        $ArchiveFlag = 1;
    }

    $Param{ResponsibleID} ||= 1;

    # get type object
    my $TypeObject = $Kernel::OM->Get('Type');

    if ( !$Param{TypeID} && !$Param{Type} ) {

        # get default ticket type
        my $DefaultTicketType = $Kernel::OM->Get('Config')->Get('Ticket::Type::Default');

        # check if default ticket type exists
        my %AllTicketTypes = reverse $TypeObject->TypeList();

        if ( $AllTicketTypes{$DefaultTicketType} ) {
            $Param{Type} = $DefaultTicketType;
        }
        else {
            if ( $DefaultTicketType ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown default type \"$DefaultTicketType\" in config setting Ticket::Type::Default!",
                );
            }

            $Param{TypeID} = 1;
        }
    }

    # TypeID/Type lookup!
    if ( !$Param{TypeID} && $Param{Type} ) {
        $Param{TypeID} = $TypeObject->TypeLookup( Type => $Param{Type} );
    }
    elsif ( $Param{TypeID} && !$Param{Type} ) {
        $Param{Type} = $TypeObject->TypeLookup( TypeID => $Param{TypeID} );
    }
    if ( !$Param{TypeID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No TypeID for '$Param{Type}'!",
        );
        return;
    }

    # get queue object
    my $QueueObject = $Kernel::OM->Get('Queue');

    if ( !$Param{QueueID} && !$Param{Queue} ) {

        # get default queue
        my $DefaultTicketQueue = $Kernel::OM->Get('Config')->Get('Ticket::Queue::Default');

        # check if default queue exists
        my %AllTicketQueues = reverse $QueueObject->QueueList();

        if ( $AllTicketQueues{$DefaultTicketQueue} ) {
            $Param{Queue} = $DefaultTicketQueue;
        }
        else {
            if ( $DefaultTicketQueue ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown default queue \"$DefaultTicketQueue\" in config setting Ticket::Queue::Default!",
                );
            }

            $Param{QueueID} = 1;
        }
    }

    # QueueID/Queue lookup!
    if ( !$Param{QueueID} && $Param{Queue} ) {
        $Param{QueueID} = $QueueObject->QueueLookup(
            Queue  => $Param{Queue},
            Silent => $Param{Silent}
        );
    }
    elsif ( !$Param{Queue} ) {
        $Param{Queue} = $QueueObject->QueueLookup(
            QueueID => $Param{QueueID},
            Silent  => $Param{Silent}
        );
    }
    if ( !$Param{QueueID} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No QueueID for '$Param{Queue}'!",
            );
        }
        return;
    }

    # get state object
    my $StateObject = $Kernel::OM->Get('State');

    if ( !$Param{StateID} && !$Param{State} ) {

        # get default ticket state
        my $DefaultTicketState = $Kernel::OM->Get('Config')->Get('Ticket::State::Default');

        # check if default ticket state exists
        my %AllTicketStates = reverse $StateObject->StateList( UserID => 1);

        if ( $AllTicketStates{$DefaultTicketState} ) {
            $Param{State} = $DefaultTicketState;
        }
        else {
            if ( $DefaultTicketState ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown default state \"$DefaultTicketState\" in config setting Ticket::State::Default!",
                );
            }
            $Param{StateID} = 1;
        }
    }

    # StateID/State lookup!
    if ( !$Param{StateID} ) {
        my %State = $StateObject->StateGet( Name => $Param{State} );
        $Param{StateID} = $State{ID};
    }
    elsif ( !$Param{State} ) {
        my %State = $StateObject->StateGet( ID => $Param{StateID} );
        $Param{State} = $State{Name};
    }
    if ( !$Param{StateID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No StateID for '$Param{State}'!",
        );
        return;
    }

    # LockID lookup!
    if ( !$Param{LockID} && $Param{Lock} ) {

        $Param{LockID} = $Kernel::OM->Get('Lock')->LockLookup(
            Lock => $Param{Lock},
        );
    }
    if ( !$Param{LockID} && !$Param{Lock} ) {

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No LockID and no LockType!',
        );
        return;
    }

    # get priority object
    my $PriorityObject = $Kernel::OM->Get('Priority');

    if ( !$Param{PriorityID} && !$Param{Priority} ) {

        # get default priority
        my $DefaultTicketPriority = $Kernel::OM->Get('Config')->Get('Ticket::Priority::Default');

        # check if default priority exists
        my %AllTicketPrioritys = reverse $PriorityObject->PriorityList();

        if ( $AllTicketPrioritys{$DefaultTicketPriority} ) {
            $Param{Priority} = $DefaultTicketPriority;
        }
        else {
            if ( $DefaultTicketPriority ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown default priority \"$DefaultTicketPriority\" in config setting Ticket::Priority::Default!",
                );
            }
            $Param{PriorityID} = 1;
        }
    }

    # PriorityID/Priority lookup!
    if ( !$Param{PriorityID} && $Param{Priority} ) {
        $Param{PriorityID} = $PriorityObject->PriorityLookup(
            Priority => $Param{Priority},
        );
    }
    elsif ( $Param{PriorityID} && !$Param{Priority} ) {
        $Param{Priority} = $PriorityObject->PriorityLookup(
            PriorityID => $Param{PriorityID},
        );
    }
    if ( !$Param{PriorityID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No PriorityID (invalid Priority Name?)!',
        );
        return;
    }

    # create ticket number if none is given
    if ( !$Param{TN} ) {
        $Param{TN} = $Self->TicketCreateNumber();
    }

    # check ticket title
    if ( !defined $Param{Title} ) {
        $Param{Title} = '';
    } else {

        # TODO: replace placeholders
        # $Param{Title} = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
        #     RichText => 0,
        #     Text     => $Param{Title},
        #     Data     => \%Param,
        #     UserID   => $Param{UserID},
        # );

        # substitute title if needed
        $Param{Title} = substr( $Param{Title}, 0, 255 );
    }

    # check given organisation id
    my $ExistingOrganisationID;

    if ( $Param{OrganisationID} ) {
        if ($Param{OrganisationID} =~ /^\d+$/) {
            my $FoundOrgNumber = $Kernel::OM->Get('Organisation')->OrganisationLookup(
                ID     => $Param{OrganisationID},
                Silent => 1
            );
            if ($FoundOrgNumber) {
                $ExistingOrganisationID = $Param{OrganisationID};
            }
        }
        if (!$ExistingOrganisationID) {
            my $FoundOrgID = $Kernel::OM->Get('Organisation')->OrganisationLookup(
                Number => $Param{OrganisationID},
                Silent => 1
            );
            if ($FoundOrgID) {
                $ExistingOrganisationID = $FoundOrgID;
            }
        }
    }

    # create contact if necessary
    if ( $Param{ContactID } ) {
        if ( $Param{ContactID} !~ /^\d+$/ ) {
            my $ContactID = $Kernel::OM->Get('Contact')->GetOrCreateID(
                Email                 => $Param{ContactID},
                PrimaryOrganisationID => $ExistingOrganisationID,
                UserID                => $Param{UserID},
            );
            if ( !$ContactID ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Could not get Contact for email "' . $Param{ContactID} . '"!'
                );
            }
            elsif ( $Param{ContactID} !~ /^\d+$/ ) {
                $Param{ContactID} = $ContactID;
            }
        }

        if ( $Param{ContactID} =~ /^\d+$/ ) {
            my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
                ID     => $Param{ContactID},
                Silent => 1,
            );
            if ( IsHashRefWithData( \%ContactData ) ) {
                # set organisation if not given at all (also no unknown)
                # FIXME: remove this with KIX2018-6884
                if ( $ContactData{PrimaryOrganisationID} && !$Param{OrganisationID} ) {
                    $ExistingOrganisationID = $ContactData{PrimaryOrganisationID};
                }
            } else {
                $Param{ContactID} = undef;
            }
        }
    }

    # make sure it's undef and no empty string, so that the result is a NULL value in the DB
    if ( !$Param{ContactID} ) {
        $Param{ContactID} = undef;
    }

    # create organisation if it doesn't exist
    if ( !$ExistingOrganisationID && $Param{OrganisationID} ) {
        $ExistingOrganisationID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
            Number => $Param{OrganisationID},
            Name   => $Param{OrganisationID},
            UserID => $Param{UserID}
        );
    }

    # update contact if necessary (add given or new organisation)
    if ($ExistingOrganisationID && $Param{ContactID}) {
        my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
            ID => $Param{ContactID},
        );
        if (IsHashRefWithData(\%ContactData)) {
            if (!$ContactData{PrimaryOrganisationID}) {
                $ContactData{PrimaryOrganisationID} = $ExistingOrganisationID;
                $Kernel::OM->Get('Contact')->ContactUpdate(
                    %ContactData,
                    UserID => $Param{UserID}
                );
            } elsif (!grep {$_ == $ExistingOrganisationID} @{ $ContactData{OrganisationIDs} }) {
                push( @{ $ContactData{OrganisationIDs} }, $ExistingOrganisationID );

                $Kernel::OM->Get('Contact')->ContactUpdate(
                    %ContactData,
                    UserID => $Param{UserID}
                );
            }
        }
    }

    # make sure it's undef and no empty string, so that the result is a NULL value in the DB
    if ( !$ExistingOrganisationID ) {
        $ExistingOrganisationID = undef;
    }

    # create db record
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => '
            INSERT INTO ticket (
                tn, title, create_time_unix, type_id, queue_id, ticket_lock_id, user_id,
                responsible_user_id, ticket_priority_id, ticket_state_id, timeout,
                until_time, archive_flag, create_time, create_by, change_time, change_by,
                contact_id, organisation_id)
            VALUES (?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, 0,
                    0, ?, current_timestamp, ?, current_timestamp, ?,
                    ?, ?)',
        Bind => [
            \$Param{TN}, \$Param{Title}, \$Age, \$Param{TypeID}, \$Param{QueueID}, \$Param{LockID},
            \$Param{OwnerID}, \$Param{ResponsibleID}, \$Param{PriorityID}, \$Param{StateID},
            \$ArchiveFlag, \$Param{UserID}, \$Param{UserID},
            \$Param{ContactID}, \$ExistingOrganisationID,
        ],
    );

    # get ticket id
    my $TicketID = $Self->TicketIDLookup(
        TicketNumber => $Param{TN},
        UserID       => $Param{UserID},
    );

    # add history entry
    $Self->HistoryAdd(
        TicketID     => $TicketID,
        QueueID      => $Param{QueueID},
        HistoryType  => 'NewTicket',
        Name         => "\%\%$Param{TN}\%\%$Param{Queue}\%\%$Param{Priority}\%\%$Param{State}\%\%$TicketID",
        CreateUserID => $Param{UserID},
    );

    # log ticket creation
    $Kernel::OM->Get('Log')->Log(
        Priority => 'info',
        Message  => "New Ticket [$Param{TN}/" . substr( $Param{Title}, 0, 15 ) . "] created "
            . "(TicketID=$TicketID,Queue=$Param{Queue},Priority=$Param{Priority},State=$Param{State})",
    );

    # update ticket index
    $Self->TicketIndexAdd(TicketID => $TicketID);

    # clear general ticket cache
    $Self->_TicketCacheClear();

    # trigger event
    $Self->EventHandler(
        Event => 'TicketCreate',
        Data  => {
            TicketID => $TicketID,
            OwnerID  => $Param{OwnerID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Ticket',
        ObjectID  => $TicketID,
    );

    return $TicketID;
}

=item TicketDelete()

deletes a ticket with articles from storage

    my $Success = $TicketObject->TicketDelete(
        TicketID => 123,
        UserID   => 123,
    );

Events:
    TicketDelete

=cut

sub TicketDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # get the ticket data
    my %Ticket = $Self->TicketGet(
        TicketID => $Param{TicketID}
    );

    # get dynamic field objects
    my $DynamicFieldObject        = $Kernel::OM->Get('DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

    # get all dynamic fields for the object type Ticket
    my $DynamicFieldListTicket = $DynamicFieldObject->DynamicFieldListGet(
        ObjectType => 'Ticket',
        Valid      => 0,
    );

    # delete dynamicfield values for this ticket
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicFieldListTicket} ) {

        next DYNAMICFIELD if !$DynamicFieldConfig;
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELD if !$DynamicFieldConfig->{Name};
        next DYNAMICFIELD if !IsHashRefWithData( $DynamicFieldConfig->{Config} );

        $DynamicFieldBackendObject->ValueDelete(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $Param{TicketID},
            UserID             => $Param{UserID},
            NoPostHandling     => 1,                # we will delete the ticket, so no additional handling needed when deleting the DF values
        );
    }

    # clear ticket cache and general cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID},
        General  => 1,
    );

    # delete ticket links
    $Kernel::OM->Get('LinkObject')->LinkDeleteAll(
        Object => 'Ticket',
        Key    => $Param{TicketID},
        UserID => $Param{UserID},
    );

    # update full text index
    return if !$Self->ArticleIndexDeleteTicket(%Param);

    # update ticket index
    return if !$Self->TicketIndexDelete(%Param);

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # remove ticket watcher
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM watcher WHERE object_id = ?',
        Bind => [ \$Param{TicketID} ],
    );

    # delete ticket flags
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM ticket_flag WHERE ticket_id = ?',
        Bind => [ \$Param{TicketID} ],
    );

    # delete ticket_history
    return if !$Self->HistoryDelete(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
    );

    # delete article, attachments and plain emails
    my @Articles = $Self->ArticleIndex( TicketID => $Param{TicketID} );
    for my $ArticleID (@Articles) {
        return if !$Self->ArticleDelete(
            ArticleID => $ArticleID,
            NoHistory => 1,
            %Param
        );
    }

    # delete accounted time
    my $Success = $Self->TicketAccountedTimeDelete(
        TicketID => $Param{TicketID}
    );

    # trigger event
    my $PreEventResult = $Self->PreEventHandler(
        Event => 'TicketDelete',
        Data  => {
            TicketID => $Param{TicketID},
            OwnerID  => $Ticket{OwnerID},
        },
        UserID => $Param{UserID},
    );
    if ( ( ref($PreEventResult) eq 'HASH' ) && ( $PreEventResult->{Error} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Pre-TicketDelete refused deletion of ticket.",
        );
        return;
    }

    # delete ticket
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM ticket WHERE id = ?',
        Bind => [ \$Param{TicketID} ],
    );

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID},
        General  => 1,
    );

    # trigger event
    $Self->EventHandler(
        Event => 'TicketDelete',
        Data  => {
            TicketID => $Param{TicketID},
            OwnerID  => $Ticket{OwnerID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Ticket',
        ObjectID  => $Param{TicketID},
    );

    return 1;
}

=item TicketIDLookup()

ticket id lookup by ticket number

    my $TicketID = $TicketObject->TicketIDLookup(
        TicketNumber => '2004040510440485',
        UserID       => 123,
    );

=cut

sub TicketIDLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketNumber} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need TicketNumber!'
        );
        return;
    }

    # prepare cache key
    my $CacheKey = 'TicketIDLookup::' . $Param{TicketNumber};

    # check cache
    my $Cached = $Self->_TicketCacheGet(
        Key => $CacheKey,
    );
    return $Cached if ref $Cached;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db query
    return if !$DBObject->Prepare(
        SQL   => 'SELECT id FROM ticket WHERE tn = ?',
        Bind  => [ \$Param{TicketNumber} ],
        Limit => 1,
    );

    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    # set cache
    if ( $ID ) {
        $Self->_TicketCacheSet(
            Key   => $CacheKey,
            Value => $ID,
        );
    }

    return $ID;
}

=item TicketNumberLookup()

ticket number lookup by ticket id

    my $TicketNumber = $TicketObject->TicketNumberLookup(
        TicketID => 123,
        UserID   => 123,
    );

=cut

sub TicketNumberLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need TicketID!'
        );
        return;
    }

    # prepare cache key
    my $CacheKey = 'TicketNumberLookup';

    # check cache
    my $Cached = $Self->_TicketCacheGet(
        TicketID => $Param{TicketID},
        Key      => $CacheKey,
    );
    return $Cached if ref $Cached;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db query
    return if !$DBObject->Prepare(
        SQL   => 'SELECT tn FROM ticket WHERE id = ?',
        Bind  => [ \$Param{TicketID} ],
        Limit => 1,
    );

    my $Number;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Number = $Row[0];
    }

    # set cache
    if ( $Number ) {
        $Self->_TicketCacheSet(
            TicketID => $Param{TicketID},
            Key      => $CacheKey,
            Value    => $Number,
        );
    }

    return $Number;
}

=item TicketSubjectBuild()

rebuild a new ticket subject

This will generate a subject like "RE: [Ticket# 2004040510440485] Some subject"

    my $NewSubject = $TicketObject->TicketSubjectBuild(
        TicketNumber => '2004040510440485',
        Subject      => $OldSubject,
        Action       => 'Reply',
    );

This will generate a subject like  "[Ticket# 2004040510440485] Some subject"
(so without RE: )

    my $NewSubject = $TicketObject->TicketSubjectBuild(
        TicketNumber => '2004040510440485',
        Subject      => $OldSubject,
        Type         => 'New',
        Action       => 'Reply',
    );

This will generate a subject like "FWD: [Ticket# 2004040510440485] Some subject"

    my $NewSubject = $TicketObject->TicketSubjectBuild(
        TicketNumber => '2004040510440485',
        Subject      => $OldSubject,
        Action       => 'Forward', # Possible values are Reply and Forward, Reply is default.
    );

This will generate a subject like "[Ticket# 2004040510440485] Re: Some subject"
(so without clean-up of subject)

    my $NewSubject = $TicketObject->TicketSubjectBuild(
        TicketNumber => '2004040510440485',
        Subject      => $OldSubject,
        Type         => 'New',
        NoCleanup    => 1,
    );

=cut

sub TicketSubjectBuild {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !defined $Param{TicketNumber} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need TicketNumber!"
        );
        return;
    }

    my $Subject = $Param{Subject} || '';

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    my $TicketSubjectFormat = $ConfigObject->Get('Ticket::SubjectFormat') || 'Right';

    if ( lc $TicketSubjectFormat ne 'none') {

        my $Action  = $Param{Action} || 'Reply';

        # cleanup of subject, remove existing ticket numbers and reply indentifier
        if ( !$Param{NoCleanup} ) {
            $Subject = $Self->TicketSubjectClean(%Param);
        }

        # get config options
        my $TicketHook          = $ConfigObject->Get('Ticket::Hook');
        my $TicketHookDivider   = $ConfigObject->Get('Ticket::HookDivider') || '';
        my $TicketSubjectRe     = $ConfigObject->Get('Ticket::SubjectRe');
        my $TicketSubjectFwd    = $ConfigObject->Get('Ticket::SubjectFwd');

        # return subject for new tickets
        if ( $Param{Type} && $Param{Type} eq 'New' ) {
            if ( lc $TicketSubjectFormat eq 'right' ) {
                return $Subject . " [$TicketHook$TicketHookDivider$Param{TicketNumber}]";
            }
            return "[$TicketHook$TicketHookDivider$Param{TicketNumber}] " . $Subject;
        }

        # return subject for existing tickets
        if ( $Action eq 'Forward' ) {
            if ($TicketSubjectFwd) {
                $TicketSubjectFwd .= ': ';
            }
            if ( lc $TicketSubjectFormat eq 'right' ) {
                return $TicketSubjectFwd . $Subject
                    . " [$TicketHook$TicketHookDivider$Param{TicketNumber}]";
            }
            return $TicketSubjectFwd
                . "[$TicketHook$TicketHookDivider$Param{TicketNumber}] "
                . $Subject;
        } else {
            if ($TicketSubjectRe) {
                $TicketSubjectRe .= ': ';
            }
            if ( lc $TicketSubjectFormat eq 'right' ) {
                return $TicketSubjectRe . $Subject
                    . " [$TicketHook$TicketHookDivider$Param{TicketNumber}]";
            }
            return $TicketSubjectRe
                . "[$TicketHook$TicketHookDivider$Param{TicketNumber}] "
                . $Subject;
        }
    }
    return $Subject;
}

=item TicketSubjectClean()

strip/clean up a ticket subject

    my $NewSubject = $TicketObject->TicketSubjectClean(
        TicketNumber => '2004040510440485',
        Subject      => $OldSubject,
        Size         => $SubjectSizeToBeDisplayed   # optional, if 0 do not cut subject
    );

=cut

sub TicketSubjectClean {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !defined $Param{TicketNumber} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need TicketNumber!"
        );
        return;
    }

    my $Subject = $Param{Subject} || '';

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # get config options
    my $TicketHook        = $ConfigObject->Get('Ticket::Hook');
    my $TicketHookDivider = $ConfigObject->Get('Ticket::HookDivider') || '';
    my $TicketSubjectSize = $Param{Size};
    if ( !defined $TicketSubjectSize ) {
        $TicketSubjectSize = $ConfigObject->Get('Ticket::SubjectSize')
            || 120;
    }
    my $TicketSubjectRe  = $ConfigObject->Get('Ticket::SubjectRe');
    my $TicketSubjectFwd = $ConfigObject->Get('Ticket::SubjectFwd');

    # remove all possible ticket hook formats with []
    $Subject =~ s/\[\s*\Q$TicketHook: $Param{TicketNumber}\E\s*\]\s*//g;
    $Subject =~ s/\[\s*\Q$TicketHook:$Param{TicketNumber}\E\s*\]\s*//g;
    $Subject =~ s/\[\s*\Q$TicketHook$Param{TicketNumber}\E\s*\]\s*//g;
    $Subject =~ s/\[\s*\Q$TicketHook$TicketHookDivider$Param{TicketNumber}\E\s*\]\s*//g;

    # remove all ticket numbers with []
    $Subject =~ s/\[\s*\Q$Param{TicketNumber}\E\s*\]\s*//g;

    # remove all possible ticket hook formats without []
    $Subject =~ s/\Q$TicketHook: $Param{TicketNumber}\E(?!\d)\s*//g;
    $Subject =~ s/\Q$TicketHook:$Param{TicketNumber}\E(?!\d)\s*//g;
    $Subject =~ s/\Q$TicketHook$Param{TicketNumber}\E(?!\d)\s*//g;
    $Subject =~ s/\Q$TicketHook$TicketHookDivider$Param{TicketNumber}\E(?!\d)\s*//g;

    # remove all ticket numbers without []
    $Subject =~ s/(?<!\d)\Q$Param{TicketNumber}\E(?!\d)\s*//g;

    # remove leading number with configured "RE:\s" or "RE[\d+]:\s" e. g. "RE: " or "RE[4]: "
    $Subject =~ s/^($TicketSubjectRe(\[\d+\])?:\s?)+//i;

    # remove leading number with configured "Fwd:\s" or "Fwd[\d+]:\s" e. g. "Fwd: " or "Fwd[4]: "
    $Subject =~ s/^($TicketSubjectFwd(\[\d+\])?:\s?)+//i;

    # trim white space at the beginning or end
    $Subject =~ s/(^\s+|\s+$)//;

    # resize subject based on config
    # do not cut subject, if size parameter was 0
    if ($TicketSubjectSize) {
        $Subject =~ s/^(.{$TicketSubjectSize}).*$/$1 [...]/;
    }

    return $Subject;
}

=item TicketGet()

Get ticket info

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => 123,
        DynamicFields => 0,         # Optional, default 0. To include the dynamic field values for this ticket on the return structure.
                                    # Provide an array ref with dynamic field names to only get the specified fields
        UserID        => 123,
        Silent        => 0,         # Optional, default 0. To suppress the warning if the ticket does not exist.
    );

Returns:

    %Ticket = (
        TicketNumber       => '20101027000001',
        Title              => 'some title',
        TicketID           => 123,
        State              => 'some state',
        StateID            => 123,
        StateType          => 'some state type',
        Priority           => 'some priority',
        PriorityID         => 123,
        Lock               => 'lock',
        LockID             => 123,
        Queue              => 'some queue',
        QueueID            => 123,
        OrganisationID     => '123' || 'customer_id_123',
        ContactID          => '123' || 'customer_user_id_123',
        Owner              => 'some_owner_login',
        OwnerID            => 123,
        Type               => 'some ticket type',
        TypeID             => 123,
        Responsible        => 'some_responsible_login',
        ResponsibleID      => 123,
        Age                => 3456,
        PendingTime        => '2010-10-27 20:15:00'      # empty string if PendingTimeUnix == 0
        PendingTimeUnix    => 1231414141
        Created            => '2010-10-27 20:15:00'
        CreateTimeUnix     => 1231414141,
        CreateBy           => 123,
        Changed            => '2010-10-27 20:15:15',
        ChangeBy           => 123,
        ArchiveFlag        => 'y',
        AccountedTime      => 123 || undef               # in minutes

        # If DynamicFields => 1 was passed, you'll get an entry like this for each dynamic field:
        DynamicField_X     => 'value_x',
    );

To get extended ticket attributes, use param Extended:

    my %Ticket = $TicketObject->TicketGet(
        TicketID => 123,
        UserID   => 123,
        Extended => 1,
    );

Additional params are:

    %Ticket = (
        FirstLock                       (timestamp of first lock)
    );

=cut

sub TicketGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need TicketID!'
        );
        return;
    }
    $Param{Extended}      //= 0;
    $Param{DynamicFields} //= 0;

    # prepare cache key
    my $CacheKey = 'TicketGet::' . $Param{Extended} . '::';
    if ( IsArrayRefWithData($Param{DynamicFields}) ) {
        $CacheKey .= join('::', @{$Param{DynamicFields}});
    }
    else {
        $CacheKey .= $Param{DynamicFields};
    }

    # check cache
    my $Cached = $Self->_TicketCacheGet(
        TicketID => $Param{TicketID},
        Key      => $CacheKey,
    );
    return %{$Cached} if ref $Cached eq 'HASH';

    my %Ticket;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare(
        SQL => '
            SELECT st.id, st.queue_id, st.ticket_state_id, st.ticket_lock_id, st.ticket_priority_id,
                st.create_time_unix, st.create_time, st.tn, st.organisation_id, st.contact_id,
                st.user_id, st.responsible_user_id, st.until_time, st.change_time, st.title,
                st.timeout, st.type_id, st.archive_flag,
                st.create_by, st.change_by, accounted_time, attachment_count
            FROM ticket st
            WHERE st.id = ?',
        Bind  => [ \$Param{TicketID} ],
        Limit => 1,
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Ticket{TicketID}        = $Row[0];
        $Ticket{QueueID}         = $Row[1];
        $Ticket{StateID}         = $Row[2];
        $Ticket{LockID}          = $Row[3];
        $Ticket{PriorityID}      = $Row[4];
        $Ticket{CreateTimeUnix}  = $Row[5];
        $Ticket{TicketNumber}    = $Row[7];
        $Ticket{OrganisationID}  = $Row[8];
        $Ticket{ContactID}       = $Row[9];
        $Ticket{OwnerID}         = $Row[10];
        $Ticket{ResponsibleID}   = $Row[11] || 1;
        $Ticket{PendingTimeUnix} = $Row[12];
        $Ticket{Changed}         = $Row[13];
        $Ticket{Title}           = $Row[14];
        $Ticket{UnlockTimeout}   = $Row[15];
        $Ticket{TypeID}          = $Row[16] || 1;
        $Ticket{ArchiveFlag}     = $Row[17] ? 'y' : 'n';
        $Ticket{CreateBy}        = $Row[18];
        $Ticket{ChangeBy}        = $Row[19];
        $Ticket{AccountedTime}   = $Row[20];
        $Ticket{AttachmentCount} = $Row[21] || 0;
    }

    # check ticket
    if ( !$Ticket{TicketID} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No such TicketID ($Param{TicketID})!",
            );
        }
        return;
    }

    # check if need to return DynamicFields
    if ($Param{DynamicFields}) {

        # get dynamic field objects
        my $DynamicFieldObject        = $Kernel::OM->Get('DynamicField');
        my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

        my $FieldFilterRef = undef;
        if ( IsArrayRefWithData($Param{DynamicFields}) ) {
            my %FieldFilter = map { $_ => 1 } @{$Param{DynamicFields}};

            $FieldFilterRef = \%FieldFilter;
        }

        # get all dynamic fields for the object type Ticket (with optional filter)
        my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
            ObjectType => 'Ticket',
            FieldFilter => $FieldFilterRef,
        );

        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {

            # validate each dynamic field
            next DYNAMICFIELD if !$DynamicFieldConfig;
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
            next DYNAMICFIELD if !$DynamicFieldConfig->{Name};

            # get the current value for each dynamic field
            my $Value = $DynamicFieldBackendObject->ValueGet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $Ticket{TicketID},
            );

            # set the dynamic field name and value into the ticket hash
            $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $Value;
        }
    }

    # get time object
    my $TimeObject = $Kernel::OM->Get('Time');

    $Ticket{Created} = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $Ticket{CreateTimeUnix},
    );

    if ($Ticket{PendingTimeUnix} > 0) {
        $Ticket{PendingTime} = $TimeObject->SystemTime2TimeStamp(
            SystemTime => $Ticket{PendingTimeUnix},
        );
    } else {
        $Ticket{PendingTime} = '';
    }

    $Ticket{Queue} = $Kernel::OM->Get('Queue')->QueueLookup(
        QueueID => $Ticket{QueueID},
    );

    # fillup runtime values
    $Ticket{Age} = $TimeObject->SystemTime() - $Ticket{CreateTimeUnix};

    $Ticket{Priority} = $Kernel::OM->Get('Priority')->PriorityLookup(
        PriorityID => $Ticket{PriorityID},
    );

    # get user object
    my $UserObject = $Kernel::OM->Get('User');

    # get owner
    $Ticket{Owner} = $UserObject->UserLookup(
        UserID => $Ticket{OwnerID},
    );

    # get responsible
    $Ticket{Responsible} = $UserObject->UserLookup(
        UserID => $Ticket{ResponsibleID},
    );

    # get lock
    $Ticket{Lock} = $Kernel::OM->Get('Lock')->LockLookup(
        LockID => $Ticket{LockID},
    );

    # get type
    $Ticket{Type} = $Kernel::OM->Get('Type')->TypeLookup( TypeID => $Ticket{TypeID} );

    # get state info
    my %StateData = $Kernel::OM->Get('State')->StateGet(
        ID => $Ticket{StateID}
    );

    $Ticket{StateType} = $StateData{TypeName};
    $Ticket{State}     = $StateData{Name};

    if ( !$Ticket{PendingTimeUnix} || lc $StateData{TypeName} eq 'pending' ) {
        $Ticket{UntilTime} = 0;
    }
    else {
        $Ticket{UntilTime} = $Ticket{PendingTimeUnix} - $TimeObject->SystemTime();
    }

    # do extended lookups
    if ( $Param{Extended} ) {
        my %TicketExtended = $Self->_TicketGetExtended(
            TicketID => $Param{TicketID},
            Ticket   => \%Ticket,
        );
        for my $Key ( sort keys %TicketExtended ) {
            $Ticket{$Key} = $TicketExtended{$Key};
        }
    }

    # set cache
    $Self->_TicketCacheSet(
        TicketID => $Param{TicketID},
        Key      => $CacheKey,
        Value    => \%Ticket,
    );

    return %Ticket;
}

sub _TicketCacheGet {
    my ( $Self, %Param ) = @_;

    # prepare cache type. Add TicketID when given
    my $CacheType = $Self->{CacheType};
    if ( $Param{TicketID} ) {
        $CacheType .= $Param{TicketID}
    }

    # get cache
    return $Kernel::OM->Get('Cache')->Get(
        %Param,
        Type => $CacheType,
    );
}

sub _TicketCacheSet {
    my ( $Self, %Param ) = @_;

    return if $Param{OnlyUpdateMeta};

    # prepare cache type. Add TicketID when given
    my $CacheType = $Self->{CacheType};
    my $Depends   = undef;
    if ( $Param{TicketID} ) {
        $CacheType .= $Param{TicketID};
    }

    # set cache
    return $Kernel::OM->Get('Cache')->Set(
        %Param,
        Type    => $CacheType,
        TTL     => $Self->{CacheTTL},
    );
}

sub _TicketCacheClear {
    my ( $Self, %Param ) = @_;

    # delete specific ticket cache
    if ( $Param{TicketID} ) {
        my $CacheType = $Self->{CacheType} . $Param{TicketID};
        $Kernel::OM->Get('Cache')->CleanUp(
            Type => $CacheType,
        );

        return 1 if ( $Param{OnlyTicket} );
    }

    # cleanup general ticket cache and API
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # cleanup search cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => "ObjectSearch_Ticket",
    );
    # cleanup search cache also for article
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => "ObjectSearch_Article",
    );

    # cleanup index cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => "TicketIndex",
    );

    return 1;
}

sub _TicketGetExtended {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID Ticket)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get extended attributes
    my %FirstResponse   = $Self->_TicketGetFirstResponse(%Param);
    my %FirstLock       = $Self->_TicketGetFirstLock(%Param);
    my %TicketGetClosed = $Self->_TicketGetClosed(%Param);

    # return all as hash
    return ( %TicketGetClosed, %FirstResponse, %FirstLock );
}

sub _TicketGetFirstResponse {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID Ticket)) {
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

    # KIX4OTRS-capeIT
    my $SQL =
        'SELECT a.create_time, a.id FROM article a, article_sender_type ast'
        . ' WHERE a.article_sender_type_id = ast.id AND a.customer_visible = 1 AND'
        . ' a.ticket_id = ? AND ( ';

    my $SQL1 =
        '( ast.name = \'agent\' )';

    my $SQL2 = ') ORDER BY a.create_time';

    # response time set by phone ticket
    my $RespTimeByPhone
        = $Kernel::OM->Get('Config')->Get('Ticket::ResponsetimeSetByPhoneTicket');
    my $RespTimeByPhoneTicketTypeStrg = '';
    if (
        defined $Kernel::OM->Get('Config')
        ->Get('Ticket::ResponsetimeSetByPhoneTicket::OnlyForTheseTicketTypes')
        )
    {
        my @RespTimeByPhoneTicketTypes = @{
            $Kernel::OM->Get('Config')
                ->Get('Ticket::ResponsetimeSetByPhoneTicket::OnlyForTheseTicketTypes')
            };
        $RespTimeByPhoneTicketTypeStrg = join( ",", @RespTimeByPhoneTicketTypes );
    }

    if (
        $RespTimeByPhone &&
        (
            !$RespTimeByPhoneTicketTypeStrg ||
            $RespTimeByPhoneTicketTypeStrg =~ /(^|.*,)$Param{Ticket}->{Type}(,.*|$)/
        )
        )
    {
        $SQL1 .= ' OR ( ast.name = \'customer\' AND a.customer_visible = 1)';
    }

    # response time set by auto reply
    my $RespTimeByAutoReply
        = $Kernel::OM->Get('Config')->Get('Ticket::ResponsetimeSetByAutoReply');
    my $RespTimeByAutoReplyTypeStrg = '';
    if (
        defined $Kernel::OM->Get('Config')
        ->Get('Ticket::ResponsetimeSetByAutoReply::OnlyForTheseTicketTypes')
        )
    {
        my @RespTimeByAutoReplyTypes = @{
            $Kernel::OM->Get('Config')
                ->Get('Ticket::ResponsetimeSetByAutoReply::OnlyForTheseTicketTypes')
            };
        $RespTimeByAutoReplyTypeStrg = join( ",", @RespTimeByAutoReplyTypes );
    }

    if (
        $RespTimeByAutoReply &&
        (
            !$RespTimeByAutoReplyTypeStrg ||
            $RespTimeByAutoReplyTypeStrg =~ /(^|.*,)$Param{Ticket}->{Type}(,.*|$)/
        )
        )
    {
        $SQL1 .= ' OR ( ast.name = \'system\' AND a.customer_visible = 1 )';
    }

    $SQL .= $SQL1 . $SQL2;

    # EO KIX4OTRS-capeIT

    # check if first response is already done
    return if !$DBObject->Prepare(
        SQL => $SQL,
        Bind  => [ \$Param{TicketID} ],
        Limit => 1,
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{FirstResponse} = $Row[0];

        # cleanup time stamps (some databases are using e. g. 2008-02-25 22:03:00.000000
        # and 0000-00-00 00:00:00 time stamps)
        $Data{FirstResponse} =~ s/^(\d\d\d\d-\d\d-\d\d\s\d\d:\d\d:\d\d)\..+?$/$1/;
    }

    return if !$Data{FirstResponse};

    return %Data;
}

sub _TicketGetClosed {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID Ticket)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get close state types
    my @List = $Kernel::OM->Get('State')->StateGetStatesByType(
        StateType => ['closed'],
        Result    => 'ID',
    );
    return if !@List;

    # Get id for history types
    my @HistoryTypeIDs;
    for my $HistoryType (qw(StateUpdate NewTicket)) {
        push @HistoryTypeIDs, $Self->HistoryTypeLookup( Type => $HistoryType );
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare(
        SQL => "
            SELECT MIN(create_time)
            FROM ticket_history
            WHERE ticket_id = ?
               AND state_id IN (${\(join ', ', sort @List)})
               AND history_type_id IN  (${\(join ', ', sort @HistoryTypeIDs)})
            ",
        Bind => [ \$Param{TicketID} ],
    );

    # EO KIX4OTRS-capeIT

    my %Data;
    ROW:
    while ( my @Row = $DBObject->FetchrowArray() ) {
        last ROW if !defined $Row[0];
        $Data{Closed} = $Row[0];

        # cleanup time stamps (some databases are using e. g. 2008-02-25 22:03:00.000000
        # and 0000-00-00 00:00:00 time stamps)
        $Data{Closed} =~ s/^(\d\d\d\d-\d\d-\d\d\s\d\d:\d\d:\d\d)\..+?$/$1/;
    }

    return %Data;
}

sub _TicketGetFirstLock {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID Ticket)) {
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

    # first lock
    return if !$DBObject->Prepare(
        SQL => 'SELECT th.name, tht.name, th.create_time '
            . 'FROM ticket_history th, ticket_history_type tht '
            . 'WHERE th.history_type_id = tht.id AND th.ticket_id = ? '
            . 'AND tht.name = \'Lock\' ORDER BY th.create_time, th.id ASC',
        Bind  => [ \$Param{TicketID} ],
        Limit => 100,
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( !$Data{FirstLock} ) {
            $Data{FirstLock} = $Row[2];

            # cleanup time stamps (some databases are using e. g. 2008-02-25 22:03:00.000000
            # and 0000-00-00 00:00:00 time stamps)
            $Data{FirstLock} =~ s/^(\d\d\d\d-\d\d-\d\d\s\d\d:\d\d:\d\d)\..+?$/$1/;
        }
    }

    return %Data;
}

=item TicketTitleUpdate()

update ticket title

    my $Success = $TicketObject->TicketTitleUpdate(
        Title    => 'Some Title',
        TicketID => 123,
        UserID   => 1,
    );

Events:
    TicketTitleUpdate

=cut

sub TicketTitleUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Title TicketID UserID)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check if update is needed
    my %Ticket = $Self->TicketGet(
        TicketID      => $Param{TicketID},
        UserID        => $Param{UserID},
        DynamicFields => 0,
    );

    return 1 if defined $Ticket{Title} && $Ticket{Title} eq $Param{Title};

    # db access
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE ticket SET title = ?, change_time = current_timestamp, '
            . ' change_by = ? WHERE id = ?',
        Bind => [ \$Param{Title}, \$Param{UserID}, \$Param{TicketID} ],
    );

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID}
    );

    # truncate title
    my $Title = substr( $Param{Title}, 0, 50 );
    $Title .= '...' if length($Title) == 50;

    # history insert
    $Self->HistoryAdd(
        TicketID     => $Param{TicketID},
        HistoryType  => 'TitleUpdate',
        Name         => "\%\%$Ticket{Title}\%\%$Title",
        CreateUserID => $Param{UserID},
    );

    # trigger event
    $Self->EventHandler(
        Event => 'TicketTitleUpdate',
        Data  => {
            TicketID => $Param{TicketID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket',
        ObjectID  => $Param{TicketID},
    );

    return 1;
}

=item TicketUnlockTimeoutUpdate()

set the ticket unlock time to the passed time

    my $Success = $TicketObject->TicketUnlockTimeoutUpdate(
        UnlockTimeout => $TimeObject->SystemTime(),
        TicketID      => 123,
        UserID        => 143,
    );

Events:
    TicketUnlockTimeoutUpdate

=cut

sub TicketUnlockTimeoutUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(UnlockTimeout TicketID UserID)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check if update is needed
    my %Ticket = $Self->TicketGet(
        %Param,
        DynamicFields => 0,
    );

    return 1 if $Ticket{UnlockTimeout} eq $Param{UnlockTimeout};

    # reset unlock time
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE ticket SET timeout = ?, change_time = current_timestamp, '
            . ' change_by = ? WHERE id = ?',
        Bind => [ \$Param{UnlockTimeout}, \$Param{UserID}, \$Param{TicketID} ],
    );

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID}
    );

    # add history
    $Self->HistoryAdd(
        TicketID     => $Param{TicketID},
        CreateUserID => $Param{UserID},
        HistoryType  => 'Misc',
        Name         => Translatable('Reset of unlock time.'),
    );

    # trigger event
    $Self->EventHandler(
        Event => 'TicketUnlockTimeoutUpdate',
        Data  => {
            TicketID => $Param{TicketID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket',
        ObjectID  => $Param{TicketID},
    );

    return 1;
}

=item TicketQueueID()

get ticket queue id

    my $QueueID = $TicketObject->TicketQueueID(
        TicketID => 123,
    );

=cut

sub TicketQueueID {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need TicketID!'
        );
        return;
    }

    # prepare cache key
    my $CacheKey = 'TicketQueueID';

    # check cache
    my $Cached = $Self->_TicketCacheGet(
        TicketID => $Param{TicketID},
        Key      => $CacheKey,
    );
    return $Cached if ref $Cached;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db query
    return if !$DBObject->Prepare(
        SQL   => 'SELECT queue_id FROM ticket WHERE id = ?',
        Bind  => [ \$Param{TicketID} ],
        Limit => 1,
    );

    my $QueueID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $QueueID = $Row[0];
    }

    # set cache
    if ( $QueueID ) {
        $Self->_TicketCacheSet(
            TicketID => $Param{TicketID},
            Key      => $CacheKey,
            Value    => $QueueID,
        );
    }

    return $QueueID;
}

=item TicketQueueSet()

to move a ticket (sends notification to agents of selected my queues, if ticket isn't closed)

    my $Success = $TicketObject->TicketQueueSet(
        QueueID  => 123,
        TicketID => 123,
        UserID   => 123,
    );

    my $Success = $TicketObject->TicketQueueSet(
        Queue    => 'Some Queue Name',
        TicketID => 123,
        UserID   => 123,
    );

    my $Success = $TicketObject->TicketQueueSet(
        Queue    => 'Some Queue Name',
        TicketID => 123,
        Comment  => 'some comment', # optional
        ForceNotificationToUserID => [1,43,56], # if you want to force somebody
        UserID   => 123,
    );

Optional attribute:
SendNoNotification disables or enables agent and customer notification for this
action.

For example:

        SendNoNotification => 0, # optional 1|0 (send no agent and customer notification)

Events:
    TicketQueueUpdate

=cut

sub TicketQueueSet {
    my ( $Self, %Param ) = @_;

    # get queue object
    my $QueueObject = $Kernel::OM->Get('Queue');

    # queue lookup
    if ( $Param{Queue} && !$Param{QueueID} ) {
        $Param{QueueID} = $QueueObject->QueueLookup( Queue => $Param{Queue} );
    }

    # check needed stuff
    for my $Needed (qw(TicketID QueueID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # queue lookup
    my $Queue = $QueueObject->QueueLookup( QueueID => $Param{QueueID} );

    if (!$Queue) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No queue with ID '$Param{QueueID}' exists!"
        );
        return;
    }

    # get current ticket
    my %Ticket = $Self->TicketGet(
        %Param,
        DynamicFields => 0,
    );

    # move needed?
    if ( $Param{QueueID} == $Ticket{QueueID} && !$Param{Comment} ) {

        # update not needed
        return 1;
    }

    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE ticket SET queue_id = ?, change_time = current_timestamp, '
            . ' change_by = ? WHERE id = ?',
        Bind => [ \$Param{QueueID}, \$Param{UserID}, \$Param{TicketID} ],
    );

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID}
    );

    # history insert
    $Self->HistoryAdd(
        TicketID     => $Param{TicketID},
        QueueID      => $Param{QueueID},
        HistoryType  => 'Move',
        Name         => "\%\%$Queue\%\%$Param{QueueID}\%\%$Ticket{Queue}\%\%$Ticket{QueueID}",
        CreateUserID => $Param{UserID},
    );

    # send move notify to queue subscriber
    if ( !$Param{SendNoNotification} && $Ticket{StateType} ne 'closed' ) {

        my @UserIDs;

        if ( $Param{ForceNotificationToUserID} ) {
            push @UserIDs, @{ $Param{ForceNotificationToUserID} };
        }

        # trigger notification event
        $Self->EventHandler(
            Event => 'NotificationMove',
            Data  => {
                TicketID              => $Param{TicketID},
                CustomerMessageParams => {
                    Queue => $Queue,
                },
                Recipients => \@UserIDs,
            },
            UserID => $Param{UserID},
        );
    }

    # trigger event, OldTicketData is needed for escalation events
    $Self->EventHandler(
        Event => 'TicketQueueUpdate',
        Data  => {
            TicketID      => $Param{TicketID},
            OldTicketData => \%Ticket,
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket.Queue',
        ObjectID  => $Param{TicketID}.'::'.$Ticket{QueueID}.'::'.$Param{QueueID},
    );

    return 1;
}

=item TicketMoveQueueList()

returns a list of used queue ids / names

    my @QueueIDList = $TicketObject->TicketMoveQueueList(
        TicketID => 123,
        Type     => 'ID',
    );

Returns:

    @QueueIDList = ( 1, 2, 3 );

    my @QueueList = $TicketObject->TicketMoveQueueList(
        TicketID => 123,
        Type     => 'Name',
    );

Returns:

    @QueueList = ( 'QueueA', 'QueueB', 'QueueC' );

=cut

sub TicketMoveQueueList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need TicketID!"
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db query
    return if !$DBObject->Prepare(
        SQL => 'SELECT sh.name, ht.name, sh.create_by, sh.queue_id FROM '
            . 'ticket_history sh, ticket_history_type ht WHERE '
            . 'sh.ticket_id = ? AND ht.name IN (\'Move\', \'NewTicket\') AND '
            . 'ht.id = sh.history_type_id ORDER BY sh.id',
        Bind => [ \$Param{TicketID} ],
    );

    my @QueueID;
    while ( my @Row = $DBObject->FetchrowArray() ) {

        # store result
        if ( $Row[1] eq 'NewTicket' ) {
            if ( $Row[3] ) {
                push @QueueID, $Row[3];
            }
        }
        elsif ( $Row[1] eq 'Move' ) {
            if ( $Row[0] =~ /^\%\%(.+?)\%\%(.+?)\%\%(.+?)\%\%(.+?)/ ) {
                push @QueueID, $2;
            }
            elsif ( $Row[0] =~ /^Ticket moved to Queue '.+?' \(ID=(.+?)\)/ ) {
                push @QueueID, $1;
            }
        }
    }

    # get queue object
    my $QueueObject = $Kernel::OM->Get('Queue');

    # queue lookup
    my @QueueName;
    for my $QueueID (@QueueID) {

        my $Queue = $QueueObject->QueueLookup( QueueID => $QueueID );

        push @QueueName, $Queue;
    }

    if ( $Param{Type} && $Param{Type} eq 'Name' ) {
        return @QueueName;
    }
    else {
        return @QueueID;
    }
}

=item TicketTypeList()

to get all possible types for a ticket (depends on workflow, if configured)

    my %Types = $TicketObject->TicketTypeList(
        UserID => 123,
    );

    my %Types = $TicketObject->TicketTypeList(
        ContactID => 'customer_user_id_123',
    );

    my %Types = $TicketObject->TicketTypeList(
        QueueID => 123,
        UserID  => 123,
    );

    my %Types = $TicketObject->TicketTypeList(
        TicketID => 123,
        UserID   => 123,
    );

Returns:

    %Types = (
        1 => 'default',
        2 => 'request',
        3 => 'offer',
    );

=cut

sub TicketTypeList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} && !$Param{ContactID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID or ContactID!'
        );
        return;
    }

    my %Types = $Kernel::OM->Get('Type')->TypeList( Valid => 1 );

    return %Types;
}

=item TicketTypeSet()

to set a ticket type

    my $Success = $TicketObject->TicketTypeSet(
        TypeID   => 123,
        TicketID => 123,
        UserID   => 123,
    );

    my $Success = $TicketObject->TicketTypeSet(
        Type     => 'normal',
        TicketID => 123,
        UserID   => 123,
    );

Events:
    TicketTypeUpdate

=cut

sub TicketTypeSet {
    my ( $Self, %Param ) = @_;

    # type lookup
    if ( $Param{Type} && !$Param{TypeID} ) {
        $Param{TypeID} = $Kernel::OM->Get('Type')->TypeLookup( Type => $Param{Type} );
    }

    # check needed stuff
    for my $Needed (qw(TicketID TypeID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get current ticket
    my %Ticket = $Self->TicketGet(
        %Param,
        DynamicFields => 0,
    );

    # update needed?
    return 1 if $Param{TypeID} == $Ticket{TypeID};

    # permission check
    my %TypeList = $Self->TicketTypeList(%Param);
    if ( !$TypeList{ $Param{TypeID} } ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "Permission denied on TicketID: $Param{TicketID}!",
        );
        return;
    }

    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE ticket SET type_id = ?, change_time = current_timestamp, '
            . ' change_by = ? WHERE id = ?',
        Bind => [ \$Param{TypeID}, \$Param{UserID}, \$Param{TicketID} ],
    );

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID}
    );

    # get new ticket data
    my %TicketNew = $Self->TicketGet(
        %Param,
        DynamicFields => 0,
    );
    $TicketNew{Type} = $TicketNew{Type} || 'NULL';
    $Param{TypeID}   = $Param{TypeID}   || '';
    $Ticket{Type}    = $Ticket{Type}    || 'NULL';
    $Ticket{TypeID}  = $Ticket{TypeID}  || '';

    # history insert
    $Self->HistoryAdd(
        TicketID     => $Param{TicketID},
        HistoryType  => 'TypeUpdate',
        Name         => "\%\%$TicketNew{Type}\%\%$Param{TypeID}\%\%$Ticket{Type}\%\%$Ticket{TypeID}",
        CreateUserID => $Param{UserID},
    );

    # trigger event
    $Self->EventHandler(
        Event => 'TicketTypeUpdate',
        Data  => {
            TicketID => $Param{TicketID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket.Type',
        ObjectID  => $Param{TicketID}.'::'.$Ticket{TypeID}.'::'.$Param{TypeID},
    );

    return 1;
}

=item TicketCustomerSet()

Set customer data of ticket. Can set 'OrganisationID' or 'Contact' or both.

    my $Success = $TicketObject->TicketCustomerSet(
        TicketID       => 123,
        OrganisationID => '123' || 'client123',
        ContactID      => '123' || 'client-user-123',
        UserID         => 23,
    );

Events:
    TicketCustomerUpdate
    TicketOrganisationUpdate
    TicketContactUpdate

=cut

sub TicketCustomerSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }
    if ( !defined $Param{OrganisationID} && !defined $Param{ContactID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ContactID or OrganisationID for update!'
        );
        return;
    }

    my %Ticket = $Self->TicketGet(
        TicketID      => $Param{TicketID},
        UserID        => $Param{UserID},
        DynamicFields => 0,
    );
    return 1 if !%Ticket;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db organisation id update
    if ( defined $Param{OrganisationID} ) {

        my $Ok;
        if ( $Param{OrganisationID} eq '' ) {
            $Ok = $DBObject->Do(
                SQL => 'UPDATE ticket SET organisation_id = null, '
                    . ' change_time = current_timestamp, change_by = ? WHERE id = ?',
                Bind => [ \$Param{UserID}, \$Param{TicketID} ]
            );
        } else {
            $Ok = $DBObject->Do(
                SQL => 'UPDATE ticket SET organisation_id = ?, '
                    . ' change_time = current_timestamp, change_by = ? WHERE id = ?',
                Bind => [ \$Param{OrganisationID}, \$Param{UserID}, \$Param{TicketID} ]
            );
        }

        if ($Ok) {
            $Param{History} = "OrganisationID=$Param{OrganisationID};";
        }
    }

    # db contact update
    if ( defined $Param{ContactID} ) {
        my $Ok;

         if ( $Param{ContactID} eq '' ) {
            $Ok = $DBObject->Do(
                SQL => 'UPDATE ticket SET contact_id = null, '
                    . 'change_time = current_timestamp, change_by = ? WHERE id = ?',
                Bind => [ \$Param{UserID}, \$Param{TicketID} ],
            );
         } else {
            $Ok = $DBObject->Do(
                SQL => 'UPDATE ticket SET contact_id = ?, '
                    . 'change_time = current_timestamp, change_by = ? WHERE id = ?',
                Bind => [ \$Param{ContactID}, \$Param{UserID}, \$Param{TicketID} ],
            );
         }

        if ($Ok) {
            $Param{History} .= "ContactID=$Param{ContactID};";
        }
    }

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID}
    );

    # trigger events
    $Self->EventHandler(
        Event => 'TicketCustomerUpdate',
        Data  => {
            TicketID => $Param{TicketID},
        },
        UserID => $Param{UserID},
    );
    if ( defined $Param{OrganisationID} ) {
        $Self->EventHandler(
            Event => 'TicketOrganisationUpdate',
            Data  => {
                TicketID => $Param{TicketID},
            },
            UserID => $Param{UserID},
        );

        # push client callback event
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
            Event     => 'UPDATE',
            Namespace => 'Ticket.Organisation',
            ObjectID  => $Param{TicketID}.'::'.$Ticket{OrganisationID}.'::'.$Param{OrganisationID},
        );
    }
    if ( defined $Param{ContactID} ) {
        $Self->EventHandler(
            Event => 'TicketContactUpdate',
            Data  => {
                TicketID => $Param{TicketID},
            },
            UserID => $Param{UserID},
        );

        # push client callback event
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
            Event     => 'UPDATE',
            Namespace => 'Ticket.Contact',
            ObjectID  => $Param{TicketID}.'::'.$Ticket{ContactID}.'::'.$Param{ContactID},
        );
    }

    # if no change
    if ( !$Param{History} ) {
        return;
    }

    # history insert
    $Self->HistoryAdd(
        TicketID     => $Param{TicketID},
        HistoryType  => 'CustomerUpdate',
        Name         => "\%\%" . $Param{History},
        CreateUserID => $Param{UserID},
    );

    return 1;
}

=item GetSubscribedUserIDsByQueueID()

returns an array of user ids which selected the given queue id as
custom queue.

    my @UserIDs = $TicketObject->GetSubscribedUserIDsByQueueID(
        QueueID => 123,
    );

Returns:

    @UserIDs = ( 1, 2, 3 );

=cut

sub GetSubscribedUserIDsByQueueID {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{QueueID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need QueueID!'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # fetch all queues
    my @UserIDs;
    return if !$DBObject->Prepare(
        SQL => "SELECT distinct(user_id) FROM user_preferences WHERE preferences_key = 'MyQueues' AND preferences_value = ?",
        Bind => [ \$Param{QueueID} ],
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @UserIDs, $Row[0];
    }

    # get user object
    my $UserObject = $Kernel::OM->Get('User');

    # check if user is valid
    my @CleanUserIDs;
    USER:
    for my $UserID (@UserIDs) {

        my %User = $UserObject->GetUserData(
            UserID => $UserID,
            Valid  => 1,
        );

        next USER if !%User;

        push @CleanUserIDs, $UserID;
    }

    return @CleanUserIDs;
}

=item GetSubscribedUserIDsByServiceID()

returns an array of user ids which selected the given service id as
custom service.

    my @UserIDs = $TicketObject->GetSubscribedUserIDsByServiceID(
        ServiceID => 123,
    );

Returns:

    @UserIDs = ( 1, 2, 3 );

=cut

sub GetSubscribedUserIDsByServiceID {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ServiceID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ServiceID!'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # fetch all users
    my @UserIDs;
    return if !$DBObject->Prepare(
        SQL => "SELECT distinct(user_id) FROM user_preferences WHERE preferences_key = 'MyServices' AND preferences_value = ?",
        Bind => [ \$Param{ServiceID} ],
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @UserIDs, $Row[0];
    }

    # get user object
    my $UserObject = $Kernel::OM->Get('User');

    # check if user is valid
    my @CleanUserIDs;
    USER:
    for my $UserID (@UserIDs) {

        my %User = $UserObject->GetUserData(
            UserID => $UserID,
            Valid  => 1,
        );

        next USER if !%User;

        push @CleanUserIDs, $UserID;
    }

    return @CleanUserIDs;
}

=item TicketPendingTimeSet()

set ticket pending time:

    my $Success = $TicketObject->TicketPendingTimeSet(
        Year     => 2003,
        Month    => 08,
        Day      => 14,
        Hour     => 22,
        Minute   => 05,
        TicketID => 123,
        UserID   => 23,
    );

or use a time stamp:

    my $Success = $TicketObject->TicketPendingTimeSet(
        String   => '2003-08-14 22:05:00',
        TicketID => 123,
        UserID   => 23,
    );

or use a diff (set pending time to "now" + diff minutes)

    my $Success = $TicketObject->TicketPendingTimeSet(
        Diff     => ( 7 * 24 * 60 ),  # minutes (here: 10080 minutes - 7 days)
        TicketID => 123,
        UserID   => 23,
    );

If you want to set the pending time to null, just supply zeros:

    my $Success = $TicketObject->TicketPendingTimeSet(
        Year     => 0000,
        Month    => 00,
        Day      => 00,
        Hour     => 00,
        Minute   => 00,
        TicketID => 123,
        UserID   => 23,
    );

or use a time stamp:

    my $Success = $TicketObject->TicketPendingTimeSet(
        String   => '0000-00-00 00:00:00',
        TicketID => 123,
        UserID   => 23,
    );

or use a diff with zero:

    my $Success = $TicketObject->TicketPendingTimeSet(
        Diff     => 0,
        TicketID => 123,
        UserID   => 23,
    );

Events:
    TicketPendingTimeUpdate

=cut

sub TicketPendingTimeSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{String} && !defined $Param{Diff} ) {
        for my $Needed (qw(Year Month Day Hour Minute TicketID UserID)) {
            if ( !defined $Param{$Needed} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
                return;
            }
        }
    }
    elsif (
        !$Param{String} &&
        !( $Param{Year} && $Param{Month} && $Param{Day} && $Param{Hour} && $Param{Minute} )
        )
    {
        for my $Needed (qw(Diff TicketID UserID)) {
            if ( !defined $Param{$Needed} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
                return;
            }
        }
    }
    else {
        for my $Needed (qw(String TicketID UserID)) {
            if ( !defined $Param{$Needed} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
                return;
            }
        }
    }

    # check if we need to null the PendingTime
    my $PendingTimeNull;
    if (
        ($Param{String} && $Param{String} eq '0000-00-00 00:00:00') ||
        (defined $Param{Diff} && $Param{Diff} == 0)
    ) {
        $PendingTimeNull = 1;
        $Param{Sec}      = 0;
        $Param{Minute}   = 0;
        $Param{Hour}     = 0;
        $Param{Day}      = 0;
        $Param{Month}    = 0;
        $Param{Year}     = 0;
    }
    elsif (
        !$Param{String}
        && !$Param{Diff}
        && $Param{Minute} == 0
        && $Param{Hour} == 0 && $Param{Day} == 0
        && $Param{Month} == 0
        && $Param{Year} == 0
        )
    {
        $PendingTimeNull = 1;
    }

    # get system time from string/params
    my $Time = 0;
    if ( !$PendingTimeNull ) {

        # get time object
        my $TimeObject = $Kernel::OM->Get('Time');

        if ( $Param{String} ) {
            $Time = $TimeObject->TimeStamp2SystemTime(
                String => $Param{String},
            );
            if ( $Time ) {
                ( $Param{Sec}, $Param{Minute}, $Param{Hour}, $Param{Day}, $Param{Month}, $Param{Year} ) = $TimeObject->SystemTime2Date(
                    SystemTime => $Time,
                );
            }
        }
        elsif ( $Param{Diff} ) {
            $Time = $TimeObject->SystemTime() + ( $Param{Diff} * 60 );
            ( $Param{Sec}, $Param{Minute}, $Param{Hour}, $Param{Day}, $Param{Month}, $Param{Year} ) =
                $TimeObject->SystemTime2Date(
                SystemTime => $Time,
                );
        }
        else {
            $Time = $TimeObject->TimeStamp2SystemTime(
                String => "$Param{Year}-$Param{Month}-$Param{Day} $Param{Hour}:$Param{Minute}:00",
            );
        }

        # return if no convert is possible
        return if !$Time;
    }

    # check if update is needed
    my %Ticket = $Self->TicketGet(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
        DynamicFields => 0,
    );
    return 1 if $Ticket{PendingTimeUnix} eq $Time;

    # db update
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE ticket SET until_time = ?, change_time = current_timestamp, change_by = ?'
            . ' WHERE id = ?',
        Bind => [ \$Time, \$Param{UserID}, \$Param{TicketID} ],
    );

    # history insert
    $Self->HistoryAdd(
        TicketID    => $Param{TicketID},
        HistoryType => 'SetPendingTime',
        Name        => '%%'
            . sprintf( "%02d", $Param{Year} ) . '-'
            . sprintf( "%02d", $Param{Month} ) . '-'
            . sprintf( "%02d", $Param{Day} ) . ' '
            . sprintf( "%02d", $Param{Hour} ) . ':'
            . sprintf( "%02d", $Param{Minute} ) . '',
        CreateUserID => $Param{UserID},
    );

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID}
    );

    # trigger event
    $Self->EventHandler(
        Event => 'TicketPendingTimeUpdate',
        Data  => {
            TicketID => $Param{TicketID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket.PendingTime',
        ObjectID  => $Param{TicketID},
    );

    return 1;
}

=item TicketLockGet()

check if a ticket is locked or not

    if ($TicketObject->TicketLockGet(TicketID => 123)) {
        print "Ticket is locked!\n";
    }
    else {
        print "Ticket is not locked!\n";
    }

=cut

sub TicketLockGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need TicketID!'
        );
        return;
    }

    my %Ticket = $Self->TicketGet(
        %Param,
        DynamicFields => 0,
    );

    # check lock state
    return 1 if lc $Ticket{Lock} eq 'lock';

    return;
}

=item TicketLockSet()

to lock or unlock a ticket

    my $Success = $TicketObject->TicketLockSet(
        Lock     => 'lock',
        TicketID => 123,
        UserID   => 123,
    );

    my $Success = $TicketObject->TicketLockSet(
        LockID   => 1,
        TicketID => 123,
        UserID   => 123,
    );

Optional attribute:
SendNoNotification, disable or enable agent and customer notification for this
action. Otherwise a notification will be sent to agent and cusomer.

For example:

        SendNoNotification => 0, # optional 1|0 (send no agent and customer notification)

Events:
    TicketLockUpdate

=cut

sub TicketLockSet {
    my ( $Self, %Param ) = @_;

    # lookup!
    if ( !$Param{LockID} && $Param{Lock} ) {

        $Param{LockID} = $Kernel::OM->Get('Lock')->LockLookup(
            Lock => $Param{Lock},
        );
    }
    if ( $Param{LockID} && !$Param{Lock} ) {

        $Param{Lock} = $Kernel::OM->Get('Lock')->LockLookup(
            LockID => $Param{LockID},
        );
    }

    # check needed stuff
    for my $Needed (qw(TicketID UserID LockID Lock)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }
    if ( !$Param{Lock} && !$Param{LockID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need LockID or Lock!'
        );
        return;
    }

    # check if update is needed
    my %Ticket = $Self->TicketGet(
        %Param,
        DynamicFields => 0,
    );
    return 1 if $Ticket{Lock} eq $Param{Lock};

    # tickets can't be locked for OwnerID = 1
    if ( $Ticket{OwnerID} == 1 && $Param{Lock} eq 'lock' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => 'Tickets can\'t be locked for OwnerID 1.'
        );
        return;
    }

    # db update
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE ticket SET ticket_lock_id = ?, '
            . ' change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [ \$Param{LockID}, \$Param{UserID}, \$Param{TicketID} ],
    );

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID}
    );

    # add history
    my $HistoryType = '';
    if ( lc $Param{Lock} eq 'unlock' ) {
        $HistoryType = 'Unlock';
    }
    elsif ( lc $Param{Lock} eq 'lock' ) {
        $HistoryType = 'Lock';
    }
    else {
        $HistoryType = 'Misc';
    }
    if ($HistoryType) {
        $Self->HistoryAdd(
            TicketID     => $Param{TicketID},
            CreateUserID => $Param{UserID},
            HistoryType  => $HistoryType,
            Name         => "\%\%$Param{Lock}",
        );
    }

    # set unlock time it event is 'lock'
    if ( $Param{Lock} eq 'lock' ) {

        # get time object
        my $TimeObject = $Kernel::OM->Get('Time');

        $Self->TicketUnlockTimeoutUpdate(
            UnlockTimeout => $TimeObject->SystemTime(),
            TicketID      => $Param{TicketID},
            UserID        => $Param{UserID},
        );
    }

    # send unlock notify
    if ( lc $Param{Lock} eq 'unlock' ) {

        my $Notification = defined $Param{Notification} ? $Param{Notification} : 1;
        if ( !$Param{SendNoNotification} && $Notification )
        {
            my @SkipRecipients;
            if ( $Ticket{OwnerID} eq $Param{UserID} ) {
                @SkipRecipients = [ $Param{UserID} ];
            }

            # trigger notification event
            $Self->EventHandler(
                Event          => 'NotificationLockTimeout',
                SkipRecipients => \@SkipRecipients,
                Data           => {
                    TicketID              => $Param{TicketID},
                    CustomerMessageParams => {},
                },
                UserID => $Param{UserID},
            );
        }
    }

    # trigger event
    $Self->EventHandler(
        Event => 'TicketLockUpdate',
        Data  => {
            TicketID => $Param{TicketID},
            Lock     => lc $Param{Lock},
            OwnerID  => $Ticket{OwnerID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket.Lock',
        ObjectID  => $Param{TicketID}.'::'.(lc $Param{Lock}).'::'.$Param{UserID},
    );

    return 1;
}

=item TicketArchiveFlagSet()

to set the ticket archive flag

    my $Success = $TicketObject->TicketArchiveFlagSet(
        ArchiveFlag => 'y',  # (y|n)
        TicketID    => 123,
        UserID      => 123,
    );

Events:
    TicketArchiveFlagUpdate

=cut

sub TicketArchiveFlagSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID ArchiveFlag)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # return if feature is not enabled
    return if !$ConfigObject->Get('Ticket::ArchiveSystem');

    # check given archive flag
    if ( $Param{ArchiveFlag} ne 'y' && $Param{ArchiveFlag} ne 'n' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "ArchiveFlag is invalid '$Param{ArchiveFlag}'!",
        );
        return;
    }

    # check if update is needed
    my %Ticket = $Self->TicketGet(
        %Param,
        DynamicFields => 0,
    );

    # return if no update is needed
    return 1 if $Ticket{ArchiveFlag} && $Ticket{ArchiveFlag} eq $Param{ArchiveFlag};

    # translate archive flag
    my $ArchiveFlag = $Param{ArchiveFlag} eq 'y' ? 1 : 0;

    # set new archive flag
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => '
            UPDATE ticket
            SET archive_flag = ?, change_time = current_timestamp, change_by = ?
            WHERE id = ?',
        Bind => [ \$ArchiveFlag, \$Param{UserID}, \$Param{TicketID} ],
    );

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID}
    );

    # Remove seen flags from ticket and article and ticket watcher data if configured
    #   and if the ticket flag was just set.
    if ($ArchiveFlag) {

        if ( $ConfigObject->Get('Ticket::ArchiveSystem::RemoveSeenFlags') ) {
            $Self->TicketFlagDelete(
                TicketID => $Param{TicketID},
                Key      => 'Seen',
                AllUsers => 1,
            );

            for my $ArticleID ( $Self->ArticleIndex( TicketID => $Param{TicketID} ) ) {
                $Self->ArticleFlagDelete(
                    ArticleID => $ArticleID,
                    Key       => 'Seen',
                    AllUsers  => 1,
                );
            }
        }

        if (
            $ConfigObject->Get('Ticket::ArchiveSystem::RemoveTicketWatchers')
        ) {
            $Kernel::OM->Get('Watcher')->WatcherDelete(
                Object   => 'Ticket',
                ObjectID => $Param{TicketID},
                AllUsers => 1,
                UserID   => $Param{UserID},
            );
        }
    }

    # add history
    $Self->HistoryAdd(
        TicketID     => $Param{TicketID},
        CreateUserID => $Param{UserID},
        HistoryType  => 'ArchiveFlagUpdate',
        Name         => "\%\%$Param{ArchiveFlag}",
    );

    # trigger event
    $Self->EventHandler(
        Event => 'TicketArchiveFlagUpdate',
        Data  => {
            TicketID => $Param{TicketID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket',
        ObjectID  => $Param{TicketID},
    );

    return 1;
}

=item TicketStateSet()

to set a ticket state

    my $Success = $TicketObject->TicketStateSet(
        State     => 'open',
        TicketID  => 123,
        ArticleID => 123, #optional, for history
        UserID    => 123,
    );

    my $Success = $TicketObject->TicketStateSet(
        StateID  => 3,
        TicketID => 123,
        UserID   => 123,
    );

Optional attribute:
SendNoNotification, disable or enable agent and customer notification for this
action. Otherwise a notification will be sent to agent and cusomer.

For example:

        SendNoNotification => 0, # optional 1|0 (send no agent and customer notification)

Events:
    TicketStateUpdate

=cut

sub TicketStateSet {
    my ( $Self, %Param ) = @_;

    my %State;
    my $ArticleID = $Param{ArticleID} || '';

    # check needed stuff
    for my $Needed (qw(TicketID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }
    if ( !$Param{State} && !$Param{StateID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need StateID or State!'
        );
        return;
    }

    # get state object
    my $StateObject = $Kernel::OM->Get('State');

    # KIX4OTRS-capeIT
    # get previous state if state placeholder is used
    if ( $Param{State} && $Param{State} eq '_PREVIOUS_' ) {
        $Param{State} = $Self->GetPreviousTicketState(
            TicketID => $Param{TicketID},
        );
    }

    my %Ticket = $Self->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    # use fallback if previous state could not be replaced
    if ( defined( $Param{State} ) && ( $Param{State} eq '0' || $Param{State} eq '_PREVIOUS_' ) )
    {
        my $FallbackStates =
            $Kernel::OM->Get('Config')->Get('TicketStateWorkflow::FallbackForPreviousState')
            || 0;
        my $FallbackStatesExtended
            = $Kernel::OM->Get('Config')->Get('TicketStateWorkflowExtension::FallbackForPreviousState');
        if ( defined $FallbackStatesExtended && ref $FallbackStatesExtended eq 'HASH' ) {
            for my $Extension ( sort keys %{$FallbackStatesExtended} ) {
                for my $Type ( keys %{ $FallbackStatesExtended->{$Extension} } ) {
                    $FallbackStates->{$Type} = $FallbackStatesExtended->{$Extension}->{$Type};
                }
            }
        }

        if ( $FallbackStates && ref($FallbackStates) eq 'HASH' ) {
            $Param{State} =
                $FallbackStates->{ $Ticket{Type} . ':::' . $Ticket{State} }
                || $FallbackStates->{ $Ticket{Type} }
                || '_PREVIOUS_';
        }
    }

    # EO KIX4OTRS-capeIT

    # state id lookup
    if ( !$Param{StateID} ) {
        %State = $StateObject->StateGet( Name => $Param{State} );
    }

    # state lookup
    if ( !$Param{State} ) {
        %State = $StateObject->StateGet( ID => $Param{StateID} );
    }
    if ( !%State ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need StateID or State!'
        );
        return;
    }

    # check if update is needed
    # KIX4OTRS-capeIT
    # moved content upwards
    # my %Ticket = $Self->TicketGet( TicketID => $Param{TicketID} );
    # EO KIX4OTRS-capeIT

    if ( $State{Name} eq $Ticket{State} ) {

        # update is not needed
        # KIX4OTRS-capeIT
        # return 1;
        return $State{ID};

        # EO KIX4OTRS-capeIT
    }

    # permission check
    my %StateList = $Self->TicketStateList(%Param);
    if ( !$StateList{ $State{ID} } ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "Permission denied on TicketID: $Param{TicketID} / StateID: $State{ID}!",
        );
        return;
    }

    # db update
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE ticket SET ticket_state_id = ?, '
            . ' change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [ \$State{ID}, \$Param{UserID}, \$Param{TicketID} ],
    );

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID}
    );

    # add history
    $Self->HistoryAdd(
        TicketID     => $Param{TicketID},
        ArticleID    => $ArticleID,
        QueueID      => $Ticket{QueueID},
        Name         => "\%\%$Ticket{State}\%\%$State{Name}\%\%",
        HistoryType  => 'StateUpdate',
        CreateUserID => $Param{UserID},
    );

    # trigger event, OldTicketData is needed for escalation events
    $Self->EventHandler(
        Event => 'TicketStateUpdate',
        Data  => {
            TicketID      => $Param{TicketID},
            State         => \%State,
            OldTicketData => \%Ticket,
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket.State',
        ObjectID  => $Param{TicketID}.'::'.$Ticket{StateID}.'::'.$State{ID},
    );

    # KIX4OTRS-capeIT
    # return 1;
    return $State{ID};

    # EO KIX4OTRS-capeIT
}

=item TicketStateList()

to get the state list for a ticket (depends on workflow, if configured)

    my %States = $TicketObject->TicketStateList(
        TicketID => 123,
        UserID   => 123,
    );

    my %States = $TicketObject->TicketStateList(
        TicketID       => 123,
        ContactID => 'customer_user_id_123',
    );

    my %States = $TicketObject->TicketStateList(
        QueueID => 123,
        UserID  => 123,
    );

    my %States = $TicketObject->TicketStateList(
        TicketID => 123,
        Type     => 'open',
        UserID   => 123,
    );

Returns:

    %States = (
        1 => 'State A',
        2 => 'State B',
        3 => 'State C',
    );

=cut

sub TicketStateList {
    my ( $Self, %Param ) = @_;

    my %States;

    # check needed stuff
    if ( !$Param{UserID} && !$Param{ContactID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID or ContactID!'
        );
        return;
    }

    # check needed stuff
    if ( !$Param{QueueID} && !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need QueueID, TicketID!'
        );
        return;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # get state object
    my $StateObject = $Kernel::OM->Get('State');

    # get states by type
    if ( $Param{Type} ) {
        %States = $StateObject->StateGetStatesByType(
            Type   => $Param{Type},
            Result => 'HASH',
        );
    }
    elsif ( $Param{Action} ) {

        if (
            ref $ConfigObject->Get("Ticket::Frontend::$Param{Action}")->{StateType} ne
            'ARRAY'
            )
        {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need config for Ticket::Frontend::$Param{Action}->StateType!"
            );
            return;
        }

        my @StateType = @{ $ConfigObject->Get("Ticket::Frontend::$Param{Action}")->{StateType} };
        %States = $StateObject->StateGetStatesByType(
            StateType => \@StateType,
            Result    => 'HASH',
        );
    }

    # get whole states list
    else {
        %States = $StateObject->StateList(
            UserID => $Param{UserID},
        );
    }

    return %States;
}

=item OwnerCheck()

to get the ticket owner

    my ($OwnerID, $Owner) = $TicketObject->OwnerCheck(
        TicketID => 123,
    );

or for access control

    my $AccessOk = $TicketObject->OwnerCheck(
        TicketID => 123,
        OwnerID  => 321,
    );

=cut

sub OwnerCheck {
    my ( $Self, %Param ) = @_;

    my $SQL = '';

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need TicketID!'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db query
    if ( $Param{OwnerID} ) {

        # create cache key
        my $CacheKey = $Param{TicketID} . '::' . $Param{OwnerID};

        # check cache
        if ( defined $Self->{OwnerCheck}->{$CacheKey} ) {
            return   if !$Self->{OwnerCheck}->{$CacheKey};
            return 1 if $Self->{OwnerCheck}->{$CacheKey};
        }

        # check if user has access
        return if !$DBObject->Prepare(
            SQL => 'SELECT user_id FROM ticket WHERE '
                . ' id = ? AND (user_id = ? OR responsible_user_id = ?)',
            Bind => [ \$Param{TicketID}, \$Param{OwnerID}, \$Param{OwnerID}, ],
        );
        my $Access = 0;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $Access = 1;
        }

        # fill cache
        $Self->{OwnerCheck}->{$CacheKey} = $Access;
        return   if !$Access;
        return 1 if $Access;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # search for owner_id and owner
    return if !$DBObject->Prepare(
        SQL => "SELECT st.user_id, su.login"
            . " FROM ticket st, users su "
            . " WHERE st.id = ? AND "
            . " st.user_id = su.id",
        Bind => [ \$Param{TicketID}, ],
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Param{SearchUserID} = $Row[0];
        $Param{SearchUser}   = $Row[1];
    }

    # return if no owner as been found
    return if !$Param{SearchUserID};

    # return owner id and owner
    return $Param{SearchUserID}, $Param{SearchUser};
}

=item TicketOwnerSet()

to set the ticket owner (notification to the new owner will be sent)

by using user id

    my $Success = $TicketObject->TicketOwnerSet(
        TicketID  => 123,
        NewUserID => 555,
        UserID    => 123,
    );

by using user login

    my $Success = $TicketObject->TicketOwnerSet(
        TicketID => 123,
        NewUser  => 'some-user-login',
        UserID   => 123,
    );

Return:
    1 = owner has been set
    2 = this owner is already set, no update needed

Optional attribute:
SendNoNotification, disable or enable agent and customer notification for this
action. Otherwise a notification will be sent to agent and cusomer.

For example:

        SendNoNotification => 0, # optional 1|0 (send no agent and customer notification)

Events:
    TicketOwnerUpdate

=cut

sub TicketOwnerSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }
    if ( !$Param{NewUserID} && !$Param{NewUser} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need NewUserID or NewUser!'
        );
        return;
    }

    # get user object
    my $UserObject = $Kernel::OM->Get('User');

    # lookup if no NewUserID is given
    if ( !$Param{NewUserID} ) {
        $Param{NewUserID} = $UserObject->UserLookup(
            UserLogin => $Param{NewUser},
        );
    }

    # lookup if no NewUser is given
    if ( !$Param{NewUser} ) {
        $Param{NewUser} = $UserObject->UserLookup(
            UserID => $Param{NewUserID},
        );
    }

    # make sure the user exists
    if ( !$UserObject->UserLookup( UserID => $Param{NewUserID} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "User does not exist.",
        );
        return;
    }

    # check if update is needed!
    my ( $OwnerID, $Owner ) = $Self->OwnerCheck( TicketID => $Param{TicketID} );
    if ( $OwnerID eq $Param{NewUserID} ) {

        # update is "not" needed!
        return 2;
    }

    # db update
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE ticket SET '
            . ' user_id = ?, change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [ \$Param{NewUserID}, \$Param{UserID}, \$Param{TicketID} ],
    );

    # tickets have to be unlocked if OwnerID = 1
    if ( $Param{NewUserID} == 1 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => 'Unlocking ticket '.$Param{TicketID}.' because OwnerID 1 has been set.'
        );
        $Self->TicketLockSet(
            TicketID => $Param{TicketID},
            Lock     => 'unlock',
            UserID   => 1,
        );
    }

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID}
    );

    # add history
    $Self->HistoryAdd(
        TicketID     => $Param{TicketID},
        CreateUserID => $Param{UserID},
        HistoryType  => 'OwnerUpdate',
        Name         => "\%\%$Param{NewUser}\%\%$Param{NewUserID}",
    );

    # send agent notify
    if ( !$Param{SendNoNotification} ) {

        my @SkipRecipients;
        if ( $Param{UserID} eq $Param{NewUserID} ) {
            @SkipRecipients = [ $Param{UserID} ];
        }

        # trigger notification event
        $Self->EventHandler(
            Event => 'NotificationOwnerUpdate',
            Data  => {
                TicketID              => $Param{TicketID},
                SkipRecipients        => \@SkipRecipients,
                CustomerMessageParams => {
                    %Param,
                    Body => $Param{Comment} || '',
                },
            },
            UserID => $Param{UserID},
        );
    }

    # trigger event
    $Self->EventHandler(
        Event => 'TicketOwnerUpdate',
        Data  => {
            TicketID        => $Param{TicketID},
            OwnerID         => $Param{NewUserID},
            PreviousOwnerID => $OwnerID,
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket.Owner',
        ObjectID  => $Param{TicketID}.'::'.$OwnerID.'::'.$Param{NewUserID},
    );

    return 1;
}

=item TicketOwnerList()

returns the owner in the past as array with hash ref of the owner data
(name, email, ...)

    my @Owner = $TicketObject->TicketOwnerList(
        TicketID => 123,
    );

Returns:

    @Owner = (
        {
            UserLogin => 'SomeName',
            # custom attributes
        },
        {
            UserLogin => 'SomeName',
            # custom attributes
        },
    );

=cut

sub TicketOwnerList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need TicketID!"
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db query
    return if !$DBObject->Prepare(
        SQL => 'SELECT sh.owner_id FROM ticket_history sh, ticket_history_type ht WHERE '
            . ' sh.ticket_id = ? AND ht.name IN (\'OwnerUpdate\', \'NewTicket\') AND '
            . ' ht.id = sh.history_type_id ORDER BY sh.id',
        Bind => [ \$Param{TicketID} ],
    );
    my @UserID;

    USER:
    while ( my @Row = $DBObject->FetchrowArray() ) {
        next USER if !$Row[0];
        next USER if $Row[0] eq 1;
        push @UserID, $Row[0];
    }

    # get user object
    my $UserObject = $Kernel::OM->Get('User');

    my @UserInfo;
    USER:
    for my $UserID (@UserID) {

        my %User = $UserObject->GetUserData(
            UserID => $UserID,
            Cache  => 1,
            Valid  => 1,
        );

        next USER if !%User;

        push @UserInfo, \%User;
    }

    return @UserInfo;
}

=item TicketResponsibleSet()

to set the ticket responsible (notification to the new responsible will be sent)

by using user id

    my $Success = $TicketObject->TicketResponsibleSet(
        TicketID  => 123,
        NewUserID => 555,
        UserID    => 213,
    );

by using user login

    my $Success = $TicketObject->TicketResponsibleSet(
        TicketID  => 123,
        NewUser   => 'some-user-login',
        UserID    => 213,
    );

Return:
    1 = responsible has been set
    2 = this responsible is already set, no update needed

Optional attribute:
SendNoNotification, disable or enable agent and customer notification for this
action. Otherwise a notification will be sent to agent and cusomer.

For example:

        SendNoNotification => 0, # optional 1|0 (send no agent and customer notification)

Events:
    TicketResponsibleUpdate

=cut

sub TicketResponsibleSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }
    if ( !$Param{NewUserID} && !$Param{NewUser} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need NewUserID or NewUser!'
        );
        return;
    }

    # get user object
    my $UserObject = $Kernel::OM->Get('User');

    # lookup if no NewUserID is given
    if ( !$Param{NewUserID} ) {
        $Param{NewUserID} = $UserObject->UserLookup( UserLogin => $Param{NewUser} );
    }

    # lookup if no NewUser is given
    if ( !$Param{NewUser} ) {
        $Param{NewUser} = $UserObject->UserLookup( UserID => $Param{NewUserID} );
    }

    # make sure the user exists
    if ( !$UserObject->UserLookup( UserID => $Param{NewUserID} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "User does not exist.",
        );
        return;
    }

    # check if update is needed!
    my %Ticket = $Self->TicketGet(
        TicketID      => $Param{TicketID},
        UserID        => $Param{NewUserID},
        DynamicFields => 0,
    );
    if ( $Ticket{ResponsibleID} eq $Param{NewUserID} ) {

        # update is "not" needed!
        return 2;
    }

    # db update
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE ticket SET responsible_user_id = ?, '
            . ' change_time = current_timestamp, change_by = ? '
            . ' WHERE id = ?',
        Bind => [ \$Param{NewUserID}, \$Param{UserID}, \$Param{TicketID} ],
    );

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID}
    );

    # add history
    $Self->HistoryAdd(
        TicketID     => $Param{TicketID},
        CreateUserID => $Param{UserID},
        HistoryType  => 'ResponsibleUpdate',
        Name         => "\%\%$Param{NewUser}\%\%$Param{NewUserID}",
    );

    # send agent notify
    if ( !$Param{SendNoNotification} ) {

        my @SkipRecipients;
        if ( $Param{UserID} eq $Param{NewUserID} ) {
            @SkipRecipients = [ $Param{UserID} ];
        }

        # trigger notification event
        $Self->EventHandler(
            Event => 'NotificationResponsibleUpdate',
            Data  => {
                TicketID              => $Param{TicketID},
                SkipRecipients        => \@SkipRecipients,
                CustomerMessageParams => \%Param,
            },
            UserID => $Param{UserID},
        );
    }

    # trigger event
    $Self->EventHandler(
        Event => 'TicketResponsibleUpdate',
        Data  => {
            TicketID => $Param{TicketID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket.Responsible',
        ObjectID  => $Param{TicketID}.'::'.$Ticket{ResponsibleID}.'::'.$Param{NewUserID},
    );

    return 1;
}

=item TicketResponsibleList()

returns the responsible in the past as array with hash ref of the owner data
(name, email, ...)

    my @Responsible = $TicketObject->TicketResponsibleList(
        TicketID => 123,
    );

Returns:

    @Responsible = (
        {
            UserLogin => 'someName',
            # custom attributes
        },
        {
            UserLogin => 'someName',
            # custom attributes
        },
    );

=cut

sub TicketResponsibleList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need TicketID!"
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db query
    my @User;
    my $LastResponsible = 1;
    return if !$DBObject->Prepare(
        SQL => 'SELECT sh.name, ht.name, sh.create_by FROM '
            . ' ticket_history sh, ticket_history_type ht WHERE '
            . ' sh.ticket_id = ? AND '
            . ' ht.name IN (\'ResponsibleUpdate\', \'NewTicket\') AND '
            . ' ht.id = sh.history_type_id ORDER BY sh.id',
        Bind => [ \$Param{TicketID} ],
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {

        # store result
        if ( $Row[1] eq 'NewTicket' && $Row[2] ne '1' && $LastResponsible ne $Row[2] ) {
            $LastResponsible = $Row[2];
            push @User, $Row[2];
        }
        elsif ( $Row[1] eq 'ResponsibleUpdate' ) {
            if (
                $Row[0] =~ /^New Responsible is '(.+?)' \(ID=(.+?)\)/
                || $Row[0] =~ /^\%\%(.+?)\%\%(.+?)$/
                )
            {
                $LastResponsible = $2;
                push @User, $2;
            }
        }
    }

    # get user object
    my $UserObject = $Kernel::OM->Get('User');

    my @UserInfo;
    for my $SingleUser (@User) {

        my %User = $UserObject->GetUserData(
            UserID => $SingleUser,
            Cache  => 1
        );
        push @UserInfo, \%User;
    }

    return @UserInfo;
}

=item TicketInvolvedAgentsList()

returns an array with hash ref of agents which have been involved with a ticket.
It is guaranteed that no agent is returned twice.

    my @InvolvedAgents = $TicketObject->TicketInvolvedAgentsList(
        TicketID => 123,
    );

Returns:

    @InvolvedAgents = (
        {
            UserLogin => 'someName',
            # custom attributes
        },
        {
            UserLogin => 'someName',
            # custom attributes
        },
    );

=cut

sub TicketInvolvedAgentsList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need TicketID!'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db query, only entries with a known history_id are retrieved
    my @User;
    my %UsedOwner;
    return if !$DBObject->Prepare(
        SQL => ''
            . 'SELECT sh.create_by'
            . ' FROM ticket_history sh, ticket_history_type ht'
            . ' WHERE sh.ticket_id = ?'
            . ' AND ht.id = sh.history_type_id'
            . ' ORDER BY sh.id',
        Bind => [ \$Param{TicketID} ],
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {

        # store result, skip the
        if ( $Row[0] ne 1 && !$UsedOwner{ $Row[0] } ) {
            $UsedOwner{ $Row[0] } = $Row[0];
            push @User, $Row[0];
        }
    }

    # get user object
    my $UserObject = $Kernel::OM->Get('User');

    # collect agent information
    my @UserInfo;
    USER:
    for my $SingleUser (@User) {

        my %User = $UserObject->GetUserData(
            UserID => $SingleUser,
            Valid  => 1,
            Cache  => 1,
        );

        next USER if !%User;

        push @UserInfo, \%User;
    }

    return @UserInfo;
}

=item TicketPrioritySet()

to set the ticket priority

    my $Success = $TicketObject->TicketPrioritySet(
        TicketID => 123,
        Priority => 'low',
        UserID   => 213,
    );

    my $Success = $TicketObject->TicketPrioritySet(
        TicketID   => 123,
        PriorityID => 2,
        UserID     => 213,
    );

Events:
    TicketPriorityUpdate

=cut

sub TicketPrioritySet {
    my ( $Self, %Param ) = @_;

    # get priority object
    my $PriorityObject = $Kernel::OM->Get('Priority');

    # lookup!
    if ( !$Param{PriorityID} && $Param{Priority} ) {
        $Param{PriorityID} = $PriorityObject->PriorityLookup(
            Priority => $Param{Priority},
        );
    }
    if ( $Param{PriorityID} && !$Param{Priority} ) {
        $Param{Priority} = $PriorityObject->PriorityLookup(
            PriorityID => $Param{PriorityID},
        );
    }

    # check needed stuff
    for my $Needed (qw(TicketID UserID PriorityID Priority)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my %Ticket = $Self->TicketGet(
        %Param,
        DynamicFields => 0,
    );

    # check if update is needed
    if ( $Ticket{Priority} eq $Param{Priority} ) {

        # update not needed
        return 1;
    }

    # permission check
    my %PriorityList = $Self->TicketPriorityList(%Param);
    if ( !$PriorityList{ $Param{PriorityID} } ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "Permission denied on TicketID: $Param{TicketID}!",
        );
        return;
    }

    # db update
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE ticket SET ticket_priority_id = ?, '
            . ' change_time = current_timestamp, change_by = ?'
            . ' WHERE id = ?',
        Bind => [ \$Param{PriorityID}, \$Param{UserID}, \$Param{TicketID} ],
    );

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID}
    );

    # add history
    $Self->HistoryAdd(
        TicketID     => $Param{TicketID},
        QueueID      => $Ticket{QueueID},
        CreateUserID => $Param{UserID},
        HistoryType  => 'PriorityUpdate',
        Name         => "\%\%$Ticket{Priority}\%\%$Ticket{PriorityID}"
            . "\%\%$Param{Priority}\%\%$Param{PriorityID}",
    );

    # trigger event
    $Self->EventHandler(
        Event => 'TicketPriorityUpdate',
        Data  => {
            TicketID => $Param{TicketID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket.Priority',
        ObjectID  => $Param{TicketID}.'::'.$Ticket{PriorityID}.'::'.$Param{PriorityID},
    );

    return 1;
}

=item TicketPriorityList()

to get the priority list for a ticket (depends on workflow, if configured)

    my %Priorities = $TicketObject->TicketPriorityList(
        TicketID => 123,
        UserID   => 123,
    );

    my %Priorities = $TicketObject->TicketPriorityList(
        TicketID       => 123,
        ContactID => 'customer_user_id_123',
    );

    my %Priorities = $TicketObject->TicketPriorityList(
        QueueID => 123,
        UserID  => 123,
    );

Returns:

    %Priorities = (
        1 => 'Priority A',
        2 => 'Priority B',
        3 => 'Priority C',
    );

=cut

sub TicketPriorityList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} && !$Param{ContactID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID or ContactID!'
        );
        return;
    }

    my %Data = $Kernel::OM->Get('Priority')->PriorityList(%Param);

    return %Data;
}

=item HistoryTicketStatusGet()

get a hash with ticket id as key and a hash ref (result of HistoryTicketGet)
of all affected tickets in this time area.

    my %Tickets = $TicketObject->HistoryTicketStatusGet(
        StartDay   => 12,
        StartMonth => 1,
        StartYear  => 2006,
        StopDay    => 18,
        StopMonth  => 1,
        StopYear   => 2006,
        Force      => 0,
    );

=cut

sub HistoryTicketStatusGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(StopYear StopMonth StopDay StartYear StartMonth StartDay)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # format month and day params
    for my $DateParameter (qw(StopMonth StopDay StartMonth StartDay)) {
        $Param{$DateParameter} = sprintf( "%02d", $Param{$DateParameter} );
    }

    my $SQLExt = '';
    for my $HistoryTypeData (
        qw(NewTicket FollowUp OwnerUpdate PriorityUpdate CustomerUpdate StateUpdate
        Forward Bounce SendAnswer EmailCustomer TicketDynamicFieldUpdate)
        )
    {
        my $ID = $Self->HistoryTypeLookup( Type => $HistoryTypeData );
        if ( !$SQLExt ) {
            $SQLExt = "AND history_type_id IN ($ID";
        }
        else {
            $SQLExt .= ",$ID";
        }
    }

    if ($SQLExt) {
        $SQLExt .= ')';
    }

    # assemble stop date/time string for database comparison
    my $TimeObject = $Kernel::OM->Get('Time');
    my $StopSystemTime
        = $TimeObject->TimeStamp2SystemTime( String => "$Param{StopYear}-$Param{StopMonth}-$Param{StopDay} 00:00:00" );
    my ( $StopSec, $StopMin, $StopHour, $StopDay, $StopMonth, $StopYear, $StopWDay )
        = $TimeObject->SystemTime2Date( SystemTime => $StopSystemTime + 24 * 60 * 60 );    # add a day

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare(
        SQL => "
            SELECT DISTINCT(th.ticket_id), th.create_time
            FROM ticket_history th
            WHERE th.create_time < '$StopYear-$StopMonth-$StopDay 00:00:00'
                AND th.create_time >= '$Param{StartYear}-$Param{StartMonth}-$Param{StartDay} 00:00:00'
                $SQLExt
            ORDER BY th.create_time DESC",
        Limit => 150000,
    );

    my %Ticket;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Ticket{ $Row[0] } = 1;
    }

    for my $TicketID ( sort keys %Ticket ) {

        my %TicketData = $Self->HistoryTicketGet(
            TicketID  => $TicketID,
            StopYear  => $Param{StopYear},
            StopMonth => $Param{StopMonth},
            StopDay   => $Param{StopDay},
            Force     => $Param{Force} || 0,
        );

        if (%TicketData) {
            $Ticket{$TicketID} = \%TicketData;
        }
        else {
            $Ticket{$TicketID} = {};
        }
    }

    return %Ticket;
}

=item HistoryTicketGet()

returns a hash of some of the ticket data
calculated based on ticket history info at the given date.

    my %HistoryData = $TicketObject->HistoryTicketGet(
        StopYear   => 2003,
        StopMonth  => 12,
        StopDay    => 24,
        StopHour   => 10, (optional, default 23)
        StopMinute => 0,  (optional, default 59)
        StopSecond => 0,  (optional, default 59)
        TicketID   => 123,
        Force      => 0,     # 1: don't use cache
    );

returns

    TicketNumber
    TicketID
    Type
    TypeID
    Queue
    QueueID
    Priority
    PriorityID
    State
    StateID
    Owner
    OwnerID
    CreateUserID
    CreateTime (timestamp)
    CreateOwnerID
    CreatePriority
    CreatePriorityID
    CreateState
    CreateStateID
    CreateQueue
    CreateQueueID
    LockFirst (timestamp)
    LockLast (timestamp)
    UnlockFirst (timestamp)
    UnlockLast (timestamp)

=cut

sub HistoryTicketGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID StopYear StopMonth StopDay)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }
    $Param{StopHour}   = defined $Param{StopHour}   ? $Param{StopHour}   : '23';
    $Param{StopMinute} = defined $Param{StopMinute} ? $Param{StopMinute} : '59';
    $Param{StopSecond} = defined $Param{StopSecond} ? $Param{StopSecond} : '59';

    # format month and day params
    for my $DateParameter (qw(StopMonth StopDay)) {
        $Param{$DateParameter} = sprintf( "%02d", $Param{$DateParameter} );
    }

    # prepare cache key
    my $CacheKey = 'HistoryTicketGet::'
        . join( '::', map { ( $_ || 0 ) . "::$Param{$_}" } sort keys %Param );

    # check cache
    my $Cached = $Self->_TicketCacheGet(
        TicketID => $Param{TicketID},
        Key      => $CacheKey,
    );
    if ( ref $Cached eq 'HASH' && !$Param{Force} ) {
        return %{$Cached};
    }

    my $Time
        = "$Param{StopYear}-$Param{StopMonth}-$Param{StopDay} $Param{StopHour}:$Param{StopMinute}:$Param{StopSecond}";

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare(
        SQL => '
            SELECT th.name, tht.name, th.create_time, th.create_by, th.ticket_id,
                th.article_id, th.queue_id, th.state_id, th.priority_id, th.owner_id, th.type_id
            FROM ticket_history th, ticket_history_type tht
            WHERE th.history_type_id = tht.id
                AND th.ticket_id = ?
                AND th.create_time <= ?
            ORDER BY th.create_time, th.id ASC',
        Bind  => [ \$Param{TicketID}, \$Time ],
        Limit => 3000,
    );

    my %Ticket;
    while ( my @Row = $DBObject->FetchrowArray() ) {

        if ( $Row[1] eq 'NewTicket' ) {
            if (
                $Row[0] =~ /^\%\%(.+?)\%\%(.+?)\%\%(.+?)\%\%(.+?)\%\%(.+?)$/
                || $Row[0] =~ /Ticket=\[(.+?)\],.+?Q\=(.+?);P\=(.+?);S\=(.+?)/
                )
            {
                $Ticket{TicketNumber}   = $1;
                $Ticket{Queue}          = $2;
                $Ticket{CreateQueue}    = $2;
                $Ticket{Priority}       = $3;
                $Ticket{CreatePriority} = $3;
                $Ticket{State}          = $4;
                $Ticket{CreateState}    = $4;
                $Ticket{TicketID}       = $Row[4];
                $Ticket{Owner}          = 'root';
                $Ticket{CreateUserID}   = $Row[3];
                $Ticket{CreateTime}     = $Row[2];
            }
            else {

                # COMPAT: compat to 1.1
                # NewTicket
                $Ticket{TicketVersion} = '1.1';
                $Ticket{TicketID}      = $Row[4];
                $Ticket{CreateUserID}  = $Row[3];
                $Ticket{CreateTime}    = $Row[2];
            }
            $Ticket{CreateOwnerID}    = $Row[9] || '';
            $Ticket{CreatePriorityID} = $Row[8] || '';
            $Ticket{CreateStateID}    = $Row[7] || '';
            $Ticket{CreateQueueID}    = $Row[6] || '';
        }

        # COMPAT: compat to 1.1
        elsif ( $Row[1] eq 'PhoneCallCustomer' ) {
            $Ticket{TicketVersion} = '1.1';
            $Ticket{TicketID}      = $Row[4];
            $Ticket{CreateUserID}  = $Row[3];
            $Ticket{CreateTime}    = $Row[2];
        }
        elsif ( $Row[1] eq 'Move' ) {
            if (
                $Row[0] =~ /^\%\%(.+?)\%\%(.+?)\%\%(.+?)\%\%(.+?)/
                || $Row[0] =~ /^Ticket moved to Queue '(.+?)'/
                )
            {
                $Ticket{Queue} = $1;
            }
        }
        elsif (
            $Row[1] eq 'StateUpdate'
            || $Row[1] eq 'Close'
            || $Row[1] eq 'Open'
            || $Row[1] eq 'Misc'
            )
        {
            if (
                $Row[0] =~ /^\%\%(.+?)\%\%(.+?)(\%\%|)$/
                || $Row[0] =~ /^Old: '(.+?)' New: '(.+?)'/
                || $Row[0] =~ /^Changed Ticket State from '(.+?)' to '(.+?)'/
                )
            {
                $Ticket{State}     = $2;
                $Ticket{StateTime} = $Row[2];
            }
        }
        elsif ( $Row[1] eq 'TicketFreeTextUpdate' ) {
            if ( $Row[0] =~ /^\%\%(.+?)\%\%(.+?)\%\%(.+?)\%\%(.+?)$/ ) {
                $Ticket{ 'Ticket' . $1 } = $2;
                $Ticket{ 'Ticket' . $3 } = $4;
                $Ticket{$1}              = $2;
                $Ticket{$3}              = $4;
            }
        }
        elsif ( $Row[1] eq 'TicketDynamicFieldUpdate' ) {

            # take care about different values between 3.3 and 4
            # 3.x: %%FieldName%%test%%Value%%TestValue1
            # 4.x: %%FieldName%%test%%Value%%TestValue1%%OldValue%%OldTestValue1
            if ( $Row[0] =~ /^\%\%FieldName\%\%(.+?)\%\%Value\%\%(.*?)(?:\%\%|$)/ ) {

                my $FieldName = $1;
                my $Value = $2 || '';
                $Ticket{$FieldName} = $Value;

                # Backward compatibility for TicketFreeText and TicketFreeTime
                if ( $FieldName =~ /^Ticket(Free(?:Text|Key)(?:[?:1[0-6]|[1-9]))$/ ) {

                    # Remove the leading Ticket on field name
                    my $FreeFieldName = $1;
                    $Ticket{$FreeFieldName} = $Value;
                }
            }
        }
        elsif ( $Row[1] eq 'PriorityUpdate' ) {
            if ( $Row[0] =~ /^\%\%(.+?)\%\%(.+?)\%\%(.+?)\%\%(.+?)/ ) {
                $Ticket{Priority} = $3;
            }
        }
        elsif ( $Row[1] eq 'OwnerUpdate' ) {
            if ( $Row[0] =~ /^\%\%(.+?)\%\%(.+?)/ || $Row[0] =~ /^New Owner is '(.+?)'/ ) {
                $Ticket{Owner} = $1;
            }
        }
        elsif ( $Row[1] eq 'Lock' ) {
            if ( !$Ticket{LockFirst} ) {
                $Ticket{LockFirst} = $Row[2];
            }
            $Ticket{LockLast} = $Row[2];
        }
        elsif ( $Row[1] eq 'Unlock' ) {
            if ( !$Ticket{UnlockFirst} ) {
                $Ticket{UnlockFirst} = $Row[2];
            }
            $Ticket{UnlockLast} = $Row[2];
        }

        # get default options
        $Ticket{TypeID}     = $Row[10] || '';
        $Ticket{OwnerID}    = $Row[9]  || '';
        $Ticket{PriorityID} = $Row[8]  || '';
        $Ticket{StateID}    = $Row[7]  || '';
        $Ticket{QueueID}    = $Row[6]  || '';
    }
    if ( !%Ticket ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "No such TicketID in ticket history till "
                . "'$Param{StopYear}-$Param{StopMonth}-$Param{StopDay} $Param{StopHour}:$Param{StopMinute}:$Param{StopSecond}' ($Param{TicketID})!",
        );
        return;
    }

    # update old ticket info
    my %CurrentTicketData = $Self->TicketGet(
        TicketID      => $Ticket{TicketID},
        DynamicFields => 0,
    );
    for my $TicketAttribute (qw(State Priority Queue TicketNumber)) {
        if ( !$Ticket{$TicketAttribute} ) {
            $Ticket{$TicketAttribute} = $CurrentTicketData{$TicketAttribute};
        }
        if ( !$Ticket{"Create$TicketAttribute"} ) {
            $Ticket{"Create$TicketAttribute"} = $CurrentTicketData{$TicketAttribute};
        }
    }

    # get time object
    my $TimeObject = $Kernel::OM->Get('Time');

    # check if we should cache this ticket data
    my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WDay ) = $TimeObject->SystemTime2Date(
        SystemTime => $TimeObject->SystemTime(),
    );

    # set cache, when the request is for the last month or older
    if ( "$Year-$Month" gt "$Param{StopYear}-$Param{StopMonth}" ) {
        $Self->_TicketCacheSet(
            TicketID => $Param{TicketID},
            Key      => $CacheKey,
            Value    => \%Ticket,
        );
    }

    return %Ticket;
}

=item HistoryTypeLookup()

returns the id of the requested history type or the name of the type if id is given.

    my $Type = $TicketObject->HistoryTypeLookup( TypeID => 123 );

    my $ID = $TicketObject->HistoryTypeLookup( Type => 'Move' );

=cut

sub HistoryTypeLookup {
    my ( $Self, %Param ) = @_;
    my $Result;

    # check needed stuff
    if ( !$Param{Type} && !$Param{TypeID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need TypeID or Type!'
        );
        return;
    }

    # prepare cache key
    my $CacheKey = 'Ticket::History::HistoryTypeLookup::' . ($Param{Type} || $Param{TypeID});

    # check cache
    my $Cached   = $Self->_TicketCacheGet(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    if ($Cached) {
        return $Cached;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    if ( $Param{Type} ) {
        # db query
        return if !$DBObject->Prepare(
            SQL  => 'SELECT id FROM ticket_history_type WHERE name = ?',
            Bind => [ \$Param{Type} ],
        );

        while ( my @Row = $DBObject->FetchrowArray() ) {
            $Result = $Row[0];
        }

        # check if data exists
        if ( !$Result ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No TypeID for $Param{Type} found!",
                );
            }
            return;
        }
    }
    elsif ( $Param{TypeID} ) {
        # db query
        return if !$DBObject->Prepare(
            SQL  => 'SELECT name FROM ticket_history_type WHERE id = ?',
            Bind => [ \$Param{TypeID} ],
        );

        while ( my @Row = $DBObject->FetchrowArray() ) {
            $Result = $Row[0];
        }

        # check if data exists
        if ( !$Result ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No Type for $Param{TypeID} found!",
                );
            }
            return;
        }
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => $Result,
    );

    return $Result;
}

=item HistoryAdd()

add a history entry to an ticket

    my $Success = $TicketObject->HistoryAdd(
        Name         => 'Some Comment',
        HistoryType  => 'Move', # see system tables
        TicketID     => 123,
        ArticleID    => 1234, # not required!
        QueueID      => 123, # not required!
        TypeID       => 123, # not required!
        CreateUserID => 123,
    );

Events:
    HistoryAdd

=cut

sub HistoryAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name!'
        );
        return;
    }

    # lookup!
    if ( !$Param{HistoryTypeID} && $Param{HistoryType} ) {
        $Param{HistoryTypeID} = $Self->HistoryTypeLookup( Type => $Param{HistoryType} );
    }

    # check needed stuff
    for my $Needed (qw(TicketID CreateUserID HistoryTypeID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get QueueID
    if ( !$Param{QueueID} ) {
        $Param{QueueID} = $Self->TicketQueueID( TicketID => $Param{TicketID} );
    }

    # get type
    if ( !$Param{TypeID} ) {
        my %Ticket = $Self->TicketGet(
            %Param,
            DynamicFields => 0,
        );
        $Param{TypeID} = $Ticket{TypeID};
    }

    # get owner
    if ( !$Param{OwnerID} ) {
        my %Ticket = $Self->TicketGet(
            %Param,
            DynamicFields => 0,
        );
        $Param{OwnerID} = $Ticket{OwnerID};
    }

    # get priority
    if ( !$Param{PriorityID} ) {
        my %Ticket = $Self->TicketGet(
            %Param,
            DynamicFields => 0,
        );
        $Param{PriorityID} = $Ticket{PriorityID};
    }

    # get state
    if ( !$Param{StateID} ) {
        my %Ticket = $Self->TicketGet(
            %Param,
            DynamicFields => 0,
        );
        $Param{StateID} = $Ticket{StateID};
    }

    # limit name to 200 chars
    if ( $Param{Name} ) {
        $Param{Name} = substr( $Param{Name}, 0, 200 );
    }

    # db quote
    if ( !$Param{ArticleID} ) {
        $Param{ArticleID} = undef;
    }

    # db insert
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'INSERT INTO ticket_history '
            . ' (name, history_type_id, ticket_id, article_id, queue_id, owner_id, '
            . ' priority_id, state_id, type_id, '
            . ' create_time, create_by, change_time, change_by) '
            . 'VALUES '
            . '(?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name},    \$Param{HistoryTypeID}, \$Param{TicketID},   \$Param{ArticleID},
            \$Param{QueueID}, \$Param{OwnerID},       \$Param{PriorityID}, \$Param{StateID},
            \$Param{TypeID},  \$Param{CreateUserID},  \$Param{CreateUserID},
        ],
    );

    # trigger event
    $Self->EventHandler(
        Event => 'HistoryAdd',
        Data  => {
            TicketID => $Param{TicketID},
        },
        UserID => $Param{CreateUserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Ticket.History',
        ObjectID  => $Param{TicketID}.'::'.$Param{HistoryTypeID}.'::'.$Param{CreateUserID},
    );

    return 1;
}

=item HistoryGet()

get ticket history as array with hashes
(TicketID, ArticleID, Name, CreateBy, CreateTime, HistoryType, QueueID,
OwnerID, PriorityID, StateID, HistoryTypeID and TypeID)

    my @HistoryLines = $TicketObject->HistoryGet(
        TicketID      => 123,
        HistoryType   => '...',           # optional
        Name          => '...',           # optional
        MinCreateTime => '...',           # optional
        SortReverse   => 1,               # optional
        Limit         => 1,               # optional
        UserID        => 123,
    );

=cut

sub HistoryGet {
    my ( $Self, %Param ) = @_;

    my @Lines;

    # check needed stuff
    for my $Needed (qw(TicketID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    my @BindArray = (
        \$Param{TicketID}
    );
    my $SQL = 'SELECT sh.name, sh.article_id, sh.create_time, sh.create_by, ht.name, '
            . ' sh.queue_id, sh.owner_id, sh.priority_id, sh.state_id, sh.history_type_id, sh.type_id, sh.id '
            . ' FROM ticket_history sh, ticket_history_type ht WHERE '
            . ' sh.ticket_id = ? AND ht.id = sh.history_type_id';

    if ( $Param{HistoryType} ) {
        $SQL .= ' AND ht.name = ?';
        push @BindArray, \$Param{HistoryType};
    }

    if ( $Param{Name} ) {
        $SQL .= ' AND sh.name = ?';
        push @BindArray, \$Param{Name};
    }

    if ( $Param{MinCreateTime} ) {
        $SQL .= ' AND sh.create_time >= ?';
        push @BindArray, \$Param{MinCreateTime};
    }

    $SQL .= ' ORDER BY sh.create_time, sh.id';
    if ( $Param{SortReverse} ) {
        $SQL .= ' DESC'
    }

    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@BindArray,
        Limit => $Param{Limit}
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        my %Data;
        $Data{HistoryID}     = $Row[11];
        $Data{TicketID}      = $Param{TicketID};
        $Data{ArticleID}     = $Row[1] || 0;
        $Data{Name}          = $Row[0];
        $Data{CreateBy}      = $Row[3];
        $Data{CreateTime}    = $Row[2];
        $Data{HistoryType}   = $Row[4];
        $Data{QueueID}       = $Row[5];
        $Data{OwnerID}       = $Row[6];
        $Data{PriorityID}    = $Row[7];
        $Data{StateID}       = $Row[8];
        $Data{HistoryTypeID} = $Row[9];
        $Data{TypeID}        = $Row[10];
        push @Lines, \%Data;
    }

    return @Lines;
}

=item HistoryDelete()

delete a ticket history (from storage)

    my $Success = $TicketObject->HistoryDelete(
        TicketID => 123,
        UserID   => 123,
    );

Events:
    HistoryDelete

=cut

sub HistoryDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # delete ticket history entries from db
    return if !$Kernel::OM->Get('DB')->Do(
        SQL =>
            'DELETE FROM ticket_history WHERE ticket_id = ? AND (article_id IS NULL OR article_id = 0)',
        Bind => [ \$Param{TicketID} ],
    );

    # trigger event
    $Self->EventHandler(
        Event => 'HistoryDelete',
        Data  => {
            TicketID => $Param{TicketID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Ticket.History',
        ObjectID  => $Param{TicketID},
    );

    return 1;
}

=item TicketAccountedTimeGet()

returns the accounted time of a ticket.

    my $AccountedTime = $TicketObject->TicketAccountedTimeGet(TicketID => 1234);

=cut

sub TicketAccountedTimeGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need TicketID!'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db query
    return if !$DBObject->Prepare(
        SQL  => 'SELECT SUM(time_unit) FROM time_accounting WHERE ticket_id = ?',
        Bind => [ \$Param{TicketID} ],
    );

    my $AccountedTime = 0;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if (@Row && $Row[0]) {
            $Row[0] =~ s/,/./g;
            $AccountedTime = $AccountedTime + int($Row[0]);
        }
    }

    return $AccountedTime;
}

=item TicketAccountTime()

account time to a ticket.

    my $Success = $TicketObject->TicketAccountTime(
        TicketID  => 1234,
        ArticleID => 23542,      # optional
        TimeUnit  => '4.5',
        UserID    => 1,
    );

Events:
    TicketAccountTime

=cut

sub TicketAccountTime {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID TimeUnit UserID)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check some wrong formats
    $Param{TimeUnit} =~ s/,/\./g;
    $Param{TimeUnit} =~ s/ //g;
    $Param{TimeUnit} =~ s/^(-?\d{1,10}\.\d\d).+?$/$1/g;
    chomp $Param{TimeUnit};

    if ( !IsNumber($Param{TimeUnit}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "TimeUnit is not a number!"
        );
        return;
    }

    if (
        $Param{TimeUnit} >= 86400 ||
        $Param{TimeUnit} <= -86400
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "TimeUnit has to be between -86400 and 86400!"
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db quote
    $Param{TimeUnit} = $DBObject->Quote( $Param{TimeUnit}, 'Number' );

    # db update
    return if !$DBObject->Do(
        SQL => "INSERT INTO time_accounting "
            . " (ticket_id, article_id, time_unit, create_time, create_by, change_time, change_by) "
            . " VALUES (?, ?, $Param{TimeUnit}, current_timestamp, ?, current_timestamp, ?)",
        Bind => [
            \$Param{TicketID}, \$Param{ArticleID}, \$Param{UserID}, \$Param{UserID},
        ],
    );

    my $AccountedTime = $Self->TicketAccountedTimeGet( TicketID => $Param{TicketID} );

    # update ticket data
    return if !$DBObject->Do(
        SQL => 'UPDATE ticket SET change_time = current_timestamp, '
            . ' change_by = ?, accounted_time = ? WHERE id = ?',
        Bind => [ \$Param{UserID}, \$AccountedTime, \$Param{TicketID} ],
    );

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID}
    );

    # add history
    $Self->HistoryAdd(
        TicketID     => $Param{TicketID},
        ArticleID    => $Param{ArticleID},
        CreateUserID => $Param{UserID},
        HistoryType  => 'TimeAccounting',
        Name         => "\%\%$Param{TimeUnit}\%\%$AccountedTime",
    );

    # trigger event
    $Self->EventHandler(
        Event => 'TicketAccountTime',
        Data  => {
            TicketID  => $Param{TicketID},
            ArticleID => $Param{ArticleID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket',
        ObjectID  => $Param{TicketID},
    );

    return 1;
}

=item TicketFlagSet()

set ticket flags

    my $Success = $TicketObject->TicketFlagSet(
        TicketID => 123,
        Key      => 'Seen',
        Value    => 1,
        UserID   => 123, # apply to this user
    );

Events:
    TicketFlagSet

=cut

sub TicketFlagSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID Key Value UserID)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # get flags
    my %Flag = $Self->TicketFlagGet(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
    );

    # check if set is needed
    return 1 if defined $Flag{ $Param{Key} } && $Flag{ $Param{Key} } eq $Param{Value};

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # set flag
    return if !$DBObject->Do(
        SQL => '
            DELETE FROM ticket_flag
            WHERE ticket_id = ?
                AND ticket_key = ?
                AND create_by = ?',
        Bind => [ \$Param{TicketID}, \$Param{Key}, \$Param{UserID} ],
    );
    return if !$DBObject->Do(
        SQL => '
            INSERT INTO ticket_flag
            (ticket_id, ticket_key, ticket_value, create_time, create_by)
            VALUES (?, ?, ?, current_timestamp, ?)',
        Bind => [ \$Param{TicketID}, \$Param{Key}, \$Param{Value}, \$Param{UserID} ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->Delete(
        Type => $Self->{CacheType},
        Key  => 'TicketFlag::' . $Param{TicketID},
    );

    # cleanup cache of TicketFlagExists
    my $CacheKeyPattern = 'TicketFlagExists::' . $Param{TicketID} . '::' . $Param{UserID} . '::' . $Param{Key} . '::';
    my @CacheKeys = $Kernel::OM->Get('Cache')->GetKeysForType(
        Type => $Self->{CacheType},
    );
    KEY:
    for my $Key ( @CacheKeys ) {
        # skip not relevant keys
        next KEY if ( $Key !~ m/^\Q$CacheKeyPattern\E/ );

        # delete cache
        $Kernel::OM->Get('Cache')->Delete(
            Type => $Self->{CacheType},
            Key  => $Key,
        );
    }

    # event
    $Self->EventHandler(
        Event => 'TicketFlagSet',
        Data  => {
            TicketID => $Param{TicketID},
            Key      => $Param{Key},
            Value    => $Param{Value},
            UserID   => $Param{UserID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Ticket.Flag',
        UserID    => $Param{UserID},
        ObjectID  => $Param{TicketID}.'::'.$Param{Key},
    );

    return 1;
}

=item TicketFlagDelete()

delete ticket flag

    my $Success = $TicketObject->TicketFlagDelete(
        TicketID => 123,
        Key      => 'Seen',
        UserID   => 123,
    );

    my $Success = $TicketObject->TicketFlagDelete(
        TicketID => 123,
        Key      => 'Seen',
        AllUsers => 1,
    );

Events:
    TicketFlagDelete

=cut

sub TicketFlagDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID Key)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # only one of these parameters is needed
    if ( !$Param{UserID} && !$Param{AllUsers} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need UserID or AllUsers param!",
        );
        return;
    }

    # if all users parameter was given
    if ( $Param{AllUsers} ) {

        # get all affected users
        my @AllTicketFlags = $Self->TicketFlagGet(
            TicketID => $Param{TicketID},
            AllUsers => 1,
        );

        # delete flags from database
        return if !$Kernel::OM->Get('DB')->Do(
            SQL => '
                DELETE FROM ticket_flag
                WHERE ticket_id = ?
                    AND ticket_key = ?',
            Bind => [ \$Param{TicketID}, \$Param{Key} ],
        );

        # delete cache
        $Kernel::OM->Get('Cache')->Delete(
            Type => $Self->{CacheType},
            Key  => 'TicketFlag::' . $Param{TicketID},
        );

        # cleanup cache of TicketFlagExists
        my $CacheKeyPatternPart1 = 'TicketFlagExists::' . $Param{TicketID} . '::';
        my $CacheKeyPatternPart2 = '::' . $Param{Key} . '::';
        my @CacheKeys = $Kernel::OM->Get('Cache')->GetKeysForType(
            Type => $Self->{CacheType},
        );
        KEY:
        for my $Key ( @CacheKeys ) {
            # skip not relevant keys
            next KEY if ( $Key !~ m/^\Q$CacheKeyPatternPart1\E.+\Q$CacheKeyPatternPart2\E/ );

            # delete cache
            $Kernel::OM->Get('Cache')->Delete(
                Type => $Self->{CacheType},
                Key  => $Key,
            );
        }

        for my $Record (@AllTicketFlags) {

            $Self->EventHandler(
                Event => 'TicketFlagDelete',
                Data  => {
                    TicketID => $Param{TicketID},
                    Key      => $Param{Key},
                    UserID   => $Record->{UserID},
                },
                UserID => $Record->{UserID},
            );
        }
    }
    else {

        # delete flags from database
        return if !$Kernel::OM->Get('DB')->Do(
            SQL => '
                DELETE FROM ticket_flag
                WHERE ticket_id = ?
                    AND create_by = ?
                    AND ticket_key = ?',
            Bind => [ \$Param{TicketID}, \$Param{UserID}, \$Param{Key} ],
        );

        # delete cache
        $Kernel::OM->Get('Cache')->Delete(
            Type => $Self->{CacheType},
            Key  => 'TicketFlag::' . $Param{TicketID},
        );

        # cleanup cache of TicketFlagExists
        my $CacheKeyPattern = 'TicketFlagExists::' . $Param{TicketID} . '::' . $Param{UserID} . '::' . $Param{Key} . '::';
        my @CacheKeys = $Kernel::OM->Get('Cache')->GetKeysForType(
            Type => $Self->{CacheType},
        );
        KEY:
        for my $Key ( @CacheKeys ) {
            # skip not relevant keys
            next KEY if ( $Key !~ m/^\Q$CacheKeyPattern\E/ );

            # delete cache
            $Kernel::OM->Get('Cache')->Delete(
                Type => $Self->{CacheType},
                Key  => $Key,
            );
        }

        $Self->EventHandler(
            Event => 'TicketFlagDelete',
            Data  => {
                TicketID => $Param{TicketID},
                Key      => $Param{Key},
                UserID   => $Param{UserID},
            },
            UserID => $Param{UserID},
        );
    }

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Ticket.Flag',
        UserID    => $Param{UserID},
        ObjectID  => $Param{TicketID}.'::'.$Param{Key},
    );

    return 1;
}

=item TicketFlagGet()

get ticket flags

    my %Flags = $TicketObject->TicketFlagGet(
        TicketID => 123,
        UserID   => 123,  # to get flags of one user
    );

    my @Flags = $TicketObject->TicketFlagGet(
        TicketID => 123,
        AllUsers => 1,    # to get flags of all users
    );

=cut

sub TicketFlagGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need TicketID!",
        );
        return;
    }

    # check optional
    if ( !$Param{UserID} && !$Param{AllUsers} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need UserID or AllUsers param!",
        );
        return;
    }

    # check cache
    my $Flags = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => 'TicketFlag::' . $Param{TicketID},
    );

    if ( !$Flags || ref $Flags ne 'HASH' ) {

        # get database object
        my $DBObject = $Kernel::OM->Get('DB');

        # get all ticket flags of the given ticket
        return if !$DBObject->Prepare(
            SQL => '
                SELECT create_by, ticket_key, ticket_value
                FROM ticket_flag
                WHERE ticket_id = ?',
            Bind => [ \$Param{TicketID} ],
        );

        # fetch the result
        $Flags = {};
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $Flags->{ $Row[0] }->{ $Row[1] } = $Row[2];
        }

        # set cache
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => 'TicketFlag::' . $Param{TicketID},
            Value => $Flags,
        );
    }

    if ( $Param{AllUsers} ) {

        my @FlagAllUsers;
        for my $UserID ( sort keys %{$Flags} ) {

            for my $Key ( sort keys %{ $Flags->{$UserID} } ) {

                push @FlagAllUsers, {
                    Key    => $Key,
                    Value  => $Flags->{$UserID}->{$Key},
                    UserID => $UserID,
                };
            }
        }

        return @FlagAllUsers;
    }

    # extract user tags
    my $UserTags = $Flags->{ $Param{UserID} } || {};

    return %{$UserTags};
}

=item TicketUserFlagExists()

check if the given flag exists for the given user

    my $Exists = $TicketObject->TicketUserFlagExists(
        TicketID => 123,
        Flag     => 'Seen',
        Value    => ...,            # optional
        UserID   => 123,
    );

=cut

sub TicketUserFlagExists {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID Flag UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check cache
    my $CacheKey = 'TicketFlagExists::' . $Param{TicketID} . '::' . $Param{UserID} . '::' . $Param{Flag} . '::' . ($Param{Value}||'');
    my $Flags = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    if ( exists $Param{Value} ) {
        return if !$DBObject->Prepare(
            SQL   => 'SELECT id FROM ticket_flag WHERE ticket_id = ? AND ticket_key = ? AND ticket_value = ? AND create_by = ?',
            Bind  => [
                \$Param{TicketID}, \$Param{Flag}, \$Param{Value}, \$Param{UserID}
            ],
            Limit => 1,
        );
    }
    else {
        return if !$DBObject->Prepare(
            SQL   => 'SELECT id FROM ticket_flag WHERE ticket_id = ? AND ticket_key = ? AND create_by = ?',
            Bind  => [
                \$Param{TicketID}, \$Param{Flag}, \$Param{UserID}
            ],
            Limit => 1,
        );
    }

    # fetch the result
    my $Exists = 0;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Exists = $Row[0];
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => $Exists,
    );

    return $Exists;
}

=item TicketCriticalityStringGet()

Returns the tickets criticality string value.

  $TicketObject->TicketCriticalityStringGet(
      %TicketData,
      %CustomerData,
      %ResponsibleData,
  );

=cut

sub TicketCriticalityStringGet {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject       = $Kernel::OM->Get('Output::HTML::Layout');
    my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');
    my $BackendObject      = $Kernel::OM->Get('DynamicField::Backend');

    # init return value
    my $RetVal = "-";

    # check if value is given
    if ( $Param{'DynamicField_ITSMCriticality'} ) {
        # get configuration of dynamicfield
        my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
            Name => 'ITSMCriticality',
        );

        # get display value
        my $ValueStrg = $BackendObject->DisplayValueRender(
            LayoutObject       => $LayoutObject,
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Param{'DynamicField_ITSMCriticality'},
            HTMLOutput         => 0,
        );
        $RetVal = $ValueStrg->{Value};
    }

    return $RetVal;
}

=item TicketImpactStringGet()

Returns the tickets impact string value.

  $TicketObject->TicketImpactStringGet(
      %TicketData,
      %CustomerData,
      %ResponsibleData,
  );

=cut

sub TicketImpactStringGet {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject       = $Kernel::OM->Get('Output::HTML::Layout');
    my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');
    my $BackendObject      = $Kernel::OM->Get('DynamicField::Backend');

    # init return value
    my $RetVal = "-";

    # check if value is given
    if ( $Param{'DynamicField_ITSMImpact'} ) {
        # get configuration of dynamicfield
        my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
            Name => 'ITSMImpact',
        );

        # get display value
        my $ValueStrg = $BackendObject->DisplayValueRender(
            LayoutObject       => $LayoutObject,
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Param{'DynamicField_ITSMImpact'},
            HTMLOutput         => 0,
        );
        $RetVal = $ValueStrg->{Value};
    }

    return $RetVal;
}

=item CommonNextStates()

Returns a hash of common next states for multiple tickets (based on TicketStateWorkflow).

    my %StateHash = $TicketObject->TSWFCommonNextStates(
        TicketIDs => [ 1, 2, 3, 4], # required
        Action => 'SomeActionName', # optional
        UserID => 1,                # optional
    );

=cut

sub TSWFCommonNextStates {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketIDs} || ref( $Param{TicketIDs} ) ne 'ARRAY' ) {
        $Kernel::OM->Get('Log')
            ->Log( Priority => 'error', Message => 'Need TicketIDs as array ref!' );
        return;
    }
    $Self->{TicketObject} = $Param{TicketObject} || $Kernel::OM->Get('Ticket');

    my %Result = ();
    if ( $Param{StateType} ) {
        %Result = $Kernel::OM->Get('State')->StateGetStatesByType(
            StateType => $Param{StateType},
            Result    => 'HASH',
            Action    => $Param{Action} || '',
            UserID    => $Param{UserID} || 1,
        );
    }
    else {
        %Result = $Kernel::OM->Get('State')->StateList(
            UserID => $Param{UserID} || 1,
        );
    }

    my %NextStates = ();
    for my $CurrTID ( @{ $Param{TicketIDs} } ) {

        my %States = $Kernel::OM->Get('Ticket')->TicketStateList(
            TicketID => $CurrTID,
            UserID => $Param{UserID} || 1,
        );

        my @CurrNextStatesArr;
        for my $ThisState ( keys %States ) {
            push( @CurrNextStatesArr, $States{$ThisState} );
        }

        # init next states set...
        if ( !%NextStates ) {
            %NextStates = map { $_ => 1 } @CurrNextStatesArr;
        }

        # check if current next states are common with previous next states...
        else {
            for my $CurrStateCheck ( keys(%NextStates) ) {

                #remove trailing or leading spaces...
                $CurrStateCheck =~ s/^\s+//g;
                $CurrStateCheck =~ s/\s+$//g;

                next if ( grep { $_ eq $CurrStateCheck } @CurrNextStatesArr );
                delete( $NextStates{$CurrStateCheck} )
            }
        }

        # end if no next states available at all..
        last if ( !%NextStates );
    }
    for my $CurrStateID ( keys(%Result) ) {
        next if ( $NextStates{ $Result{$CurrStateID} } );
        delete( $Result{$CurrStateID} );
    }

    return %Result;
}

=item TicketQueueLinkGet()

Returns a link to the queue of a given ticket.

    my $Result = $TicketObject->TicketQueueLinkGet(
        TicketID => 123,
        UserID   => 123,
    );

=cut

sub TicketQueueLinkGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')
            ->Log( Priority => 'error', Message => 'Need TicketID!' );
        return;
    }

    my $SessionID = '';
    if ( !$Kernel::OM->Get('Config')->Get('SessionUseCookie') && $Param{SessionID} ) {
        $SessionID = ';' . $Param{SessionName} . '=' . $Param{SessionID};
    }

    my $Output =
        '<a href="?Action=AgentTicketQueue;QueueID='
        . $Param{'QueueID'}
        . $SessionID . '">'
        . $Param{'Queue'} . '</a>';


    return $Output;
}

=item CountArticles()

Returns the number of articles of a given ticket.

    my $Result = $TicketObject->CountArticles(
        TicketID => 123,
        UserID   => 123,
    );

=cut

sub CountArticles {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    my @ArticleIndexList = $Self->ArticleIndex(
        TicketID => $Param{TicketID},
    );

    $Result = ( scalar(@ArticleIndexList) || 0 );

    return $Result;
}

=item CountLinkedObjects()

Returns the number of objects linked with a given ticket.

    my $Result = $TicketObject->CountLinkedObjects(
        TicketID => 123,
        UserID   => 123,
    );

=cut

sub CountLinkedObjects {
    my ( $Self, %Param ) = @_;
    my $Result = 0;
    my $LinkObject = $Kernel::OM->Get('LinkObject') || undef;

    if ( !$LinkObject ) {
        $LinkObject = Kernel::System::LinkObject->new( %{$Self} );
    }

    return '' if !$LinkObject;

    my %PossibleObjectsList = $LinkObject->PossibleObjectsList(
        Object => 'Ticket',
        UserID => 1,
    );

    # get user preferences
    my %UserPreferences
        = $Kernel::OM->Get('User')->GetPreferences( UserID => $Param{UserID} );

    for my $CurrObject ( keys(%PossibleObjectsList) ) {
        my %LinkList = $LinkObject->LinkKeyList(
            Object1 => 'Ticket',
            Key1    => $Param{TicketID},
            Object2 => $CurrObject,
            State   => 'Valid',
            UserID  => 1,
        );

        # do not count merged tickets if user preference set
        my $LinkCount = 0;
        if ( $CurrObject eq 'Ticket' ) {
            foreach my $ObjectID ( keys %LinkList ) {
                my %Ticket = $Self->TicketGet( TicketID => $ObjectID );
                next
                    if (
                    (
                        !defined $UserPreferences{UserShowMergedTicketsInLinkedObjects}
                        || !$UserPreferences{UserShowMergedTicketsInLinkedObjects}
                    )
                    && $Ticket{StateType} eq 'merged'
                    );
                $LinkCount++;
            }
        }
        else {
            $LinkCount = scalar( keys(%LinkList) );
        }
        $Result = $Result + ( $LinkCount || 0 );
    }

    return $Result;
}

=item GetPreviousTicketState()

Returns the previous ticket state to the current one.

    my $Result = $TicketObject->GetPreviousTicketState(
        TicketID   => 123,                  # required
        ResultType => "StateName" || "ID",  # optional
    );

=cut

sub GetPreviousTicketState {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw(TicketID) ) {
        if ( !$Param{ $Needed } ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message => "Need $Needed!"
            );
            return 0;
        }
    }

    my $SelectValue = 'ts1.name';
    if (
        $Param{ResultType}
        && (
            $Param{ResultType} eq 'ID'
            || $Param{ResultType} eq 'StateID'
        )
    ) {
        $SelectValue = 'ts1.id';
    }

    my %Ticket = $Self->TicketGet(
        TicketID => $Param{TicketID},
    );
    return 0 if (
        !%Ticket
        || !$Ticket{State}
    );

    return 0 if !$Kernel::OM->Get('DB')->Prepare(
        SQL => <<"END",
SELECT $SelectValue
FROM ticket_history th1, ticket_state ts1
WHERE th1.id = (
    SELECT max(th2.id)
    FROM ticket_history th2
    WHERE th2.ticket_id = ?
        AND th2.create_time = th2.change_time
        AND th2.state_id != ?
    )
    AND ts1.id = th1.state_id
END
        Bind => [ \$Ticket{TicketID}, \$Ticket{StateID} ],
    );

    my $Result = 0;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $Result = $Row[0];
    }

    return $Result;
}

=item TicketAttachmentCountUpdate()

updates the number of attachments of an ticket

    my $Result = $TicketObject->TicketAttachmentCountUpdate(
        TicketID => 123,
        Notify   => 1 | 0      # optional - notify clients (default 0)
    );

=cut

sub TicketAttachmentCountUpdate {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(TicketID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $AttachmentCount = $Self->TicketAttachmentCountCalculate(
        TicketID => $Param{TicketID}
    );

    my $Success = $Kernel::OM->Get('DB')->Do(
        SQL => "UPDATE ticket SET attachment_count = ? WHERE id = ?",
        Bind => [ \$AttachmentCount, \$Param{TicketID} ],
    );
    if (!$Success) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Couldn't update ticket attachment count for ticket ($Param{TicketID})!",
        );
        return;
    }

    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID}
    );

    if ($Param{Notify}) {
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
            Event     => 'UPDATE',
            Namespace => 'Ticket',
            ObjectID  => $Param{TicketID},
        );
    }

    return 1;
}

=item TicketAttachmentCountCalculate()

calculate the number of attachments of an ticket

    my $Count = $TicketObject->TicketAttachmentCountCalculate(
        TicketID => 123
    );

=cut

sub TicketAttachmentCountCalculate {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(TicketID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $AttachmentCount = 0;

    my @Articles = $Self->ArticleGet(
        TicketID => $Param{TicketID},
        UserID   => 1
    );
    if (@Articles) {
        for my $Article (@Articles) {
            $AttachmentCount += $Article->{AttachmentCount} || 0;
        }
    }

    return $AttachmentCount;
}

=item ArticleMove()

Moves an article to another ticket

    my $Result = $TicketObject->ArticleMove(
        TicketID  => 123,
        ArticleID => 123,
        UserID    => 123,
    );

Result:
    1
    MoveFailed
    AccountFailed

Events:
    ArticleMove

=cut

sub ArticleMove {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID TicketID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')
                ->Log( Priority => 'error', Message => "ArticleMove: Need $Needed!" );
            return;
        }
    }

    # get ticket id of article
    my $TicketID = $Self->ArticleGetTicketID(
        ArticleID => $Param{ArticleID},
    );

    # update article data
    return 'MoveFailed' if !$Kernel::OM->Get('DB')->Do(
        SQL => "UPDATE article SET ticket_id = ?, "
            . "change_time = current_timestamp, change_by = ? WHERE id = ?",
        Bind => [ \$Param{TicketID}, \$Param{UserID}, \$Param{ArticleID} ],
    );

    # update time accounting data
    return 'AccountFailed' if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE time_accounting SET ticket_id = ?, '
            . "change_time = current_timestamp, change_by = ? WHERE article_id = ?",
        Bind => [ \$Param{TicketID}, \$Param{UserID}, \$Param{ArticleID} ],
    );

    # update accounted time of old ticket
    my $OldAccountedTime = $Self->TicketAccountedTimeGet( TicketID => $TicketID );
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE ticket SET change_time = current_timestamp, '
            . ' change_by = ?, accounted_time = ? WHERE id = ?',
        Bind => [ \$Param{UserID}, \$OldAccountedTime, \$TicketID ],
    );

    # update accounted time of new ticket
    my $NewAccountedTime = $Self->TicketAccountedTimeGet( TicketID => $Param{TicketID} );
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE ticket SET change_time = current_timestamp, '
            . ' change_by = ?, accounted_time = ? WHERE id = ?',
        Bind => [ \$Param{UserID}, \$NewAccountedTime, \$Param{TicketID} ],
    );

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID   => $TicketID,
        OnlyTicket => 1,
    );
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID},
    );

    # event
    $Self->EventHandler(
        Event => 'ArticleMove',
        Data  => {
            TicketID    => $Param{TicketID},
            ArticleID   => $Param{ArticleID},
            OldTicketID => $TicketID
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Ticket.Article',
        ObjectID  => $TicketID.'::'.$Param{ArticleID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Ticket.Article',
        ObjectID  => $Param{TicketID}.'::'.$Param{ArticleID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket',
        ObjectID  => $TicketID,
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket',
        ObjectID  => $Param{TicketID},
    );


    return 1;
}

=item ArticleCopy()

Copies an article to another ticket including all attachments

    my $Result = $TicketObject->ArticleCopy(
        TicketID  => 123,
        ArticleID => 123,
        UserID    => 123,
    );

Result:
    NewArticleID
    'NoOriginal'
    'CopyFailed'
    'UpdateFailed'

Events:
    ArticleCopy

=cut

sub ArticleCopy {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID TicketID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')
                ->Log( Priority => 'error', Message => "ArticleCopy: Need $Needed!" );
            return;
        }
    }

    # get original article content
    my %Article = $Self->ArticleGet(
        ArticleID => $Param{ArticleID},
    );
    return 'NoOriginal' if !%Article;

    # copy original article
    my $CopyArticleID = $Self->ArticleCreate(
        %Article,
        TicketID       => $Param{TicketID},
        UserID         => $Param{UserID},
        HistoryType    => 'Misc',
        HistoryComment => "Copied article $Param{ArticleID} from "
            . "ticket $Article{TicketID} to ticket $Param{TicketID}",
        DoNotSendEmail => 1,
    );
    return 'CopyFailed' if !$CopyArticleID;

    # set article times from original article
    return 'UpdateFailed' if !$Kernel::OM->Get('DB')->Do(
        SQL =>
            'UPDATE article SET create_time = ?, change_time = ?, incoming_time = ? WHERE id = ?',
        Bind => [
            \$Article{Created},      \$Article{Changed},
            \$Article{IncomingTime}, \$CopyArticleID
        ],
    );

    # copy attachments from original article
    my %ArticleIndex = $Self->ArticleAttachmentIndex(
        ArticleID => $Param{ArticleID},
        UserID    => $Param{UserID},
    );
    for my $Index ( keys %ArticleIndex ) {
        my %Attachment = $Self->ArticleAttachment(
            ArticleID    => $Param{ArticleID},
            AttachmentID => $Index,
            UserID       => $Param{UserID},
        );
        $Self->ArticleWriteAttachment(
            %Attachment,
            ArticleID => $CopyArticleID,
            UserID    => $Param{UserID},
        );
    }

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $Param{TicketID}
    );

    # copy plain article if exists
    if ( $Article{Channel} =~ /email/i ) {
        my $Data = $Self->ArticlePlain(
            ArticleID => $Param{ArticleID}
        );
        if ($Data) {
            $Self->ArticleWritePlain(
                ArticleID => $CopyArticleID,
                Email     => $Data,
                UserID    => $Param{UserID},
            );
        }
    }

    # event
    $Self->EventHandler(
        Event => 'ArticleCopy',
        Data  => {
            TicketID     => $Param{TicketID},
            ArticleID    => $CopyArticleID,
            OldArticleID => $Param{ArticleID},
        },
        UserID => $Param{UserID},
    );

    return $CopyArticleID;
}

=item ArticleFullDelete()

Delete an article, its history, its plain message, and all attachments

    my $Success = $TicketObject->ArticleFullDelete(
        ArticleID => 123,
        UserID    => 123,
    );

ATTENTION:
    sub ArticleDelete is used in this sub, but this sub does not delete
    article history

Events:
    ArticleFullDelete

=cut

sub ArticleFullDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID UserID)) {
        if ( !$Param{ $Needed } ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message => "ArticleFullDelete: Need $Needed!"
            );
            return;
        }
    }

    # delete article history
    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => 'DELETE FROM ticket_history WHERE article_id = ?',
        Bind => [ \$Param{ArticleID} ],
    );

    # delete article, attachments and plain emails
    return if !$Self->ArticleDelete(
        ArticleID => $Param{ArticleID},
        UserID    => $Param{UserID},
    );

    # get ticket id of article
    my $TicketID = $Self->ArticleGetTicketID(
        ArticleID => $Param{ArticleID},
    );
    return if !$TicketID;

    # clear ticket cache
    $Self->_TicketCacheClear(
        TicketID => $TicketID,
    );

    # event
    $Self->EventHandler(
        Event => 'ArticleFullDelete',
        Data  => {
            TicketID  => $TicketID,
            ArticleID => $Param{ArticleID},
        },
        UserID => $Param{UserID},
    );

    return 1;
}

=item ArticleCreateDateUpdate()

Manipulates the article create date

    my $Result = $TicketObject->ArticleCreateDateUpdate(
        ArticleID => 123,
        UserID    => 123,
    );

Events:
    ArticleUpdate

=cut

sub ArticleCreateDateUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID ArticleID UserID Created IncomingTime)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')
                ->Log( Priority => 'error', Message => "ArticleCreateDateUpdate: Need $Needed!" );
            return;
        }
    }

    # db update
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => "UPDATE article SET incoming_time = ?, create_time = ?,"
            . "change_time = current_timestamp, change_by = ? WHERE id = ?",
        Bind => [ \$Param{IncomingTime}, \$Param{Created}, \$Param{UserID}, \$Param{ArticleID} ],
    );

    # event
    $Self->EventHandler(
        Event => 'ArticleUpdate',
        Data  => {
            TicketID  => $Param{TicketID},
            ArticleID => $Param{ArticleID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Ticket.Article',
        ObjectID  => $Param{TicketID}.'::'.$Param{ArticleID},
    );

    return 1;
}

=item ArticleFlagDataSet()

set ....

    my $Success = $TicketObject->ArticleFlagDataSet(
            ArticleID   => 1,
            Key         => 'ToDo', // ArticleFlagKey
            Keywords    => Keywords,
            Subject     => Subject,
            Note        => Note,
        );
=cut

sub ArticleFlagDataSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID Key UserID)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Log')
                ->Log( Priority => 'error', Message => "ArticleFlagDataSet: Need $Needed!" );
            return;
        }
    }

    # get ticket id of article
    my $TicketID = $Self->ArticleGetTicketID(
        ArticleID => $Param{ArticleID},
    );

    # db quote
    for my $Quote (qw(Notes Subject Keywords Key)) {
        $Param{$Quote} = $Kernel::OM->Get('DB')->Quote( $Param{$Quote} );
    }
    for my $Quote (qw(ArticleID)) {
        $Param{$Quote} = $Kernel::OM->Get('DB')->Quote( $Param{$Quote}, 'Integer' );
    }

    # check if update is needed
    my %ArticleFlagData = $Self->ArticleFlagDataGet(
        ArticleID      => $Param{ArticleID},
        ArticleFlagKey => $Param{Key},
        UserID         => $Param{UserID},
    );

    # return 1 if ( %ArticleFlagData && $ArticleFlagData{ $Param{TicketID} } eq $Param{Notes} );

    # update action
    if (
        defined( $ArticleFlagData{ $Param{ArticleID} } )
        && defined( $ArticleFlagData{ $Param{Key} } )
        )
    {
        return if !$Kernel::OM->Get('DB')->Do(
            SQL =>
                'UPDATE kix_article_flag SET note = ?, subject = ?, keywords = ? '
                . 'WHERE article_id = ? AND article_key = ? AND create_by = ? ',
            Bind => [
                \$Param{Note},      \$Param{Subject}, \$Param{Keywords},
                \$Param{ArticleID}, \$Param{Key},     \$Param{UserID}
            ],
        );

        # push client callback event
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
            Event     => 'UPDATE',
            Namespace => 'Ticket.Article.Flag',
            ObjectID  => $TicketID.'::'.$Param{ArticleID}.'::'.$Param{Key},
        );
    }

    # insert action
    else {
        return if !$Kernel::OM->Get('DB')->Do(
            SQL =>
                'INSERT INTO kix_article_flag (article_id, article_key, keywords, subject, note, create_by) '
                . ' VALUES (?, ?, ?, ?, ?, ?)',
            Bind => [
                \$Param{ArticleID}, \$Param{Key},  \$Param{Keywords},
                \$Param{Subject},   \$Param{Note}, \$Param{UserID}
            ],
        );

        # push client callback event
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
            Event     => 'CREATE',
            Namespace => 'Ticket.Article.Flag',
            ObjectID  => $TicketID.'::'.$Param{ArticleID}.'::'.$Param{Key},
        );
    }

    return 1;
}

=item ArticleFlagDataDelete()

delete ....

    my $Success = $TicketObject->ArticleFlagDataDelete(
            ArticleID   => 1,
            Key         => 'ToDo',
            UserID      => $UserID,  # use either UserID or AllUsers
        );

    my $Success = $TicketObject->ArticleFlagDataDelete(
            ArticleID   => 1,
            Key         => 'ToDo',
            AllUsers    => 1,        # delete flag data from all users for this article
        );
=cut

sub ArticleFlagDataDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID Key)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Log')
                ->Log( Priority => 'error', Message => "ArticleFlagDataDelete: Need $Needed!" );
            return;
        }
    }
    if ( !defined $Param{UserID} && !defined $Param{AllUsers} ) {
        $Kernel::OM->Get('Log')
            ->Log(
            Priority => 'error',
            Message  => "ArticleFlagDataDelete: Need either UserID or AllUsers!"
            );
        return;
    }

    # get ticket id of article
    my $TicketID = $Self->ArticleGetTicketID(
        ArticleID => $Param{ArticleID},
    );

    # check if UserID or AllUsers set
    if ( $Param{UserID} ) {

        # insert action
        return if !$Kernel::OM->Get('DB')->Do(
            SQL =>
                'DELETE FROM kix_article_flag'
                . ' WHERE article_id = ? AND article_key = ? AND create_by = ? ',
            Bind => [ \$Param{ArticleID}, \$Param{Key}, \$Param{UserID} ],
        );
    }
    else {

        # insert action
        return if !$Kernel::OM->Get('DB')->Do(
            SQL =>
                'DELETE FROM kix_article_flag'
                . ' WHERE article_id = ? AND article_key = ? ',
            Bind => [ \$Param{ArticleID}, \$Param{Key} ],
        );
    }

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Ticket.Article.Flag',
        ObjectID  => $TicketID.'::'.$Param{ArticleID},
    );

    return 1;
}

=item ArticleFlagDataGet()

get ....

    my $Success = $TicketObject->ArticleFlagDataGet(
            ArticleID      => 1,
            ArticleFlagKey => 'ToDo',
            UserID         => 1
        );
=cut

sub ArticleFlagDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID ArticleFlagKey UserID)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Log')
                ->Log( Priority => 'error', Message => "ArticleFlagGet: Need $Needed!" );
            return;
        }
    }

    # fetch the result
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT article_id, article_key, subject, keywords, note, create_by'
            . ' FROM kix_article_flag'
            . ' WHERE article_id = ? AND article_key = ? AND create_by = ?',
        Bind => [ \$Param{ArticleID}, \$Param{ArticleFlagKey}, \$Param{UserID} ],
        Limit => 1,
    );

    my %ArticleFlagData;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $ArticleFlagData{ArticleID} = $Row[0];
        $ArticleFlagData{Key}       = $Row[1];
        $ArticleFlagData{Subject}   = $Row[2];
        $ArticleFlagData{Keywords}  = $Row[3];
        $ArticleFlagData{Note}      = $Row[4];
        $ArticleFlagData{CreateBy}  = $Row[5];
    }

    return %ArticleFlagData;
}

=item TicketAccountedTimeDelete()

deletes the accounted time of a ticket.

    my $Success = $TicketObject->TicketAccountedTimeDelete(
        TicketID    => 1234,
        ArticleID   => 1234     # optional
    );

=cut

sub TicketAccountedTimeDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')
                ->Log( Priority => 'error', Message => "Need $Needed!" );
            return;
        }
    }

    # db query
    if ( $Param{ArticleID} ) {
        return if !$Kernel::OM->Get('DB')->Prepare(
            SQL => 'DELETE FROM time_accounting WHERE ticket_id = ? AND article_id = ?',
            Bind => [ \$Param{TicketID}, \$Param{ArticleID} ],
        );
    }
    else {
        return if !$Kernel::OM->Get('DB')->Prepare(
            SQL  => 'DELETE FROM time_accounting WHERE ticket_id = ?',
            Bind => [ \$Param{TicketID} ],
        );
    }

    return 1;
}

sub GetLinkedTickets {
    my ( $Self, %Param ) = @_;

    my $SQL = 'SELECT DISTINCT target_key FROM link_relation WHERE source_key = ?';

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => $SQL,
        Bind => [ \$Param{Customer} ],
    );
    my @TicketIDs;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push @TicketIDs, $Row[0];
    }
    return @TicketIDs;
}

sub TicketFulltextIndexRebuild {
    my ( $Self, %Param ) = @_;

    # get all tickets
    my @TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        Sort => [
            {
                Field     => 'Age',
                Direction => 'DESCENDING'
            }
        ],
        ObjectType => 'Ticket',
        Result     => 'ARRAY',
        Limit      => 100_000_000,
        UserID     => 1,
        UserType   => 'Agent'
    );

    $Kernel::OM->Get('Log')->Log(
        Priority => 'info',
        Message  => "Rebuilding ticket fulltext index for ".@TicketIDs." tickets."
    );

    my $Count      = 0;
    my $PercentOld = 0;
    for my $TicketID ( @TicketIDs ) {

        # get articles
        my @ArticleIndex = $Self->ArticleIndex(
            TicketID => $TicketID,
            UserID   => 1,
        );

        for my $ArticleID (@ArticleIndex) {
            $Self->ArticleIndexBuild(
                ArticleID => $ArticleID,
                UserID    => 1,
            );
        }

        my $Percent = int( $Count / ( $#TicketIDs / 100 ) );
        $Count += 1;

        if ( $Percent > $PercentOld ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Rebuilding ticket fulltext index...". $Percent . "% done."
            );
            $PercentOld = $Percent;
        }
    }

    return 1;
}

=item GetAssignedTicketsForObject()

return all assigned ticket IDs

    my $TicketIDList = $TicketObject->GetAssignedTicketsForObject(
        ObjectType   => 'Contact',
        Object       => $ContactHashRef,         # (optional)
        ObjectIDList => $ObjectIDListArrayRef,   # (optional)
        UserID       => 1
    );

=cut

sub GetAssignedTicketsForObject {
    my ( $Self, %Param ) = @_;

    my @AssignedTicketIDs = ();

    my %SearchData = $Self->_GetAssignedSearchParams(
        %Param,
        AssignedObjectType => 'Ticket'
    );

    if (IsHashRefWithData(\%SearchData)) {
        my %Search;
        if (IsArrayRefWithData($Param{ObjectIDList})) {
            $Search{AND} = [
                { Field => 'TicketID', Operator => 'IN', Value => $Param{ObjectIDList} }
            ];
        }

        my @ORSearch = map { { Field => $_, Operator => 'IN', Value => $SearchData{$_} } } keys %SearchData;
        @AssignedTicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType => 'Ticket',
            Result     => 'ARRAY',
            Search     => {
                %Search,
                OR => \@ORSearch
            },
            UserID   => $Param{UserID},
            UserType => $Param{UserType},
            Silent   => $Param{Silent}
        );

        if ( IsArrayRefWithData(\@AssignedTicketIDs) ) {
            @AssignedTicketIDs = map { 0 + $_ } @AssignedTicketIDs;
        }
    }

    return \@AssignedTicketIDs;
}

=item MarkAsSeen()

mark all articles and ticket as seen by the given user

    my $Success = $TicketObject->MarkAsSeen(
        TicketID => 1,
        UserID   => 1
    );
=cut

sub MarkAsSeen {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message => "Need $Needed!"
            );
            return;
        }
    }

    # mark also all articles as seen
    my @ArticleIDs = $Self->ArticleIndex(
        TicketID => $Param{TicketID}
    );
    foreach my $ArticleID ( @ArticleIDs ) {
        my $Success = $Self->ArticleFlagSet(
            ArticleID => $ArticleID,
            TicketID  => $Param{TicketID},
            Key       => 'Seen',
            Value     => 1,
            UserID    => $Param{UserID},
            # for performance reasons - ticket flag update will trigger notification
            Silent    => 1,
            NoEvents  => 1
        );
        return 0 if !$Success;
    }

    # ticket should be marked as seen when all articles of the ticket are marked as seen
    # somehow there are cases that all article are already marked, but not the ticket. force mark as seen
    return $Self->TicketFlagSet(
        TicketID => $Param{TicketID},
        Key      => 'Seen',
        Value    => 1,
        UserID   => $Param{UserID}
    );
}

sub DESTROY {
    my $Self = shift;

    # execute all transaction events
    $Self->EventHandlerTransaction();

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
