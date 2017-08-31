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
use Kernel::API::Validator::ServiceValidator;

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
my $ValidatorObject = Kernel::API::Validator::ServiceValidator->new(
    DebuggerObject => $DebuggerObject
);

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# create service
my $ServiceID = $Kernel::OM->Get('Kernel::System::Service')->ServiceAdd(
    Name        => 'TestService-Unittest',
    ValidID     => 1,
    Criticality => '3 normal',
    TypeID      => 10,
    UserID      => 1,
);

my $ValidData = {
    Service => 'TestService-Unittest'
};

my $InvalidData = {
    Service => 'TestService-Unittest_invalid'
};

my $ValidData_ID = {
    ServiceID => $ServiceID
};

my $InvalidData_ID = {
    ServiceID => '-9999'
};

# validate valid Service
my $Result = $ValidatorObject->Validate(
    Attribute => 'Service',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid Service',
);

# validate invalid Service
$Result = $ValidatorObject->Validate(
    Attribute => 'Service',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid Service',
);

# validate valid ServiceID
$Result = $ValidatorObject->Validate(
    Attribute => 'ServiceID',
    Data      => $ValidData_ID,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid ServiceID',
);

# validate invalid ServiceID
$Result = $ValidatorObject->Validate(
    Attribute => 'ServiceID',
    Data      => $InvalidData_ID,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid ServiceID',
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
