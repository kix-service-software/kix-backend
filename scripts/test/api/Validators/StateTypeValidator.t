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

use Kernel::API::Validator::StateTypeValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::StateTypeValidator->new();

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $ValidData = {
    Type => 'open'
};

my $InvalidData = {
    Type => 'Unclassified-unittest'
};

my $ValidData_ID = {
    TypeID => '1'
};

my $InvalidData_ID = {
    TypeID => '9999'
};

# validate valid Type
my $Result = $ValidatorObject->Validate(
    Attribute => 'Type',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid Type',
);

# validate invalid Type
$Result = $ValidatorObject->Validate(
    Attribute => 'Type',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid Type',
);

# validate valid TypeID
$Result = $ValidatorObject->Validate(
    Attribute => 'TypeID',
    Data      => $ValidData_ID,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid TypeID',
);

# validate invalid TypeID
$Result = $ValidatorObject->Validate(
    Attribute => 'TypeID',
    Data      => $InvalidData_ID,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid TypeID',
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
