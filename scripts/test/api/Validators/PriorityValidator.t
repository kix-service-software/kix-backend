# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Validator::PriorityValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::PriorityValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $ValidData = {
    Priority => '3 normal'
};

my $InvalidData = {
    Priority => 'invalid'
};

my $ValidData_ID = {
    PriorityID => '1'
};

my $InvalidData_ID = {
    PriorityID => '9999'
};

# validate valid Priority
my $Result = $ValidatorObject->Validate(
    Attribute => 'Priority',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid Priority',
);

# validate invalid Priority
$Result = $ValidatorObject->Validate(
    Attribute => 'Priority',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid Priority',
);

# validate valid PriorityID
$Result = $ValidatorObject->Validate(
    Attribute => 'PriorityID',
    Data      => $ValidData_ID,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid PriorityID',
);

# validate invalid PriorityID
$Result = $ValidatorObject->Validate(
    Attribute => 'PriorityID',
    Data      => $InvalidData_ID,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid PriorityID',
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
