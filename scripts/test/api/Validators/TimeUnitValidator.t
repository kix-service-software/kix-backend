# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Debugger;
use Kernel::API::Validator::TimeUnitValidator;

my $DebuggerObject = Kernel::API::Debugger->new(
    DebuggerConfig   => {
        DebugThreshold  => 'debug',
        TestMode        => 1,
    },
    WebserviceID      => 1,
    CommunicationType => 'Provider',
    RemoteIP          => 'localhost',
);

# get validator object
my $ValidatorObject = Kernel::API::Validator::TimeUnitValidator->new(
    DebuggerObject => $DebuggerObject
);

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my %ValidData = (
    '#01 integer' => '10',
    '#02 float with dot' => '10.0',
    '#03 float with comma' => '10,0',
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
