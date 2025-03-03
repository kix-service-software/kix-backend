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

use Kernel::API::Validator::ContactValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::ContactValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# create organisation
my $OrgID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => 'ValidatorTestCustomer',
    Name    => 'ValidatorTestCustomer',
    ValidID => 1,
    UserID  => 1,
);

# create contact
my $ContactID = $Kernel::OM->Get('Contact')->ContactAdd(
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

# rollback transaction on database
$Helper->Rollback();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
