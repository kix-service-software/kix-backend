# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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

# get state object
my $StateObject = $Kernel::OM->Get('State');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# add state
my $StateName = 'state' . $Helper->GetRandomID();
my $StateID   = $StateObject->StateAdd(
    Name    => $StateName,
    Comment => 'some comment',
    ValidID => 1,
    TypeID  => 1,
    UserID  => 1,
);

$Self->True(
    $StateID,
    'StateAdd()',
);

my %State = $StateObject->StateGet( ID => $StateID );

$Self->True(
    $State{Name} eq $StateName,
    'StateGet() - Name',
);
$Self->True(
    $State{Comment} eq 'some comment',
    'StateGet() - Comment',
);
$Self->True(
    $State{ValidID} eq 1,
    'StateGet() - ValidID',
);

my %StateList = $StateObject->StateList(
    UserID => 1,
);
$Self->True(
    exists $StateList{$StateID} && $StateList{$StateID} eq $StateName,
    'StateList() contains the state ' . $StateName . ' with ID ' . $StateID,
);

my $StateType = $StateObject->StateTypeLookup(
    StateTypeID => 1,
);

$Self->True(
    $StateType,
    'StateTypeLookup()',
);

my @List = $StateObject->StateGetStatesByType(
    StateType => [$StateType],
    Result    => 'ID',
);
$Self->True(
    ( grep { $_ eq $StateID } @List ),
    "StateGetStatesByType() contains the state $StateName with ID $StateID",
);

my $StateNameUpdate = $StateName . 'update';
my $StateUpdate     = $StateObject->StateUpdate(
    ID      => $StateID,
    Name    => $StateNameUpdate,
    Comment => 'some comment 1',
    ValidID => 2,
    TypeID  => 1,
    UserID  => 1,
);

$Self->True(
    $StateUpdate,
    'StateUpdate()',
);

%State = $StateObject->StateGet( ID => $StateID );

$Self->True(
    $State{Name} eq $StateNameUpdate,
    'StateGet() - Name',
);
$Self->True(
    $State{Comment} eq 'some comment 1',
    'StateGet() - Comment',
);
$Self->True(
    $State{ValidID} eq 2,
    'StateGet() - ValidID',
);

@List = $StateObject->StateGetStatesByType(
    StateType => [$StateType],
    Result    => 'ID',
);
$Self->True(
    ( grep { $_ ne $StateID } @List ),
    "StateGetStatesByType() does not contain the state $StateNameUpdate with ID $StateID",
);

my %StateTypeList = $StateObject->StateTypeList(
    UserID => 1,
);

$Self->True(
    ( grep { $_ eq 'new' } values %StateTypeList ),
    "StateGetStatesByType() does not contain the state 'new'",
);

$Self->True(
    ( grep { $_ eq 'open' } values %StateTypeList ),
    "StateGetStatesByType() does not contain the state 'open'",
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
