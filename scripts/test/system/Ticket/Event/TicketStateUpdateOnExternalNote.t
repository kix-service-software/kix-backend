# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use utf8;

use Kernel::System::VariableCheck qw(:all);

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# check default config
$Self->IsDeeply(
    $Kernel::OM->Get('Config')->Get('Ticket::EventModulePost')->{'999-TicketStateUpdateOnExternalNote'},
    {
        Module      => 'Kernel::System::Ticket::Event::TicketStateUpdateOnExternalNote',
        Event       => '(TicketCreate|ArticleCreate|TicketStateUpdate)',
        Transaction => 1,
    },
    'Default config "Ticket::EventModulePost###999-TicketStateUpdateOnExternalNote"',
);

# disable PostmasterFollowUpState configs
$Helper->ConfigSettingChange(
    Valid => 0,
    Key   => 'PostmasterFollowUpState',
    Value => undef,
);
$Helper->ConfigSettingChange(
    Valid => 0,
    Key   => 'PostmasterFollowUpStateClosed',
    Value => undef,
);
$Helper->ConfigSettingChange(
    Valid => 0,
    Key   => 'TicketStateWorkflow::PostmasterFollowUpState',
    Value => undef,
);
$Self->Is(
    $Kernel::OM->Get('Config')->Get('PostmasterFollowUpState'),
    undef,
    'Changed config "PostmasterFollowUpState"',
);
$Self->Is(
    $Kernel::OM->Get('Config')->Get('PostmasterFollowUpStateClosed'),
    undef,
    'Changed config "PostmasterFollowUpStateClosed"',
);
$Self->Is(
    $Kernel::OM->Get('Config')->Get('TicketStateWorkflow::PostmasterFollowUpState'),
    undef,
    'Changed config "TicketStateWorkflow::PostmasterFollowUpState"',
);

# get test queue
my $QueueID = $Kernel::OM->Get('Queue')->QueueLookup(
    Queue => 'Service Desk',
);
$Self->True(
    $QueueID,
    'Queue "Service Desk" exists',
);
my %Queue = $Kernel::OM->Get('Queue')->QueueGet(
    ID => $QueueID,
);

# get FollowUpTypes
my %FollowUpTypeList = $Kernel::OM->Get('Queue')->FollowUpTypeList(
    Valid => 1,
);
my %ReverseFollowUpTypeList = reverse( %FollowUpTypeList );
$Self->True(
    $ReverseFollowUpTypeList{possible},
    'FollowUpType "possible" exists',
);
$Self->True(
    $ReverseFollowUpTypeList{reject},
    'FollowUpType "reject" exists',
);

# create ticket with status "new"
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title           => 'Testticket Unittest',
    Type            => 'Unclassified',
    State           => 'new',
    QueueID         => $QueueID,
    PriorityID      => 1,
    OwnerID         => 1,
    UserID          => 1,
    LockID          => 1,
);
$Self->True(
    $TicketID,
    'Create ticket',
);

# create external note
my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID,
    Channel         => 'note',
    SenderType      => 'external',
    MimeType        => 'text/plain',
    Charset         => 'utf8',
    Subject         => 'unittest',
    Body            => 'unittest',
    HistoryType     => 'AddNote',
    HistoryComment  => '%%',
    NoAgentNotify   => 1,
    UserID          => 1,
);
$Self->True(
    $ArticleID,
    'Create external note',
);

# discard objects - "end process"
$Helper->ObjectsDiscard();

# check ticket data
my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID => $TicketID,
);
$Self->Is(
    $Ticket{State},
    'new',
    'Ticket status not changed after creation',
);

# create external note
$ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID,
    Channel         => 'note',
    SenderType      => 'external',
    MimeType        => 'text/plain',
    Charset         => 'utf8',
    Subject         => 'unittest',
    Body            => 'unittest',
    HistoryType     => 'AddNote',
    HistoryComment  => '%%',
    NoAgentNotify   => 1,
    UserID          => 1,
);
$Self->True(
    $ArticleID,
    'Create external note',
);

# discard objects - "end process"
$Helper->ObjectsDiscard();

# check ticket data
%Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID => $TicketID,
);
$Self->Is(
    $Ticket{State},
    'open',
    'Ticket status changed after new external note - fallback state "open"',
);

# set PostmasterFollowUpState
$Helper->ConfigSettingChange(
    Valid => 1,
    Key   => 'PostmasterFollowUpState',
    Value => 'closed',
);
$Self->Is(
    $Kernel::OM->Get('Config')->Get('PostmasterFollowUpState'),
    'closed',
    'Changed config "PostmasterFollowUpState"',
);

# create external note
$ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID,
    Channel         => 'note',
    SenderType      => 'external',
    MimeType        => 'text/plain',
    Charset         => 'utf8',
    Subject         => 'unittest',
    Body            => 'unittest',
    HistoryType     => 'AddNote',
    HistoryComment  => '%%',
    NoAgentNotify   => 1,
    UserID          => 1,
);
$Self->True(
    $ArticleID,
    'Create external note',
);

# discard objects - "end process"
$Helper->ObjectsDiscard();

# check ticket data
%Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID => $TicketID,
);
$Self->Is(
    $Ticket{State},
    'closed',
    'Ticket status changed after new external note - SysConfig "PostmasterFollowUpState"',
);

# set PostmasterFollowUpState
$Helper->ConfigSettingChange(
    Valid => 1,
    Key   => 'PostmasterFollowUpStateClosed',
    Value => 'new',
);
$Self->Is(
    $Kernel::OM->Get('Config')->Get('PostmasterFollowUpStateClosed'),
    'new',
    'Changed config "PostmasterFollowUpStateClosed"',
);

# update queue to reject followup for closed tickets
my $Success = $Kernel::OM->Get('Queue')->QueueUpdate(
    %Queue,
    FollowUpID          => $ReverseFollowUpTypeList{reject},
    UserID              => 1,
);
%Queue = $Kernel::OM->Get('Queue')->QueueGet(
    ID => $QueueID,
);
$Self->Is(
    $Queue{FollowUpID},
    $ReverseFollowUpTypeList{reject},
    'Update queue to reject followup for closed tickets',
);

# create external note
$ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID,
    Channel         => 'note',
    SenderType      => 'external',
    MimeType        => 'text/plain',
    Charset         => 'utf8',
    Subject         => 'unittest',
    Body            => 'unittest',
    HistoryType     => 'AddNote',
    HistoryComment  => '%%',
    NoAgentNotify   => 1,
    UserID          => 1,
);
$Self->True(
    $ArticleID,
    'Create external note',
);

# discard objects - "end process"
$Helper->ObjectsDiscard();

# check ticket data
%Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID => $TicketID,
);
$Self->Is(
    $Ticket{State},
    'closed',
    'Ticket status unchanged after new external note - rejected followup for closed ticket',
);

# update queue to allow followup for closed tickets
$Success = $Kernel::OM->Get('Queue')->QueueUpdate(
    %Queue,
    FollowUpID          => $ReverseFollowUpTypeList{possible},
    UserID              => 1,
);
%Queue = $Kernel::OM->Get('Queue')->QueueGet(
    ID => $QueueID,
);
$Self->Is(
    $Queue{FollowUpID},
    $ReverseFollowUpTypeList{possible},
    'Update queue to allow followup for closed tickets',
);

# create external note
$ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID,
    Channel         => 'note',
    SenderType      => 'external',
    MimeType        => 'text/plain',
    Charset         => 'utf8',
    Subject         => 'unittest',
    Body            => 'unittest',
    HistoryType     => 'AddNote',
    HistoryComment  => '%%',
    NoAgentNotify   => 1,
    UserID          => 1,
);
$Self->True(
    $ArticleID,
    'Create external note',
);

# discard objects - "end process"
$Helper->ObjectsDiscard();

# check ticket data
%Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID => $TicketID,
);
$Self->Is(
    $Ticket{State},
    'new',
    'Ticket status changed after new external note - SysConfig "PostmasterFollowUpStateClosed"',
);

# create external note
$ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID,
    Channel         => 'note',
    SenderType      => 'external',
    MimeType        => 'text/plain',
    Charset         => 'utf8',
    Subject         => 'unittest',
    Body            => 'unittest',
    HistoryType     => 'AddNote',
    HistoryComment  => '%%',
    NoAgentNotify   => 1,
    UserID          => 1,
);
$Self->True(
    $ArticleID,
    'Create external note',
);

# discard objects - "end process"
$Helper->ObjectsDiscard();

# check ticket data
%Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID => $TicketID,
);
$Self->Is(
    $Ticket{State},
    'closed',
    'Ticket status changed after new external note - SysConfig "PostmasterFollowUpState"',
);

# set PostmasterFollowUpState and PostmasterFollowUpStateClosed
$Helper->ConfigSettingChange(
    Valid => 1,
    Key   => 'PostmasterFollowUpState',
    Value => 'pending reminder',
);
$Self->Is(
    $Kernel::OM->Get('Config')->Get('PostmasterFollowUpState'),
    'pending reminder',
    'Changed config "PostmasterFollowUpState"',
);
$Helper->ConfigSettingChange(
    Valid => 0,
    Key   => 'PostmasterFollowUpStateClosed',
    Value => undef,
);
$Self->Is(
    $Kernel::OM->Get('Config')->Get('PostmasterFollowUpStateClosed'),
    undef,
    'Changed config "PostmasterFollowUpStateClosed"',
);

# create external note
$ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID,
    Channel         => 'note',
    SenderType      => 'external',
    MimeType        => 'text/plain',
    Charset         => 'utf8',
    Subject         => 'unittest',
    Body            => 'unittest',
    HistoryType     => 'AddNote',
    HistoryComment  => '%%',
    NoAgentNotify   => 1,
    UserID          => 1,
);
$Self->True(
    $ArticleID,
    'Create external note',
);

# discard objects - "end process"
$Helper->ObjectsDiscard();

# check ticket data
%Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID => $TicketID,
);
$Self->Is(
    $Ticket{State},
    'pending reminder',
    'Ticket status changed after new external note - SysConfig "PostmasterFollowUpState" for closed ticket',
);

# set TicketStateWorkflow::PostmasterFollowUpState
$Helper->ConfigSettingChange(
    Valid => 1,
    Key   => 'TicketStateWorkflow::PostmasterFollowUpState',
    Value => {
        'Incident::pending reminder' => 'open',
        'pending reminder'           => 'new',
        'Unclassified::new'          => 'pending reminder',
        'new'                        => 'pending reminder',
        'open'                       => 'closed',
    },
);
$Self->IsDeeply(
    $Kernel::OM->Get('Config')->Get('TicketStateWorkflow::PostmasterFollowUpState'),
    {
        'Incident::pending reminder' => 'open',
        'pending reminder'           => 'new',
        'Unclassified::new'          => 'pending reminder',
        'new'                        => 'pending reminder',
        'open'                       => 'closed',
    },
    'Changed config "TicketStateWorkflow::PostmasterFollowUpState"',
);

# create external note
$ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID,
    Channel         => 'note',
    SenderType      => 'external',
    MimeType        => 'text/plain',
    Charset         => 'utf8',
    Subject         => 'unittest',
    Body            => 'unittest',
    HistoryType     => 'AddNote',
    HistoryComment  => '%%',
    NoAgentNotify   => 1,
    UserID          => 1,
);
$Self->True(
    $ArticleID,
    'Create external note',
);

# discard objects - "end process"
$Helper->ObjectsDiscard();

# check ticket data
%Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID => $TicketID,
);
$Self->Is(
    $Ticket{State},
    'new',
    'Ticket status changed after new external note - SysConfig "TicketStateWorkflow::PostmasterFollowUpState" fallback without type',
);

# create external note
$ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID,
    Channel         => 'note',
    SenderType      => 'external',
    MimeType        => 'text/plain',
    Charset         => 'utf8',
    Subject         => 'unittest',
    Body            => 'unittest',
    HistoryType     => 'AddNote',
    HistoryComment  => '%%',
    NoAgentNotify   => 1,
    UserID          => 1,
);
$Self->True(
    $ArticleID,
    'Create external note',
);

# discard objects - "end process"
$Helper->ObjectsDiscard();

# check ticket data
%Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID => $TicketID,
);
$Self->Is(
    $Ticket{State},
    'pending reminder',
    'Ticket status changed after new external note - SysConfig "TicketStateWorkflow::PostmasterFollowUpState" entry with type',
);

# update ticket state
$Success = $Kernel::OM->Get('Ticket')->TicketStateSet(
    State     => 'open',
    TicketID  => $TicketID,
    UserID    => 1,
);
$Self->True(
    $Success,
    'TicketStateSet "open"',
);

# create external note
$ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID,
    Channel         => 'note',
    SenderType      => 'external',
    MimeType        => 'text/plain',
    Charset         => 'utf8',
    Subject         => 'unittest',
    Body            => 'unittest',
    HistoryType     => 'AddNote',
    HistoryComment  => '%%',
    NoAgentNotify   => 1,
    UserID          => 1,
);
$Self->True(
    $ArticleID,
    'Create external note',
);

# discard objects - "end process"
$Helper->ObjectsDiscard();

# check ticket data
%Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID => $TicketID,
);
$Self->Is(
    $Ticket{State},
    'open',
    'Ticket status unchanged after new external note - Reset Protection',
);

# create external note
$ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID,
    Channel         => 'note',
    SenderType      => 'external',
    MimeType        => 'text/plain',
    Charset         => 'utf8',
    Subject         => 'unittest',
    Body            => 'unittest',
    HistoryType     => 'AddNote',
    HistoryComment  => '%%',
    NoAgentNotify   => 1,
    UserID          => 1,
);
$Self->True(
    $ArticleID,
    'Create external note',
);

# discard objects - "end process"
$Helper->ObjectsDiscard();

# check ticket data
%Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID => $TicketID,
);
$Self->Is(
    $Ticket{State},
    'closed',
    'Ticket status changed after new external note - Reset Protection only for previous "process"',
);

# rollback transaction on database
$Helper->Rollback();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
