# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Debugger;
use Kernel::API::Validator::ExecPlanValidator;

# get ExecPlan object
my $AutomationObject = $Kernel::OM->Get('Kernel::System::Automation');

my $DebuggerObject = Kernel::API::Debugger->new(
    DebuggerConfig   => {
        DebugThreshold  => 'debug',
        TestMode        => 1,
    },
    WebserviceID      => 1,
    CommunicationType => 'Provider',
    RemoteIP          => 'localhost',
);

# get validator object
my $ValidatorObject = Kernel::API::Validator::ExecPlanValidator->new(
    DebuggerObject => $DebuggerObject
);

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my $NameRandom  = $Helper->GetRandomID();

# add exec plan
my $ExecPlanID = $AutomationObject->ExecPlanAdd(
    Name    => 'execplan-'.$NameRandom,
    Type    => 'TimeBased',
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $ExecPlanID,
    'ExecPlanAdd() for new execution plan',
);

my $ValidData = {
    ExecPlanID => $ExecPlanID
};

my $InvalidData = {
    ExecPlanID => 9999
};

# validate valid ExecPlanID
my $Result = $ValidatorObject->Validate(
    Attribute => 'ExecPlanID',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid ExecPlanID',
);

# validate invalid ExecPlanID
$Result = $ValidatorObject->Validate(
    Attribute => 'ExecPlanID',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid ExecPlanID',
);

# validate invalid attribute
$Result = $ValidatorObject->Validate(
    Attribute => 'InvalidAttribute',
    Data      => {},
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid attribute',
);

# cleanup is done by RestoreDatabase.

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
