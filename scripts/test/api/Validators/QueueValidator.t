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

use Kernel::API::Validator::QueueValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::QueueValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $ValidData = {
    Queue => 'Junk'
};

my $InvalidData = {
    Queue => 'Junk-test'
};

my $ValidData_ID = {
    QueueID => '1'
};

my $InvalidData_ID = {
    QueueID => '9999'
};

# validate valid Queue
my $Result = $ValidatorObject->Validate(
    Attribute => 'Queue',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid Queue',
);

# validate invalid Queue
$Result = $ValidatorObject->Validate(
    Attribute => 'Queue',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid Queue',
);

# validate valid QueueID
$Result = $ValidatorObject->Validate(
    Attribute => 'QueueID',
    Data      => $ValidData_ID,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid QueueID',
);

# validate invalid QueueID
$Result = $ValidatorObject->Validate(
    Attribute => 'QueueID',
    Data      => $InvalidData_ID,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid QueueID',
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
