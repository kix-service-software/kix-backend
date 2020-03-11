# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
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
use Kernel::API::Validator::StateValidator;

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
my $ValidatorObject = Kernel::API::Validator::StateValidator->new(
    DebuggerObject => $DebuggerObject
);

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my $ValidData = {
    State => 'open'
};

my $InvalidData = {
    State => 'open-unittest'
};

my $ValidData_ID = {
    StateID => '1'
};

my $InvalidData_ID = {
    StateID => '9999'
};

# validate valid State
my $Result = $ValidatorObject->Validate(
    Attribute => 'State',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid State',
);

# validate invalid State
$Result = $ValidatorObject->Validate(
    Attribute => 'State',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid State',
);

# validate valid StateID
$Result = $ValidatorObject->Validate(
    Attribute => 'StateID',
    Data      => $ValidData_ID,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid StateID',
);

# validate invalid StateID
$Result = $ValidatorObject->Validate(
    Attribute => 'StateID',
    Data      => $InvalidData_ID,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid StateID',
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
