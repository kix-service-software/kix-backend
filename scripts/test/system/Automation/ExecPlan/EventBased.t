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

# get ExecPlan object
my $AutomationObject = $Kernel::OM->Get('Automation');

#
# ExecPlan tests
#

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $NameRandom  = $Helper->GetRandomID();

# get current time
my ($Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay) = $Kernel::OM->Get('Time')->SystemTime2Date(
    SystemTime => $Kernel::OM->Get('Time')->SystemTime()
);

# test data
my @TestData = (
    {
        Test              => 'non-relevant event',
        Event             => 'ArticleCreate',
        ExpectedResult    => 0
    },
    {
        Test              => 'relevant event',
        Event             => 'TicketCreate',
        ExpectedResult    => 1
    },
);

# add valid timebased execplan
my $ExecPlanID = $AutomationObject->ExecPlanAdd(
    Name       => 'execplan-eventbased-'.$NameRandom,
    Type       => 'EventBased',
    Parameters => {
        Event => [
            'DynamicFieldUpdate',
            'TicketCreate',
        ]
    },
    ValidID    => 1,
    UserID     => 1,
);

$Self->True(
    $ExecPlanID,
    'ExecPlanAdd() for new execution plan',
);

# add job
my $JobID = $AutomationObject->JobAdd(
    Name       => 'job-'.$NameRandom,
    Type       => 'Ticket',
    ValidID    => 1,
    UserID     => 1,
);

$Self->True(
    $JobID,
    'JobAdd() for new job',
);

# check different times
foreach my $Test ( @TestData ) {
    my $CanExecute = $AutomationObject->ExecPlanCheck(
        %{$Test},
        ID      => $ExecPlanID,
        JobID   => $JobID,
        UserID  => 1,
    );

    $Self->Is(
        $CanExecute,
        $Test->{ExpectedResult},
        'ExecPlanCheck() for '.$Test->{Test},
    );
}

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
