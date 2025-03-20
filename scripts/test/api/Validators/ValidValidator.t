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

use Kernel::API::Validator::ValidValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::ValidValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $ValidData = {
    Valid => 'valid'
};

my $InvalidData = {
    Valid => 'valid-unittest'
};

my $ValidData_ID = {
    ValidID => '1'
};

my $InvalidData_ID = {
    ValidID => '9999'
};

# validate valid Valid
my $Result = $ValidatorObject->Validate(
    Attribute => 'Valid',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid Valid',
);

# validate invalid Valid
$Result = $ValidatorObject->Validate(
    Attribute => 'Valid',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid Valid',
);

# validate valid ValidID
$Result = $ValidatorObject->Validate(
    Attribute => 'ValidID',
    Data      => $ValidData_ID,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid ValidID',
);

# validate invalid ValidID
$Result = $ValidatorObject->Validate(
    Attribute => 'ValidID',
    Data      => $InvalidData_ID,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid ValidID',
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
