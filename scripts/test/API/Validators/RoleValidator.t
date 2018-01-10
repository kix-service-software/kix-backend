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

# create role
my $RoleID = $Kernel::OM->Get('Kernel::System::Group')->RoleAdd(
    Name    => 'testrole',
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
        'Role' => 'testrole',
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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
