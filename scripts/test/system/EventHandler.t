# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

package main;

use vars (qw($Self));

use Kernel::System::VariableCheck qw(:all);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# load the sample modules via the ObjectManager (mirrors the
# AsynchronousExecutor.t pattern). Get() requires the module and returns
# an instance; each True() below is asserted in the test output so a
# missing/broken sample file fails early and visibly.
my $DieModule     = $Kernel::OM->Get('scripts::test::system::sample::EventHandler::Die');
my $RecordModule  = $Kernel::OM->Get('scripts::test::system::sample::EventHandler::Record');
my $ReEnterModule = $Kernel::OM->Get('scripts::test::system::sample::EventHandler::ReEnter');
my $TestObject    = $Kernel::OM->Get('scripts::test::system::sample::EventHandler::TestObject');

$Self->True( ref($DieModule),     'KIX-17493: Die sample module loaded' );
$Self->True( ref($RecordModule),  'KIX-17493: Record sample module loaded' );
$Self->True( ref($ReEnterModule), 'KIX-17493: ReEnter sample module loaded' );
$Self->True( ref($TestObject),    'KIX-17493: TestObject sample module loaded' );

# own config key - not aggregated, no collision with real settings.
# ConfigSettingChange() sets the in-memory value and marks SysConfigChanged;
# Rollback() rebuilds the config from SysConfig/XML, removing this key.
#
# Sort order matters: modules run in key order per event. Record must sort
# BEFORE Die, because the eval isolation in EventHandlerTransaction() works
# per event, not per module - a die() in one module aborts the remaining
# modules of the SAME event (but not the remaining events of the pipe).
$Helper->ConfigSettingChange(
    Key   => 'Test::EventHandler::EventModulePost',
    Value => {
        '010-Record'  => {
            Module      => 'scripts::test::system::sample::EventHandler::Record',
            Event       => '',
            Transaction => 1,
        },
        '020-ReEnter' => {
            Module      => 'scripts::test::system::sample::EventHandler::ReEnter',
            Event       => 'ReEnterFlush',
            Transaction => 1,
        },
        '030-Die'     => {
            Module      => 'scripts::test::system::sample::EventHandler::Die',
            Event       => 'DieFlush',
            Transaction => 1,
        },
    },
    Silent => 1
);

# init the standalone test object and wire the ReEnter handler to it
$TestObject->EventHandlerInit(
    Config => 'Test::EventHandler::EventModulePost',
);
$ReEnterModule->SetTestObject($TestObject);
$Self->True(
    $TestObject->can('EventHandlerTransaction'),
    'KIX-17493: TestObject is an EventHandler',
);

# sanity check: config is actually set
my $Modules = $Kernel::OM->Get('Config')->Get('Test::EventHandler::EventModulePost') || {};
$Self->True(
    IsHashRefWithData( $Modules->{'010-Record'} ),
    'KIX-17493: test config is set (Record module present)',
);

# =============================================================================
# Test D: Empty pipe flush
# =============================================================================
$Self->True(
    $TestObject->EventHandlerTransaction(),
    'KIX-17493: flush with empty pipe returns 1',
);
$Self->False(
    $TestObject->{EventHandlerTransaction},
    'KIX-17493: flag reset after empty pipe flush',
);

# =============================================================================
# Test B: HasQueuedTransactions reports 0 during flush
# =============================================================================
$TestObject->EventHandler(
    Event  => 'RecordFlush',
    Data   => { Test => 1 },
    UserID => 1,
);
$Self->True(
    $TestObject->EventHandlerHasQueuedTransactions(),
    'KIX-17493: HasQueuedTransactions is true with events in pipe',
);

# Simulate "flush is running" by setting the flag directly
$TestObject->{EventHandlerTransaction} = 1;
$Self->False(
    $TestObject->EventHandlerHasQueuedTransactions(),
    'KIX-17493: HasQueuedTransactions is false while flush is running',
);
# Restore
$TestObject->{EventHandlerTransaction} = 0;

# Clean up the queued event
$TestObject->EventHandlerTransaction();

# =============================================================================
# Test A: Re-Entrancy Guard (isolated)
# A handler calls EventHandlerTransaction() on the same object during
# the outer flush. The inner call must be a no-op; the outer flush
# continues with the remaining events.
# =============================================================================
$RecordModule->Reset();

# Queue two events
$TestObject->EventHandler(
    Event  => 'ReEnterFlush',
    Data   => { Test => 1 },
    UserID => 1,
);
$TestObject->EventHandler(
    Event  => 'ReEnterFlush',
    Data   => { Test => 1 },
    UserID => 1,
);

# Flush: Record runs + ReEnter (inner call = no-op), twice
$TestObject->EventHandlerTransaction();

$Self->Is(
    $RecordModule->CalledCount(),
    2,
    'KIX-17493: re-entrant flush is a no-op, outer flush processes all events',
);
$Self->False(
    $TestObject->{EventHandlerTransaction},
    'KIX-17493: flag reset after re-entrant flush',
);
$Self->False(
    defined $TestObject->{EventHandlerPipe},
    'KIX-17493: pipe empty after re-entrant flush',
);

# =============================================================================
# Test C: Multiple events, first handler dies, rest still run
# Expected log noise: 3x "Event handler failed for event 'DieFlush'"
# (the eval isolation working as intended).
# =============================================================================
$RecordModule->Reset();

# Queue three events
for ( 1 .. 3 ) {
    $TestObject->EventHandler(
        Event  => 'DieFlush',
        Data   => { Test => 1 },
        UserID => 1,
    );
}

$TestObject->EventHandlerTransaction();

# Without eval: first die aborts the for-loop, Record runs 0 times
$Self->Is(
    $RecordModule->CalledCount(),
    3,
    'KIX-17493: all events processed after handler failure in each',
);
$Self->False(
    $TestObject->{EventHandlerTransaction},
    'KIX-17493: flag reset after multi-event flush with failures',
);

# =============================================================================
# Test E: Practical scenario (KIX-17493)
#
# Mirrors the actual bug: a Ticket Template sets 3 Dynamic Fields
# (Supportcall, AffectedServices, AffectedAsset) simultaneously → 3 events
# are piped. An Automation Job (handler with Event => '' matching ALL events)
# runs CreateOrUpdateAsset which calls ObjectsDiscard(). ObjectsDiscard()
# calls EventHandlerTransaction() on ALL registered handlers, including the
# object whose flush is currently running.
#
# Without the fix: the re-entrant call re-iterates the pipe from index 0,
# re-executing already processed events → unlimited asset versions.
# With the fix: the re-entrant call is a no-op (flag guard), each event is
# processed exactly once.
# =============================================================================
$Helper->ConfigSettingChange(
    Key   => 'Test::EventHandler::EventModulePost',
    Value => {
        '010-ReEnter' => {
            # Simulates ObjectsDiscard: runs for ALL events (Event => '')
            # and triggers a re-entrant flush on the same object.
            Module      => 'scripts::test::system::sample::EventHandler::ReEnter',
            Event       => '',
            Transaction => 1,
        },
        '020-Record'  => {
            Module      => 'scripts::test::system::sample::EventHandler::Record',
            Event       => '',
            Transaction => 1,
        },
    },
    Silent => 1
);

$RecordModule->Reset();

# Queue 3 events (simulating Template: Supportcall + AffectedServices + AffectedAsset)
for my $EventName (qw(DF_Supportcall DF_AffectedServices DF_AffectedAsset)) {
    $TestObject->EventHandler(
        Event  => $EventName,
        Data   => { Test => 1 },
        UserID => 1,
    );
}

$TestObject->EventHandlerTransaction();

# Each event must be processed exactly once. Record runs once per event.
# Without the fix: re-entrant flush re-iterates the pipe → Record runs
# multiple times per event (or the loop never terminates).
$Self->Is(
    $RecordModule->CalledCount(),
    3,
    'KIX-17493 (practical): ObjectsDiscard during flush does not re-execute events',
);
$Self->False(
    $TestObject->{EventHandlerTransaction},
    'KIX-17493 (practical): flag reset after practical scenario',
);
$Self->False(
    defined $TestObject->{EventHandlerPipe},
    'KIX-17493 (practical): pipe empty after practical scenario',
);

# =============================================================================
# Final: object is back in normal mode (not stuck in transaction mode)
# =============================================================================
$TestObject->EventHandler(
    Event  => 'RecordFlush',
    Data   => { Test => 1 },
    UserID => 1,
);
$Self->True(
    IsArrayRefWithData( $TestObject->{EventHandlerPipe} ),
    'KIX-17493: object is in normal mode (event re-piped after all flush tests)',
);

# cleanup
$TestObject->EventHandlerTransaction();
$ReEnterModule->SetTestObject(undef);

# rollback transaction on database (also restores config via SysConfig rebuild)
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