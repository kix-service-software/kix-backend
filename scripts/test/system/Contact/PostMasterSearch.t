# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get needed objects
my $ConfigObject       = $Kernel::OM->Get('Config');
my $ContactObject = $Kernel::OM->Get('Contact');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $Contact = 'customer' . $Helper->GetRandomID();

# add two users
$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

my $OrgRand  = 'example-organisation' . $Helper->GetRandomID();

my $OrgID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number => $OrgRand,
    Name   => $OrgRand,
    ValidID => 1,
    UserID  => 1,
);

my $ContactID = $ContactObject->ContactAdd(
    Source         => 'Contact',
    Firstname  => 'Firstname Test',
    Lastname   => 'Lastname Test',
    PrimaryOrganisationID => $OrgID,
    OrganisationIDs => [
        $OrgID
    ],
    Email      => "john.doe.$Contact\@example.com",
    ValidID        => 1,
    UserID         => 1,
);

$Self->True(
    $ContactID,
    "ContactAdd() - $ContactID",
);

my @Tests = (
    {
        Name             => "Exact match",
        PostMasterSearch => "john.doe.$Contact\@example.com",
        ResultCount      => 1,
    },
    {
        Name             => "Exact match with different casing",
        PostMasterSearch => "John.Doe.$Contact\@example.com",
        ResultCount      => 1,
    },
    {
        Name             => "Partial string",
        PostMasterSearch => "doe.$Contact\@example.com",
        ResultCount      => 0,
    },
    {
        Name             => "Partial string with different casing",
        PostMasterSearch => "Doe.$Contact\@example.com",
        ResultCount      => 0,
    },
);

for my $Test (@Tests) {
    my %Result = $ContactObject->ContactSearch(
        PostMasterSearch => $Test->{PostMasterSearch},
    );

    $Self->Is(
        scalar keys %Result,
        $Test->{ResultCount},
        $Test->{Name},
    );
}

# cleanup is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
