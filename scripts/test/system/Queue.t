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

use vars (qw($Self));

use Kernel::System::VariableCheck qw(:all);

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Config');
my $QueueObject  = $Kernel::OM->Get('Queue');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $QueueRand = 'Some::Queue' . $Helper->GetRandomID();
my $QueueID   = $QueueObject->QueueAdd(
    Name            => $QueueRand,
    ValidID         => 1,
    GroupID         => 1,
    SystemAddressID => 1,
    UserID          => 1,
    Comment         => 'Some Comment',
);

$Self->True(
    $QueueID,
    "QueueAdd() - $QueueRand, $QueueID",
);

my @IDs;

push( @IDs, $QueueID );

my $QueueIDWrong = $QueueObject->QueueAdd(
    Name            => $QueueRand,
    ValidID         => 1,
    GroupID         => 1,
    SystemAddressID => 1,
    UserID          => 1,
    Comment         => 'Some Comment',
    Silent          => 1,
);

$Self->False(
    $QueueIDWrong,
    'QueueAdd() - Try to add new queue with existing queue name',
);

my %QueueGet = $QueueObject->QueueGet( ID => $QueueID );

$Self->True(
    $QueueGet{Name} eq $QueueRand,
    'QueueGet() - Name',
);
$Self->True(
    $QueueGet{ValidID} eq 1,
    'QueueGet() - ValidID',
);
$Self->True(
    $QueueGet{Comment} eq 'Some Comment',
    'QueueGet() - Comment',
);

my $Queue = $QueueObject->QueueLookup( QueueID => $QueueID );

$Self->True(
    $Queue eq $QueueRand,
    'QueueLookup() by ID',
);

my $QueueIDLookup = $QueueObject->QueueLookup( Queue => $Queue );

$Self->True(
    $QueueID eq $QueueIDLookup,
    'QueueLookup() by Name',
);

# a real scenario from AdminQueue.pm
# for more information see 3139
my $QueueUpdate2 = $QueueObject->QueueUpdate(
    QueueID         => $QueueID,
    Name            => $QueueRand . "2",
    ValidID         => 1,
    GroupID         => 1,
    SystemAddressID => 1,
    FollowUpID      => 1,
    UserID          => 1,
    Comment         => 'Some Comment2',
    DefaultSignKey  => '',
    UnlockTimeOut   => '',
    FollowUpLock    => 1,
    ParentQueueID   => '',
);

$Self->True(
    $QueueUpdate2,
    'QueueUpdate() - a real scenario from AdminQueue.pm',
);

my $QueueUpdate1Name = $QueueRand . '1',;
my $QueueUpdate1     = $QueueObject->QueueUpdate(
    QueueID         => $QueueID,
    Name            => $QueueUpdate1Name,
    ValidID         => 2,
    GroupID         => 1,
    SystemAddressID => 1,
    FollowUpID      => 1,
    UserID          => 1,
    Comment         => 'Some Comment1',
);

$Self->True(
    $QueueUpdate1,
    'QueueUpdate()',
);

#add another queue for testing update queue with existing name
my $Queue2Rand = 'Some::Queue2' . $Helper->GetRandomID();
my $QueueID2   = $QueueObject->QueueAdd(
    Name            => $Queue2Rand,
    ValidID         => 1,
    GroupID         => 1,
    SystemAddressID => 1,
    UserID          => 1,
    Comment         => 'Some Comment',
);

$Self->True(
    $QueueID2,
    "QueueAdd() - $Queue2Rand, $QueueID2",
);

push( @IDs, $QueueID2 );

#add subqueue
my $SubQueueName = '::SubQueue' . $Helper->GetRandomID();
my $SubQueue1    = $Queue2Rand . $SubQueueName;
my $QueueID3     = $QueueObject->QueueAdd(
    Name            => $SubQueue1,
    ValidID         => 1,
    GroupID         => 1,
    SystemAddressID => 1,
    UserID          => 1,
    Comment         => 'Some Comment',
);

$Self->True(
    $QueueID3,
    "QueueAdd() - $SubQueue1, $QueueID3",
);

push( @IDs, $QueueID3 );

#add subqueue with name that exists in another parent queue
my $SubQueue2 = $QueueUpdate1Name . $SubQueueName;
my $QueueID4  = $QueueObject->QueueAdd(
    Name            => $SubQueue2,
    ValidID         => 1,
    GroupID         => 1,
    SystemAddressID => 1,
    UserID          => 1,
    Comment         => 'Some Comment',
);

$Self->True(
    $QueueID4,
    "QueueAdd() - $SubQueue2, $QueueID4",
);

push( @IDs, $QueueID4 );

#add subqueue with name that exists in the same parent queue
$QueueIDWrong = $QueueObject->QueueAdd(
    Name            => $SubQueue2,
    ValidID         => 1,
    GroupID         => 1,
    SystemAddressID => 1,
    UserID          => 1,
    Comment         => 'Some Comment',
    Silent          => 1,
);

$Self->False(
    $QueueIDWrong,
    "QueueAdd() - $SubQueue2",
);

#try to update subqueue with existing name
my $QueueUpdateExist = $QueueObject->QueueUpdate(
    Name            => $SubQueue1,
    QueueID         => $QueueID4,
    ValidID         => 1,
    GroupID         => 1,
    SystemAddressID => 1,
    FollowUpID      => 1,
    UserID          => 1,
    Comment         => 'Some Comment1',
    Silent          => 1,
);

$Self->False(
    $QueueUpdateExist,
    "QueueUpdate() - update subqueue with existing name",
);

#try to update queue with existing name
$QueueUpdateExist = $QueueObject->QueueUpdate(
    Name            => $QueueRand . '1',
    QueueID         => $QueueID2,
    ValidID         => 1,
    GroupID         => 1,
    SystemAddressID => 1,
    FollowUpID      => 1,
    UserID          => 1,
    Comment         => 'Some Comment1',
    Silent          => 1,
);

$Self->False(
    $QueueUpdateExist,
    "QueueUpdate() - update queue with existing name",
);

# check function NameExistsCheck()
# check does it exist a queue with certain Name or
# check is it possible to set Name for queue with certain ID
my $Exist = $QueueObject->NameExistsCheck(
    Name => $Queue2Rand,
);

$Self->True(
    $Exist,
    "NameExistsCheck() - A queue with \'$Queue2Rand\' already exists!",
);

# there is a queue with certain name, now check if there is another one
$Exist = $QueueObject->NameExistsCheck(
    Name => "$Queue2Rand",
    ID   => $QueueID2,
);

$Self->False(
    $Exist,
    "NameExistsCheck() - Another queue \'$Queue2Rand\' for ID=$QueueID2 does not exists!",
);

$Exist = $QueueObject->NameExistsCheck(
    Name => $Queue2Rand,
    ID   => $QueueID,
);

$Self->True(
    $Exist,
    "NameExistsCheck() - Another queue \'$Queue2Rand\' for ID=$QueueID already exists!",
);

#check for subqueue
$Exist = $QueueObject->NameExistsCheck(
    Name => $SubQueue2,
);

$Self->True(
    $Exist,
    "NameExistsCheck() - Another subqueue \'$SubQueue2\' already exists!",
);

$Exist = $QueueObject->NameExistsCheck(
    Name => $SubQueue2,
    ID   => $QueueID4,
);

$Self->False(
    $Exist,
    "NameExistsCheck() - Another subqueue \'$SubQueue2\' for ID=$QueueID4 does not exists!",
);

$Exist = $QueueObject->NameExistsCheck(
    Name => $SubQueue2,
    ID   => $QueueID3,
);

$Self->True(
    $Exist,
    "NameExistsCheck() - Another subqueue \'$SubQueue2\' for ID=$QueueID3 already exists!",
);

# check is there a queue whose name has been updated in the meantime
$Exist = $QueueObject->NameExistsCheck(
    Name => $QueueRand,
);

$Self->False(
    $Exist,
    "NameExistsCheck() - A queue with \'$QueueRand\' does not exists!",
);

$Exist = $QueueObject->NameExistsCheck(
    Name => $QueueRand,
    ID   => $QueueID,
);

$Self->False(
    $Exist,
    "NameExistsCheck() - Another queue \'$QueueRand\' for ID=$QueueID does not exists!",
);

# lookup the queue name for $QueueID
my $LookupQueueName = $QueueObject->QueueLookup( QueueID => $QueueID );

$Self->Is(
    $LookupQueueName,
    $QueueRand . '1',
    "QueueLookup() - lookup the queue name for ID $QueueID",
);

# lookup the queue id for $QueueRand . '1'
my $LookupQueueID = $QueueObject->QueueLookup( Queue => $QueueRand . '1' );

$Self->Is(
    $LookupQueueID,
    $QueueID,
    "QueueLookup() - lookup the queue ID for queue name " . $QueueRand . '1',
);

# lookup the queue id for $QueueRand, this should be undef, because this queue was renamed meanwhile!
$LookupQueueID = $QueueObject->QueueLookup(
    Queue  => $QueueRand,
    Silent => 1,
);

$Self->Is(
    $LookupQueueID,
    undef,
    "QueueLookup() - lookup the queue ID for queue name " . $QueueRand,
);

%QueueGet = $QueueObject->QueueGet( ID => $QueueID );

$Self->True(
    $QueueGet{Name} eq $QueueRand . "1",
    'QueueGet() - Name',
);
$Self->True(
    $QueueGet{ValidID} eq 2,
    'QueueGet() - ValidID',
);
$Self->True(
    $QueueGet{Comment} eq 'Some Comment1',
    'QueueGet() - Comment',
);

$Queue = $QueueObject->QueueLookup( QueueID => $QueueID );

$Self->True(
    $Queue eq $QueueRand . "1",
    'QueueLookup() by ID',
);

$QueueIDLookup = $QueueObject->QueueLookup( Queue => $Queue );

$Self->True(
    $QueueID eq $QueueIDLookup,
    'QueueLookup() by Name',
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
