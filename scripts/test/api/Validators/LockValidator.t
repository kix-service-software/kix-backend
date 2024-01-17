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

use Kernel::API::Validator::LockValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::LockValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $ValidData = {
    Lock => 'lock'
};

my $InvalidData = {
    Lock => 'lock123-test'
};

my $ValidData_ID = {
    LockID => '1'
};

my $InvalidData_ID = {
    LockID => '9999'
};

# validate valid Lock
my $Result = $ValidatorObject->Validate(
    Attribute => 'Lock',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid Lock',
);

# validate invalid Lock
$Result = $ValidatorObject->Validate(
    Attribute => 'Lock',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid Lock',
);

# validate valid LockID
$Result = $ValidatorObject->Validate(
    Attribute => 'LockID',
    Data      => $ValidData_ID,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid LockID',
);

# validate invalid LockID
$Result = $ValidatorObject->Validate(
    Attribute => 'LockID',
    Data      => $InvalidData_ID,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid LockID',
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

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
