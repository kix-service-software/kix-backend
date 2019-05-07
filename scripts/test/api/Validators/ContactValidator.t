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
use Kernel::API::Validator::ContactValidator;

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
my $ValidatorObject = Kernel::API::Validator::ContactValidator->new(
    DebuggerObject => $DebuggerObject
);

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# create organisation
my $OrgID = $Kernel::OM->Get('Kernel::System::Organisation')->OrganisationAdd(
    Number  => 'ValidatorTestCustomer',
    Name    => 'ValidatorTestCustomer',
    ValidID => 1,
    UserID  => 1,
);

# create contact
my $ContactID = $Kernel::OM->Get('Kernel::System::Contact')->ContactAdd(
    Firstname  => 'ValidatorTestContact',
    Lastname   => 'ValidatorTestContact',
    PrimaryOrganisationID => $OrgID,
    OrganisationIDs => [
        $OrgID
    ],
    Login      => 'ValidatorTestContact',
    Email      => 'ValidatorTestContact@validatortest.kix',
    ValidID    => 1,
    UserID     => 1,
);

my $ValidData = {
    ContactID => $ContactID
};

my $InvalidData = {
    ContactID => 9999
};

# validate valid Contact
my $Result = $ValidatorObject->Validate(
    Attribute => 'ContactID',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid Contact',
);

# validate invalid Contact
$Result = $ValidatorObject->Validate(
    Attribute => 'ContactID',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid Contact',
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
