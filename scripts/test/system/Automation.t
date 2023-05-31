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

# get Job object
my $AutomationObject = $Kernel::OM->Get('Automation');

#
# log tests
#

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# create test job
my $JobName  = 'job-'.$Helper->GetRandomID();

my $JobID = $AutomationObject->JobAdd(
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

my $MacroID = $AutomationObject->MacroAdd(
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
$Result = $AutomationObject->LogError();

$Self->False(
    $Result,
    'LogError() without parameters',
);

# no UserID
$Result = $AutomationObject->LogError(Message => 'test');

$Self->False(
    $Result,
    'LogError() without UserID',
);

# no Message
$Result = $AutomationObject->LogError(UserID => 1);

$Self->False(
    $Result,
    'LogError() without Message',
);

# with Message and UserID
$Result = $AutomationObject->LogError(
    Message => 'test',
    UserID => 1
);

$Self->True(
    $Result,
    'LogError() with Message and UserID',
);

# with Referrer (JobID)
$Result = $AutomationObject->LogError(
    Referrer => {
        JobID => $JobID,
    },
    Message => 'Test',
    UserID => 1
);

$Self->True(
    $Result,
    'LogError() without Referrer (JobID)',
);

# with Referrer (JobID+MacroID)
$Result = $AutomationObject->LogError(
    Referrer => {
        JobID   => $JobID,
        MacroID => $MacroID,
    },
    Message => 'Test',
    UserID => 1
);

$Self->True(
    $Result,
    'LogError() without Referrer (JobID+MacroID)',
);

# cleanup is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
