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

use Kernel::API::Validator::MimeTypeValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::MimeTypeValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $ValidData = {
    MimeType => 'application/json'
};

my $InvalidData = {
    MimeType => 'invalid-MimeType'
};

# validate valid MimeType
my $Result = $ValidatorObject->Validate(
    Attribute => 'MimeType',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid MimeType',
);

# validate invalid MimeType
$Result = $ValidatorObject->Validate(
    Attribute => 'MimeType',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid MimeType',
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
