# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Debugger;
use Kernel::API::Validator::SLAValidator;

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
my $ValidatorObject = Kernel::API::Validator::SLAValidator->new(
    DebuggerObject => $DebuggerObject
);

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# create SLA
my $SLAID = $Kernel::OM->Get('Kernel::System::SLA')->SLAAdd(
        Name    => 'TestSLA-Unittest',
        ValidID => 1,
        TypeID  => 10,
        UserID  => 1,
);

my $ValidData = {
    SLA => 'TestSLA-Unittest'
};

my $InvalidData = {
    SLA => 'TestSLA-Unittest_invalid'
};

my $ValidData_ID = {
    SLAID => $SLAID
};

my $InvalidData_ID = {
    SLAID => '-9999'
};

# validate valid SLA
my $Result = $ValidatorObject->Validate(
    Attribute => 'SLA',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid SLA',
);

# validate invalid SLA
$Result = $ValidatorObject->Validate(
    Attribute => 'SLA',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid SLA',
);

# validate valid SLAID
$Result = $ValidatorObject->Validate(
    Attribute => 'SLAID',
    Data      => $ValidData_ID,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid SLAID',
);

# validate invalid SLAID
$Result = $ValidatorObject->Validate(
    Attribute => 'SLAID',
    Data      => $InvalidData_ID,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid SLAID',
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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
