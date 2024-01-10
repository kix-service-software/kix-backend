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

use Kernel::API::Validator::ExecPlanValidator;

# get ExecPlan object
my $AutomationObject = $Kernel::OM->Get('Automation');

# get validator object
my $ValidatorObject = Kernel::API::Validator::ExecPlanValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $NameRandom  = $Helper->GetRandomID();

# add exec plan
my $ExecPlanID = $AutomationObject->ExecPlanAdd(
    Name    => 'execplan-'.$NameRandom,
    Type    => 'EventBased',
    Parameters => {
        Event => [ 'TicketCreate' ],
    },
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
