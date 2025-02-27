# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# create test job
my $JobName  = 'job-'.$Helper->GetRandomID();

my $JobID = $Kernel::OM->Get('Automation')->JobAdd(
    Name    => $JobName,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $JobID,
    'JobAdd() for new job ' . $JobName,
);

# create test macro
my $MacroName  = 'macro-'.$Helper->GetRandomID();

my $MacroID = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => $MacroName,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $MacroID,
    'MacroAdd() for new macro ' . $MacroName,
);

my $Result;

# no parameters
$Result = $Kernel::OM->Get('Automation')->LogError(
    Silent => 1,
);

$Self->False(
    $Result,
    'LogError() without parameters',
);

# no UserID
$Result = $Kernel::OM->Get('Automation')->LogError(
    Message => 'test',
    Silent  => 1,
);

$Self->False(
    $Result,
    'LogError() without UserID',
);

# no Message
$Result = $Kernel::OM->Get('Automation')->LogError(
    UserID => 1,
    Silent => 1,
);

$Self->False(
    $Result,
    'LogError() without Message',
);

# with Message and UserID
$Result = $Kernel::OM->Get('Automation')->LogError(
    Message => 'test',
    UserID  => 1,
    Silent  => 1,
);

$Self->True(
    $Result,
    'LogError() with Message and UserID',
);

# with Referrer (JobID)
$Result = $Kernel::OM->Get('Automation')->LogError(
    Referrer => {
        JobID => $JobID,
    },
    Message => 'Test',
    UserID  => 1,
    Silent  => 1,
);

$Self->True(
    $Result,
    'LogError() without Referrer (JobID)',
);

# with Referrer (JobID+MacroID)
$Result = $Kernel::OM->Get('Automation')->LogError(
    Referrer => {
        JobID   => $JobID,
        MacroID => $MacroID,
    },
    Message => 'Test',
    UserID  => 1,
    Silent  => 1,
);

$Self->True(
    $Result,
    'LogError() without Referrer (JobID+MacroID)',
);

# check logging
foreach my $MinimumLogLevel ( qw( error notice info debug) ) {
    # set in Config
    my $Success = $Kernel::OM->Get('Config')->Set(
        Key   => 'Automation::MinimumLogLevel',
        Value => $MinimumLogLevel,
    );
    $Self->True(
        $Success,
        "Set Automation::MinimumLogLevel to \"$MinimumLogLevel\"",
    );

    # discard object after changing minimum log level
    $Kernel::OM->ObjectsDiscard(
        Objects => ['Automation'],
    );

    my $MinimumLogLevel = $Kernel::OM->Get('Config')->Get('Automation::MinimumLogLevel') || 'error';
    my $MinimumLogLevelNum = $Kernel::OM->Get('Log')->GetNumericLogLevel( Priority => $MinimumLogLevel);

    foreach my $Priority ( qw( error notice info debug) ) {

        my $LogCountBefore = $Kernel::OM->Get('Automation')->GetLogCount();

        my $PriorityNum = $Kernel::OM->Get('Log')->GetNumericLogLevel( Priority => $Priority );

        my $Result = $Kernel::OM->Get('Automation')->_Log(
            Message  => "logging with priority \"$Priority\" and MinLogLevel \"$MinimumLogLevel\"",
            Priority => $Priority,
            UserID   => 1,
        );
        $Self->True(
            $Result,
            "_Log() with priority \"$Priority\" returns 1",
        );

        my $LogCount = $Kernel::OM->Get('Automation')->GetLogCount();

        if ( $PriorityNum >= $MinimumLogLevelNum ) {
            $Self->True(
                $LogCount - $LogCountBefore,
                "_Log() with priority \"$Priority\" created log entry",
            );
        }
        else {
            $Self->False(
                $LogCount - $LogCountBefore,
                "_Log() with priority \"$Priority\" created no log entry",
            );
        }
    }
}

my @ObjectIDTests = (
    {
        Test     => 'ObjectIDIsScalar',
        ObjectID => 'ObjectIDIsScalar',
    },
    {
        Test     => 'ObjectIDIsHashRef',
        ObjectID => {
            WhatIsIt => 'ObjectIDIsHashRef'
        },
    },
    {
        Test     => 'ObjectIDIsArrayRef',
        ObjectID => [
            'ObjectIDIsArrayRef'
        ]
    }
);
foreach my $Test ( @ObjectIDTests ) {
    my $Result = $Kernel::OM->Get('Automation')->_Log(
        Message  => "executing logging test \"$Test->{Test}\"",
        Priority => 'error',
        UserID   => 1,
        Referrer => {
            ObjectID => $Test->{ObjectID}
        }
    );
    $Self->True(
        $Result,
        "logging test \"$Test->{Test}\" returns 1",
    );

    # check log entry
    $Result = $Kernel::OM->Get('DB')->Prepare(
        SQL   => 'SELECT object_id FROM automation_log ORDER BY id DESC',
        Limit => 1,
    );
    $Self->True(
        $Result,
        "Prepare to get log entry from DB",
    );

    my $ObjectIDString = $Test->{ObjectID};
    if ( IsHashRef($Test->{ObjectID}) || IsArrayRef($Test->{ObjectID}) ) {
        $ObjectIDString = $Kernel::OM->Get('JSON')->Encode(
            Data => $Test->{ObjectID},
        );
    }

    my $Data = $Kernel::OM->Get('DB')->FetchAllArrayRef(
        Columns => [ 'ObjectID' ],
    );
    $Self->Is(
        $Data->[0]->{ObjectID},
        $ObjectIDString,
        "logged ObjectID",
    );

    # data found...
    my @Result;
    if ( IsArrayRefWithData($Data) ) {
        @Result = @{$Data};
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
