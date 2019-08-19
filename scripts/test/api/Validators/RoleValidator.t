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
use Kernel::API::Validator::RoleValidator;

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
my $ValidatorObject = Kernel::API::Validator::RoleValidator->new(
    DebuggerObject => $DebuggerObject
);

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my $RoleRandom = 'testrole' . $Helper->GetRandomID();

# create role
my $RoleID = $Kernel::OM->Get('Kernel::System::Role')->RoleAdd(
    Name    => $RoleRandom,
    ValidID => 1,
    UserID  => 1,
);

# validate valid RoleID
# run test for each supported attribute
my $Result = $ValidatorObject->Validate(
    Attribute => 'RoleID',
    Data      => {
        'RoleID' => $RoleID,
    }
);

$Self->True(
    $Result->{Success},
    "Validate() - valid RoleID",
);

# validate invalid RoleID
my $Result = $ValidatorObject->Validate(
    Attribute => 'RoleID',
    Data      => {
        'RoleID' => -9999,
    }
);

$Self->False(
    $Result->{Success},
    "Validate() - invalid RoleID",
);

# validate valid Role
# run test for each supported attribute
my $Result = $ValidatorObject->Validate(
    Attribute => 'Role',
    Data      => {
        'Role' => $RoleRandom,
    }
);

$Self->True(
    $Result->{Success},
    "Validate() - valid Role",
);

# validate invalid Role
# run test for each supported attribute
my $Result = $ValidatorObject->Validate(
    Attribute => 'Role',
    Data      => {
        'Role' => '____test____',
    }
);

$Self->False(
    $Result->{Success},
    "Validate() - invalid Role",
);

# validate invalid attribute
my $Result = $ValidatorObject->Validate(
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
