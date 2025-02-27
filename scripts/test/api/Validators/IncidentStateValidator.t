# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Validator::IncidentStateValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::IncidentStateValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $ItemData = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::Core::IncidentState',
    Name  => 'Incident',
);

my $ValidData = {
    InciStateID => $ItemData->{ItemID},
};

my $InvalidData = {
    InciStateID => '9999'
};

# validate valid InciStateID
my $Result = $ValidatorObject->Validate(
    Attribute => 'InciStateID',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid InciStateID',
);

# validate invalid InciStateID
$Result = $ValidatorObject->Validate(
    Attribute => 'InciStateID',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid InciStateID',
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
