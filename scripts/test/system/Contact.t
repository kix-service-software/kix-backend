# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::VariableCheck qw(:all);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# add three users
$Kernel::OM->Get('Config')->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

# create organisation for tests
my $OrgRand        = 'Example-Organisation-Company' . $Helper->GetRandomID();
my $OrganisationID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
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
my $OrganisationIDForUpdate = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $OrgRand . '_ForUpdate',
    Name    => $OrgRand . ' Inc_ForUpdate',
    Street  => 'Some Street',
    Zip     => '12345',
    City    => 'Some city',
    Country => 'USA',
    Url     => 'http://example.com',
    Comment => 'some comment',
    ValidID => 1,
    UserID  => 1,
);

my $SubOrganisationID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    ParentID => $OrganisationID,
    Number   => $OrgRand.'_sub',
    Name     => $OrgRand . '_sub Inc',
    Street   => 'Some Street',
    Zip      => '12345',
    City     => 'Some city',
    Country  => 'USA',
    Url      => 'http://example.com',
    Comment  => 'some comment',
    ValidID  => 1,
    UserID   => 1,
);

my $SubSubOrganisationID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    ParentID => $SubOrganisationID,
    Number   => $OrgRand.'_sub_sub',
    Name     => $OrgRand . '_sub_sub Inc',
    Street   => 'Some Street',
    Zip      => '12345',
    City     => 'Some city',
    Country  => 'USA',
    Url      => 'http://example.com',
    Comment  => 'some comment',
    ValidID  => 1,
    UserID   => 1,
);

my $ContactID = '';
for my $Key ( 1 .. 3, 'ä', 'カス', '_' ) {

    # create non existing customer user login
    my $ContactRandom = 'unittest-' . $Key . $Helper->GetRandomID();

    # add assigned user
    my $UserID = $Kernel::OM->Get('User')->UserAdd(
        UserLogin    => $ContactRandom,
        ValidID      => 1,
        ChangeUserID => 1,
        IsAgent      => 1
    );
    $Self->True(
        $UserID,
        "assigned UserAdd() - $UserID",
    );

    my $ContactID = $Kernel::OM->Get('Contact')->ContactAdd(
        AssignedUserID        => $UserID,
        Firstname             => 'Firstname Test' . $Key,
        Lastname              => 'Lastname Test' . $Key,
        PrimaryOrganisationID => $OrganisationID,
        OrganisationIDs       => [
            $OrganisationID
        ],
        Email    => $ContactRandom . '-Email@example.com',
        ValidID  => 1,
        UserID   => 1,
    );
    $Self->True(
        $ContactID,
        "ContactAdd() - $ContactID",
    );

    my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
        ID => $ContactID,
    );

    $Self->Is(
        $Contact{Firstname},
        "Firstname Test$Key",
        "ContactGet() - Firstname",
    );
    $Self->Is(
        $Contact{Lastname},
        "Lastname Test$Key",
        "ContactGet() - Lastname",
    );
    $Self->Is(
        $Contact{Email},
        $ContactRandom . '-Email@example.com',
        "ContactGet() - Email",
    );
    $Self->Is(
        $Contact{PrimaryOrganisationID},
        $OrganisationID,
        "ContactGet() - PrimaryOrganisationID",
    );
    $Self->Is(
        $Contact{AssignedUserID},
        $UserID,
        "ContactGet() - AssignedUserID",
    );

    $Self->Is(
        scalar( @{ $Contact{OrganisationIDs} } ),
        1,
        "ContactGet() - length OrganisationIDs",
    );
    $Self->Is(
        $Contact{ValidID},
        1,
        "ContactGet() - ValidID",
    );

    # check Organisation::VirtuallyAssignContactsToSubOrganisations
    my $Success = $Helper->ConfigSettingChange(
        Valid => 1,
        Key   => 'Organisation::VirtuallyAssignContactsToSubOrganisations',
        Value => '1',
    );
    $Self->True(
        $Success,
        "Enable Organisation::VirtuallyAssignContactsToSubOrganisations",
    );

    %Contact = $Kernel::OM->Get('Contact')->ContactGet(
        ID => $ContactID,
    );
    $Self->Is(
        scalar( @{ $Contact{OrganisationIDs} } ),
        3,
        "ContactGet() - length OrganisationIDs",
    );
    $Self->IsDeeply(
        $Contact{OrganisationIDs},
        [
            $OrganisationID,
            $SubOrganisationID,
            $SubSubOrganisationID,
        ],
        "ContactGet() - OrganisationIDs",
    );

    $Success = $Helper->ConfigSettingChange(
        Valid => 1,
        Key   => 'Organisation::VirtuallyAssignContactsToSubOrganisations',
        Value => '0',
    );
    $Self->True(
        $Success,
        "Disable Organisation::VirtuallyAssignContactsToSubOrganisations",
    );

    %Contact = $Kernel::OM->Get('Contact')->ContactGet(
        ID => $ContactID,
    );
    $Self->Is(
        scalar( @{ $Contact{OrganisationIDs} } ),
        1,
        "ContactGet() re-test - length OrganisationIDs",
    );
    $Self->IsDeeply(
        $Contact{OrganisationIDs},
        [
            $OrganisationID,
        ],
        "ContactGet() re-test - OrganisationIDs",
    );

    my $Update = $Kernel::OM->Get('Contact')->ContactUpdate(
        ID                    => $ContactID,
        AssignedUserID        => $UserID,
        Firstname             => 'Firstname Test Update' . $Key,
        Lastname              => 'Lastname Test Update' . $Key,
        Email                 => 'test@example.org' . $Key,
        PrimaryOrganisationID => $OrganisationIDForUpdate,
        OrganisationIDs       => [
            $OrganisationIDForUpdate
        ],
        ValidID => 1,
        UserID  => 1,
    );
    $Self->True(
        $Update,
        "ContactUpdate() - $ContactID",
    );

    %Contact = $Kernel::OM->Get('Contact')->ContactGet(
        ID => $ContactID,
    );

    $Self->Is(
        $Contact{Firstname},
        "Firstname Test Update$Key",
        "ContactGet() - Firstname",
    );
    $Self->Is(
        $Contact{Lastname},
        "Lastname Test Update$Key",
        "ContactGet() - Lastname",
    );
    $Self->Is(
        $Contact{Email},
        'test@example.org' . $Key,
        "ContactGet() - Email",
    );
    $Self->Is(
        $Contact{PrimaryOrganisationID},
        $OrganisationIDForUpdate,
        "ContactGet() - OrganisationID",
    );
    $Self->Is(
        $Contact{AssignedUserID},
        $UserID,
        "ContactGet() - AssignedUserID",
    );
    $Self->Is(
        $Contact{ValidID},
        1,
        "ContactGet() - ValidID",
    );

    # search by OrganisationID
    my %List = $Kernel::OM->Get('ObjectSearch')->Search(
        Search => {
            AND => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'EQ',
                    Value    => $OrganisationIDForUpdate
                },
                {
                    Field    => 'Valid',
                    Operator => 'EQ',
                    Value    => 'valid'
                }
            ]
        },
        ObjectType => 'Contact',
        Result     => 'HASH',
        UserID     => 1,
        UserType   => 'Agent'
    );
    $Self->True(
        $List{$ContactID},
        "ObjectSearch - Contact - PrimaryOrganisationID=\'$OrganisationIDForUpdate\' - $ContactID is found",
    );

    $Kernel::OM->ObjectsDiscard( Objects => ['Contact'] );

    $Kernel::OM->Get('Cache')->CleanUp();

    # Customer Search
    %List = $Kernel::OM->Get('ObjectSearch')->Search(
        Search => {
            AND => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => 'test@example.org' . $Key
                },
                {
                    Field    => 'Valid',
                    Operator => 'EQ',
                    Value    => 'valid'
                }
            ]
        },
        ObjectType => 'Contact',
        Result     => 'HASH',
        UserID     => 1,
        UserType   => 'Agent'
    );

    $Self->True(
        $List{$ContactID},
        "ObjectSearch - Contact - Fulltext=\'" . 'test@example.org' . $Key . "\'- $ContactID is found",
    );

    my @TestData = (
        {
            Search => {
                AND => [
                    {
                        Field    => 'Emails',
                        Operator => 'EQ',
                        Value    => 'test@example.org' . $Key,
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   => "ObjectSearch - Contact - Email - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Emails',
                        Operator => 'EQ',
                        Value    => lc( 'test@example.org' . $Key ),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   => "ObjectSearch - Contact - Email lc() - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Emails',
                        Operator => 'EQ',
                        Value    => uc( 'test@example.org' . $Key ),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   => "ObjectSearch - Contact - Email uc() - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Login',
                        Operator => 'EQ',
                        Value    => $ContactRandom,
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   => "ObjectSearch - Contact - Login - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Login',
                        Operator => 'EQ',
                        Value    => lc($ContactRandom),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   => "ObjectSearch - Contact - Login - lc - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Login',
                        Operator => 'EQ',
                        Value    => uc($ContactRandom),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   => "ObjectSearch - Contact - Login - uc - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Fulltext',
                        Operator => 'LIKE',
                        Value    => lc('test@example.org' . $Key),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   =>  "ObjectSearch - Contact - Fulltext LIKE lc(Email) - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Fulltext',
                        Operator => 'LIKE',
                        Value    => lc('test@example.org' . $Key . '*'),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   =>  "ObjectSearch - Contact - Fulltext LIKE lc(Email*) - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Fulltext',
                        Operator => 'LIKE',
                        Value    => lc('*test@example.org' . $Key),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   =>  "ObjectSearch - Contact - Fulltext LIKE lc(*Email) - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Fulltext',
                        Operator => 'LIKE',
                        Value    => lc('*test@example.org' . $Key . '*'),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   =>  "ObjectSearch - Contact - Fulltext LIKE lc(*Email*) - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Fulltext',
                        Operator => 'LIKE',
                        Value    => uc('test@example.org' . $Key),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   =>  "ObjectSearch - Contact - Fulltext LIKE uc(Email) - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Fulltext',
                        Operator => 'LIKE',
                        Value    => uc('test@example.org' . $Key . '*'),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   =>  "ObjectSearch - Contact - Fulltext LIKE uc(Email*) - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Fulltext',
                        Operator => 'LIKE',
                        Value    => uc('*test@example.org' . $Key),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   =>  "ObjectSearch - Contact - Fulltext LIKE uc(*Email) - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Fulltext',
                        Operator => 'LIKE',
                        Value    => uc('*test@example.org' . $Key . '*'),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   =>  "ObjectSearch - Contact - Fulltext LIKE uc(*Email*) - $ContactID",
        }
    );

    for my $Test ( @TestData ) {
        my %ContactList = $Kernel::OM->Get('ObjectSearch')->Search(
            Search     => $Test->{Search},
            ObjectType => 'Contact',
            Result     => 'HASH',
            UserID     => 1,
            UserType   => 'Agent'
        );

        if ( $Test->{Not} ) {
            $Self->False(
                $ContactList{$ContactID},
                $Test->{Text},
            );
        }
        else {
            $Self->True(
                $ContactList{$ContactID},
                $Test->{Text},
            );
        }
    }

    #update customer user
    $Update = $Kernel::OM->Get('Contact')->ContactUpdate(
        ID                    => $ContactID,
        AssignedUserID        => $UserID,
        Firstname             => 'Firstname Update' . $ContactID,
        Lastname              => 'Lastname Update' . $ContactID,
        Email                 => $ContactID . 'new@example.com',
        PrimaryOrganisationID => $OrganisationID,
        OrganisationIDs       => [
            $OrganisationID
        ],
        ValidID => 1,
        UserID  => 1,
    );
    $Self->True(
        $Update,
        "ContactUpdate - $ContactID",
    );

    if ( $Key eq '1' ) {

        # delete the first contact
        my $Success = $Kernel::OM->Get('Contact')->ContactDelete(
            ID     => $ContactID,
            UserID => 1,
        );

        $Self->True(
            $Success,
            "ContactDelete() - $ContactID",
        );
    }
}

# set fixed time for test
$Helper->FixedTimeSet(
    $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
        String => '2014-01-01 14:00:00',
    ),
);

my $DynamicFieldID1 = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
    Name            => 'UnitTest1',
    Label           => 'UnitTest1',
    FieldType       => 'Text',
    ObjectType      => 'Contact',
    Config          => {},
    ValidID         => 1,
    UserID          => 1
);
$Self->True(
    $DynamicFieldID1,
    'DynamicFieldAdd() - create first test dynamic field'
);
my $DynamicField1 = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
    ID => $DynamicFieldID1,
);

my $DynamicFieldID2 = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
    Name            => 'UnitTest2',
    Label           => 'UnitTest2',
    FieldType       => 'Text',
    ObjectType      => 'Contact',
    Config          => {},
    ValidID         => 1,
    UserID          => 1
);
$Self->True(
    $DynamicFieldID2,
    'DynamicFieldAdd() - create second test dynamic field'
);
my $DynamicField2 = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
    ID => $DynamicFieldID2,
);

my $ContactID1 = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname => 'Unit',
    Lastname  => 'Test',
    Email     => 'unit.test@example.com',
    ValidID   => 1,
    UserID    => 1,
);
$Self->True(
    $ContactID1,
    "ContactAdd() - $ContactID1",
);

my $DynamicFieldValue1 = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
    DynamicFieldConfig => $DynamicField1,
    ObjectID           => $ContactID1,
    Value              => 'UnitTest1',
    UserID             => 1,
);
$Self->True(
    $DynamicFieldValue1,
    'ValueSet() - set first dynamic field value',
);

my $DynamicFieldValue2 = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
    DynamicFieldConfig => $DynamicField2,
    ObjectID           => $ContactID1,
    Value              => 'UnitTest2',
    UserID             => 1,
);
$Self->True(
    $DynamicFieldValue2,
    'ValueSet() - set second dynamic field value',
);

my @ContactGetTests = (
    {
        Name      => 'Parameter DynamicFields not given',
        Parameter => {
            ID => $ContactID1
        },
        Expected  => {
            ID              => $ContactID1,
            UserID          => $ContactID1,
            Firstname       => 'Unit',
            Lastname        => 'Test',
            Email           => 'unit.test@example.com',
            Title           => undef,
            Phone           => undef,
            Fax             => undef,
            Mobile          => undef,
            Street          => undef,
            Zip             => undef,
            City            => undef,
            Country         => undef,
            Comment         => '',
            ValidID         => 1,
            CreateTime      => '2014-01-01 14:00:00',
            CreateBy        => 1,
            ChangeTime      => '2014-01-01 14:00:00',
            ChangeBy        => 1,
            AssignedUserID  => undef,
            Email1          => '',
            Email2          => '',
            Email3          => '',
            Email4          => '',
            Email5          => '',
            OrganisationIDs => [],
            Fullname        => 'Unit Test'
        }
    },
    {
        Name      => 'Parameter DynamicFields true value',
        Parameter => {
            ID            => $ContactID1,
            DynamicFields => 1
        },
        Expected  => {
            ID                     => $ContactID1,
            UserID                 => $ContactID1,
            Firstname              => 'Unit',
            Lastname               => 'Test',
            Email                  => 'unit.test@example.com',
            Title                  => undef,
            Phone                  => undef,
            Fax                    => undef,
            Mobile                 => undef,
            Street                 => undef,
            Zip                    => undef,
            City                   => undef,
            Country                => undef,
            Comment                => '',
            ValidID                => 1,
            CreateTime             => '2014-01-01 14:00:00',
            CreateBy               => 1,
            ChangeTime             => '2014-01-01 14:00:00',
            ChangeBy               => 1,
            AssignedUserID         => undef,
            Email1                 => '',
            Email2                 => '',
            Email3                 => '',
            Email4                 => '',
            Email5                 => '',
            OrganisationIDs        => [],
            Fullname               => 'Unit Test',
            DynamicField_UnitTest1 => ['UnitTest1'],
            DynamicField_UnitTest2 => ['UnitTest2']
        }
    },
    {
        Name      => 'Parameter DynamicFields empty array',
        Parameter => {
            ID            => $ContactID1,
            DynamicFields => []
        },
        Expected  => {
            ID              => $ContactID1,
            UserID          => $ContactID1,
            Firstname       => 'Unit',
            Lastname        => 'Test',
            Email           => 'unit.test@example.com',
            Title           => undef,
            Phone           => undef,
            Fax             => undef,
            Mobile          => undef,
            Street          => undef,
            Zip             => undef,
            City            => undef,
            Country         => undef,
            Comment         => '',
            ValidID         => 1,
            CreateTime      => '2014-01-01 14:00:00',
            CreateBy        => 1,
            ChangeTime      => '2014-01-01 14:00:00',
            ChangeBy        => 1,
            AssignedUserID  => undef,
            Email1          => '',
            Email2          => '',
            Email3          => '',
            Email4          => '',
            Email5          => '',
            OrganisationIDs => [],
            Fullname        => 'Unit Test'
        }
    },
    {
        Name      => 'Parameter DynamicFields array with existing field',
        Parameter => {
            ID            => $ContactID1,
            DynamicFields => ['UnitTest1']
        },
        Expected  => {
            ID                     => $ContactID1,
            UserID                 => $ContactID1,
            Firstname              => 'Unit',
            Lastname               => 'Test',
            Email                  => 'unit.test@example.com',
            Title                  => undef,
            Phone                  => undef,
            Fax                    => undef,
            Mobile                 => undef,
            Street                 => undef,
            Zip                    => undef,
            City                   => undef,
            Country                => undef,
            Comment                => '',
            ValidID                => 1,
            CreateTime             => '2014-01-01 14:00:00',
            CreateBy               => 1,
            ChangeTime             => '2014-01-01 14:00:00',
            ChangeBy               => 1,
            AssignedUserID         => undef,
            Email1                 => '',
            Email2                 => '',
            Email3                 => '',
            Email4                 => '',
            Email5                 => '',
            OrganisationIDs        => [],
            Fullname               => 'Unit Test',
            DynamicField_UnitTest1 => ['UnitTest1']
        }
    },
    {
        Name      => 'Parameter DynamicFields array with not existing field',
        Parameter => {
            ID            => $ContactID1,
            DynamicFields => ['UnitTest3']
        },
        Expected  => {
            ID              => $ContactID1,
            UserID          => $ContactID1,
            Firstname       => 'Unit',
            Lastname        => 'Test',
            Email           => 'unit.test@example.com',
            Title           => undef,
            Phone           => undef,
            Fax             => undef,
            Mobile          => undef,
            Street          => undef,
            Zip             => undef,
            City            => undef,
            Country         => undef,
            Comment         => '',
            ValidID         => 1,
            CreateTime      => '2014-01-01 14:00:00',
            CreateBy        => 1,
            ChangeTime      => '2014-01-01 14:00:00',
            ChangeBy        => 1,
            AssignedUserID  => undef,
            Email1          => '',
            Email2          => '',
            Email3          => '',
            Email4          => '',
            Email5          => '',
            OrganisationIDs => [],
            Fullname        => 'Unit Test'
        }
    }
);
for my $Test ( @ContactGetTests ) {
    my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
        %{ $Test->{Parameter} }
    );
    $Self->IsDeeply(
        \%Contact,
        $Test->{Expected},
        'ContactGet: ' . $Test->{Name} . ': Result',
    );
}

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
