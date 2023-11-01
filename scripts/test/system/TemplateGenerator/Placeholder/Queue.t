# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get needed objects
my $ConfigObject  = $Kernel::OM->Get('Config');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

$Helper->BeginWork();

my $SystemAddressName          = 'sometestmail@unknowntesthost.com';
my $SystemAddressRealname      = 'Some Test Mail';
my $TicketTitle                = 'some test ticket for queue placeholder testing';
my $GrandparentName            = 'GrandparentTestQueueName';
my $ParentName                 = 'ParentTestQueueName';
my $ParentFullname             = $GrandparentName .'::ParentTestQueueName';
my $ChildName                  = 'ChildTestQueueName';
my $ChildFullname              = $ParentFullname . '::ChildTestQueueName';
my $GrandparentSignature       = '<KIX_QUEUE_Name> +++ <KIX_QUEUE_Signature>';
my $GrandparentSignatureResult = "$GrandparentName +++ -";
my $ParentSignature            = 'some simple string';
my $ParentSignatureResult      = $ParentSignature;
my $ChildSignature             = '<KIX_TICKET_Title> +++ <KIX_TICKET_Queue> +++ <KIX_QUEUE_Name> +++ <KIX_QUEUE_FullName>';
my $ChildSignatureResult       = "$TicketTitle +++ $ChildFullname +++ $ChildName +++ $ChildFullname";

# create system address
my $SystemAddressID = $Kernel::OM->Get('SystemAddress')->SystemAddressAdd(
    Name     => $SystemAddressName,
    Comment  => q{},
    ValidID  => 1,
    Realname => $SystemAddressRealname,
    UserID   => 1,
    Silent   => 1
);
$Self->True(
    $SystemAddressID,
    'ReplaceQueue - create system address'
);

return if (!$SystemAddressID);

my $GrandparentQueueID = $Kernel::OM->Get('Queue')->QueueAdd(
    Name            => $GrandparentName,
    Comment         => q{},
    ValidID         => 1,
    FollowUpID      => 1,
    FollowUpLock    => 1,
    SystemAddressID => $SystemAddressID,
    Signature       => $GrandparentSignature,
    UserID          => 1,
    Silent          => 1
);
$Self->True(
    $GrandparentQueueID,
    'ReplaceQueue - create grandparent queue'
);

$Kernel::OM->ObjectsDiscard(
    Objects => [
        'Queue'
    ]
);

return if (!$GrandparentQueueID);

my $ParentQueueID = $Kernel::OM->Get('Queue')->QueueAdd(
    Name            => $ParentFullname,
    Comment         => q{},
    ValidID         => 1,
    FollowUpID      => 1,
    FollowUpLock    => 1,
    SystemAddressID => $SystemAddressID,
    Signature       => $ParentSignature,
    UserID          => 1,
    Silent          => 1
);
$Self->True(
    $ParentQueueID,
    'ReplaceQueue - create parent queue'
);

$Kernel::OM->ObjectsDiscard(
    Objects => [
        'Queue'
    ]
);

return if (!$ParentQueueID);

# check queue placeholder by ID
_checkByQueueID();

my $ChildQueueID = $Kernel::OM->Get('Queue')->QueueAdd(
    Name            => $ChildFullname,
    Comment         => q{},
    ValidID         => 1,
    FollowUpID      => 2,
    FollowUpLock    => 0,
    SystemAddressID => $SystemAddressID,
    Signature       => $ChildSignature,
    UserID          => 1,
    Silent          => 1
);
$Self->True(
    $ChildQueueID,
    'ReplaceQueue - create child queue'
);

$Kernel::OM->ObjectsDiscard(
    Objects => [
        'Queue'
    ]
);

return if (!$ChildQueueID);

my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title    => $TicketTitle,
    OwnerID  => 1,
    QueueID  => $ChildQueueID,
    Lock     => 'unlock',
    Priority => '3 normal',
    State    => 'closed',
    UserID   => 1,
    Silent   => 1
);
$Self->True(
    $TicketID,
    'ReplaceQueue - create ticket'
);

$Kernel::OM->ObjectsDiscard(
    Objects => [
        'Ticket'
    ]
);

return if (!$TicketID);

# check queue placeholder by ticket
_checkTicketQueue();

sub _checkByQueueID {
    my $FollowUp = $Kernel::OM->Get('Queue')->GetFollowUpOption(
        QueueID => $GrandparentQueueID
    );
    my @Tests = (
        {
            Name   => 'check queue name (grandparent)',
            Text   => '<KIX_QUEUE_Name>',
            Result => $GrandparentName
        },
        {
            Name    => 'check queue full name (grandparent)',
            Text    => '<KIX_QUEUE_Fullname>',
            Result  => $GrandparentName,
        },
        {
            Name    => 'check queue name (parent)',
            Text    => '<KIX_QUEUE_Name>',
            Result  => $ParentName,
            QueueID => $ParentQueueID
        },
        {
            Name    => 'check queue full name (parent)',
            Text    => '<KIX_QUEUE_Fullname>',
            Result  => $ParentFullname,
            QueueID => $ParentQueueID
        },
        {
            Name   => 'check follow up (grandparent)',
            Text   => '<KIX_QUEUE_FollowUp>',
            Result => $FollowUp
        },
        {
            Name   => 'check follow up lock (grandparent)',
            Text   => '<KIX_QUEUE_FollowUpLock>',
            Result => 'Yes'
        },
        {
            Name   => 'check follow up lock - german (grandparent)',
            Text   => '<KIX_QUEUE_FollowUpLock>',
            German => 1,
            Result => 'Ja'
        },
        {
            Name   => 'check system address id (grandparent)',
            Text   => '<KIX_QUEUE_SystemAddressID>',
            Result => $SystemAddressID
        },
        {
            Name   => 'check system address (grandparent)',
            Text   => '<KIX_QUEUE_SystemAddress>',
            Result => q{"} . $SystemAddressRealname . '" <' . $SystemAddressName . '>'
        },
        {
            Name   => 'check parent id (grandparent)',
            Text   => '<KIX_QUEUE_ParentID>',
            Result => q{-}
        },
        {
            Name    => 'check parent (grandparent)',
            Text    => '<KIX_QUEUE_Parent>',
            Result  => q{-}
        },
        {
            Name    => 'check parent id (parent)',
            Text    => '<KIX_QUEUE_ParentID>',
            Result  => $GrandparentQueueID,
            QueueID => $ParentQueueID
        },
        {
            Name    => 'check parent (parent)',
            Text    => '<KIX_QUEUE_Parent>',
            Result  => $GrandparentName,
            QueueID => $ParentQueueID
        },
        {
            Name    => 'check parent fullname (parent)',
            Text    => '<KIX_QUEUE_ParentFullname>',
            Result  => $GrandparentName,
            QueueID => $ParentQueueID
        },
        {
            Name   => 'check signature (grandparent - no loop)',
            Text   => '<KIX_QUEUE_Signature>',
            Result => $GrandparentSignatureResult
        },
        {
            Name   => "Placeholder: <KIX_QUEUE>",
            Text   => "<KIX_QUEUE>",
            Result => $GrandparentName
        }
    );
    for my $Test ( @Tests ) {
        my $Result = $Kernel::OM->Get('TemplateGenerator')->_Replace(
            Text     => $Test->{Text},
            Data     => {
                QueueID => $Test->{QueueID} || $GrandparentQueueID
            },
            UserID   => 1,
            Language => $Test->{German} ? 'de' : 'en'
        );
        $Self->Is(
            $Result,
            $Test->{Result},
            "$Test->{Name}:"
        );
    }
}

sub _checkTicketQueue {
    my $FollowUp = $Kernel::OM->Get('Queue')->GetFollowUpOption(
        QueueID => $ChildQueueID
    );
    my @Tests = (
        {
            Name   => 'check queue name (child)',
            Text   => '<KIX_QUEUE_Name>',
            Result => $ChildName
        },
        {
            Name   => 'check queue fullname (child)',
            Text   => '<KIX_QUEUE_FullName>',
            Result => $GrandparentName . q{::} . $ParentName . q{::} . $ChildName
        },
        {
            Name   => 'check follow up (child)',
            Text   => '<KIX_QUEUE_FollowUp>',
            Result => $FollowUp
        },
        {
            Name   => 'check follow up lock (child)',
            Text   => '<KIX_QUEUE_FollowUpLock>',
            Result => 'No'
        },
        {
            Name   => 'check parent id (child)',
            Text   => '<KIX_QUEUE_ParentID>',
            Result => $ParentQueueID
        },
        {
            Name   => 'check parent (child - only parent, no grandparent)',
            Text   => '<KIX_QUEUE_Parent>',
            Result => $ParentName
        },
        {
            Name   => 'check parent fullname (child)',
            Text   => '<KIX_QUEUE_ParentFullName>',
            Result => $ParentFullname
        },
        {
            Name   => 'check signature (child)',
            Text   => '<KIX_QUEUE_Signature>',
            Result => $ChildSignatureResult
        },
    );
    for my $Test ( @Tests ) {
        my $Result = $Kernel::OM->Get('TemplateGenerator')->_Replace(
            Text       => $Test->{Text},
            ObjectType => 'Ticket',
            ObjectID   => $TicketID,
            UserID     => 1,
            Language   => $Test->{German} ? 'de' : 'en'
        );
        $Self->Is(
            $Result,
            $Test->{Result},
            "$Test->{Name}:"
        );
    }
}

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
