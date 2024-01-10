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

use Kernel::API::Validator::CharsetValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::CharsetValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $ValidData = {
    Charset => 'utf8'
};

my $ValidDataAlias = {
    Charset => 'utf-8'
};

my $InvalidData = {
    Charset => 'invalid-charset'
};

# validate valid Charset
my $Result = $ValidatorObject->Validate(
    Attribute => 'Charset',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid Charset',
);

# validate valid Charset alias
$Result = $ValidatorObject->Validate(
    Attribute => 'Charset',
    Data      => $ValidDataAlias,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid Charset alias',
);

# validate invalid Charset
$Result = $ValidatorObject->Validate(
    Attribute => 'Charset',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid Charset',
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
