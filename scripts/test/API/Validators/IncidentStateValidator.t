# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Debugger;
use Kernel::API::Validator::IncidentStateValidator;

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
my $ValidatorObject = Kernel::API::Validator::IncidentStateValidator->new(
    DebuggerObject => $DebuggerObject
);

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my $ItemData = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemGet(
    Class => 'ITSM::Core::IncidentState',
    Name  => 'Incident',
);

my $ValidData = {
    IncidentStateID => $ItemData->{ItemID},
};

my $InvalidData = {
    IncidentStateID => '99999999999999999'
};

# validate valid IncidentStateID
my $Result = $ValidatorObject->Validate(
    Attribute => 'IncidentStateID',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid IncidentStateID',
);

# validate invalid IncidentStateID
$Result = $ValidatorObject->Validate(
    Attribute => 'IncidentStateID',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid IncidentStateID',
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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
