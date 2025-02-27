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

use Kernel::API::Validator::TimeUnitValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::TimeUnitValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my %ValidData = (
    '#01 integer' => '10',
    '#02 negative integer' => '-10',
    '#03 zero' => '0',
#    '#04 float with dot' => '10.0',
#    '#05 float with comma' => '10,0'
);

my %InvalidData = (
    '#01 string' => 'abc',
    '#02 float with dot and comma' => '10.,0',
    '#03 float with double dot' => '10.10.0',
    '#04 float with double comma' => '10,10,0',
    '#05 float with dot and comma separated' => '10.10,0',
);

# validate valid TimeUnit
foreach my $TestID ( sort keys %ValidData ) {
    my $Result = $ValidatorObject->Validate(
        Attribute => 'TimeUnit',
        Data      => {
            'TimeUnit' => $ValidData{$TestID},
        }
    );

    $Self->True(
        $Result->{Success},
        "Validate() - valid TimeUnit - $TestID",
    );
}

# validate invalid TimeUnit
foreach my $TestID ( sort keys %InvalidData ) {
    my $Result = $ValidatorObject->Validate(
        Attribute => 'TimeUnit',
        Data      => {
            'TimeUnit' => $InvalidData{$TestID},
        }
    );

    $Self->False(
        $Result->{Success},
        "Validate() - invalid TimeUnit - $TestID",
    );
}

# validate invalid attribute
my $Result = $ValidatorObject->Validate(
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
