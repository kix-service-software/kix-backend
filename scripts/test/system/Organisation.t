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
my $ConfigObject = $Kernel::OM->Get('Config');
my $DBObject     = $Kernel::OM->Get('DB');
my $XMLObject    = $Kernel::OM->Get('XML');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $Data         = $ConfigObject->Get('Organisation');
my $DefaultValue = $Data->{Params}->{Table};

my $OrganisationObject = $Kernel::OM->Get('Organisation');

for my $Key ( 1 .. 3, 'ä', 'カス' ) {

    my $OrgRand = 'Example-Organisation-Company' . $Key . $Helper->GetRandomID();

    my $OrganisationID = $OrganisationObject->OrganisationAdd(
        Number  => $OrgRand,
        Name    => $OrgRand . ' Inc',
        Street  => 'Some Street',
        Zip     => '12345',
        City    => 'Some city',
        Country => 'USA',
        Url     => 'http://example.com',
        Comment => 'some comment',
        ValidID => 1,
        UserID  => 1,
    );

    $Self->True(
        $OrganisationID,
        "OrganisationAdd() - $OrganisationID",
    );

    my %Organisation = $OrganisationObject->OrganisationGet(
        ID => $OrganisationID,
    );

    $Self->Is(
        $Organisation{Name},
        "$OrgRand Inc",
        "OrganisationGet() - Name",
    );

    $Self->Is(
        $Organisation{Number},
        "$OrgRand",
        "OrganisationGet() - Number",
    );

    # check cache
    %Organisation = $OrganisationObject->OrganisationGet(
        ID => $OrganisationID,
    );

    $Self->Is(
        $Organisation{Name},
        "$OrgRand Inc",
        "OrganisationGet() cached - Name",
    );

    $Self->Is(
        $Organisation{Number},
        "$OrgRand",
        "OrganisationGet() cached - Number",
    );

    $Self->True(
        $Organisation{CreateTime},
        "OrganisationGet() - CreateTime",
    );

    $Self->True(
        $Organisation{ChangeTime},
        "OrganisationGet() - ChangeTime",
    );

    my $Update = $OrganisationObject->OrganisationUpdate(
        ID      => $OrganisationID,
        Number  => $OrgRand . '- updated',
        Name    => $OrgRand . '- updated Inc',
        Street  => 'Some Street',
        Zip     => '12345',
        City    => 'Some city',
        Country => 'USA',
        Url     => 'http://updated.example.com',
        Comment => 'some comment updated',
        ValidID => 1,
        UserID  => 1,
    );

    $Self->True(
        $Update,
        "OrganisationUpdate() - $OrganisationID",
    );

    %Organisation = $OrganisationObject->OrganisationGet(
        ID => $OrganisationID,
    );

    $Self->Is(
        $Organisation{Name},
        "$OrgRand- updated Inc",
        "OrganisationGet() - Name",
    );

    $Self->Is(
        $Organisation{Number},
        "$OrgRand- updated",
        "OrganisationGet() - Number",
    );

    $Self->Is(
        $Organisation{Comment},
        "some comment updated",
        "OrganisationGet() - Comment",
    );

    $Self->Is(
        $Organisation{Url},
        "http://updated.example.com",
        "OrganisationGet() - Url",
    );

    $Self->True(
        $Organisation{CreateTime},
        "OrganisationGet() - CreateTime",
    );

    $Self->True(
        $Organisation{ChangeTime},
        "OrganisationGet() - ChangeTime",
    );

    $OrganisationObject->OrganisationUpdate(
        ID      => $OrganisationID,
        Number  => $OrgRand . '- updated',
        Name    => $OrgRand . '- updated Inc',
        Street  => 'Some Street',
        Zip     => '12345',
        City    => 'Some city',
        Country => 'Germany',
        Url     => 'http://updated.example.com',
        Comment => 'some comment updated',
        ValidID => 1,
        UserID  => 1,
    );

    %Organisation = $OrganisationObject->OrganisationGet(
        ID => $OrganisationID,
    );

    $Self->Is(
        $Organisation{Country},
        'Germany',
        "OrganisationGet() cached - Changed country from USA to Germany and check value",
    );

    if ( $Key eq '1' ) {
        # delete the first organisation
        my $Success = $OrganisationObject->OrganisationDelete(
            ID => $OrganisationID,
        );

        $Self->True(
            $Success,
            "OrganisationDelete() - $OrganisationID",
        );
    }
}

my %OrganisationSearch = $OrganisationObject->OrganisationSearch( Valid => 0 );
my $OrgList = %OrganisationSearch ? 1 : 0;

# check OrganisationSearch with Valid=>0
$Self->True(
    $OrgList,
    "OrganisationSearch() with Valid=>0",
);

%OrganisationSearch = $OrganisationObject->OrganisationSearch(
    Search => 'Example',
    Valid  => 0,
);

$Self->True(
    scalar keys %OrganisationSearch,
    "OrganisationSearch() with Search",
);

%OrganisationSearch = $OrganisationObject->OrganisationSearch(
    Search => 'Foo-123FALSE-Example*',
    Valid  => 0,
);

$Self->False(
    scalar keys %OrganisationSearch,
    "OrganisationSearch() with Search",
);

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
