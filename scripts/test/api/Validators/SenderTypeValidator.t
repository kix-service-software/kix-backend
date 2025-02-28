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

use Kernel::API::Validator::SenderTypeValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::SenderTypeValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $ValidData = {
    SenderType => 'agent'
};

my $InvalidData = {
    SenderType => 'agent-test'
};

my $ValidData_ID = {
    SenderTypeID => '1'
};

my $InvalidData_ID = {
    SenderTypeID => '9999'
};

# validate valid SenderType
my $Result = $ValidatorObject->Validate(
    Attribute => 'SenderType',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid SenderType',
);

# validate invalid SenderType
$Result = $ValidatorObject->Validate(
    Attribute => 'SenderType',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid SenderType',
);

# validate valid SenderTypeID
$Result = $ValidatorObject->Validate(
    Attribute => 'SenderTypeID',
    Data      => $ValidData_ID,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid SenderTypeID',
);

# validate invalid SenderTypeID
$Result = $ValidatorObject->Validate(
    Attribute => 'SenderTypeID',
    Data      => $InvalidData_ID,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid SenderTypeID',
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
