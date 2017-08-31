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
use Kernel::API::Validator::CustomerValidator;

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
my $ValidatorObject = Kernel::API::Validator::CustomerValidator->new(
    DebuggerObject => $DebuggerObject
);

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# create customer contact
$Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserAdd(
    Source         => 'CustomerUser',
    UserFirstname  => 'ValidatorTestCustomer',
    UserLastname   => 'ValidatorTestCustomer',
    UserCustomerID => 'ValidatorTestCustomer',
    UserLogin      => 'ValidatorTestCustomer',
    UserEmail      => 'ValidatorTestCustomer@validatortest.kix',
    ValidID        => 1,
    UserID         => 1,
);

my $ValidData = {
    CustomerContact => 'ValidatorTestCustomer'
};

my $ValidData_Email = {
    CustomerContact => 'ValidatorTestCustomer@validatortest.kix'
};

my $InvalidData = {
    Customer => 'invalid-Customer'
};

# validate valid CustomerContact
my $Result = $ValidatorObject->Validate(
    Attribute => 'CustomerContact',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid CustomerContact',
);

# validate valid CustomerContact email
my $Result = $ValidatorObject->Validate(
    Attribute => 'CustomerContact',
    Data      => $ValidData_Email,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid CustomerContact (Email)',
);

# validate invalid CustomerContact
$Result = $ValidatorObject->Validate(
    Attribute => 'CustomerContact',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid CustomerContact',
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
