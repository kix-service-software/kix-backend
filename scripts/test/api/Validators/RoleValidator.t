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

use Kernel::API::Validator::RoleValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::RoleValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $RoleRandom = 'testrole' . $Helper->GetRandomID();

# create role
my $RoleID = $Kernel::OM->Get('Role')->RoleAdd(
    Name         => $RoleRandom,
    UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    ValidID      => 1,
    UserID       => 1,
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
$Result = $ValidatorObject->Validate(
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
$Result = $ValidatorObject->Validate(
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
$Result = $ValidatorObject->Validate(
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
