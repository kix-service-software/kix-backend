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

use Kernel::System::VariableCheck qw(:all);

# get needed objects
my $ConfigObject       = $Kernel::OM->Get('Config');
my $CacheObject        = $Kernel::OM->Get('Cache');
my $ContactObject      = $Kernel::OM->Get('Contact');
my $OrganisationObject = $Kernel::OM->Get('Organisation');
my $DBObject           = $Kernel::OM->Get('DB');
my $UserObject         = $Kernel::OM->Get('User');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# add three users
$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

# create organisation for tests
my $OrgRand        = 'Example-Organisation-Company' . $Helper->GetRandomID();
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
my $OrganisationIDForUpdate = $OrganisationObject->OrganisationAdd(
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

my $ContactID = '';
for my $Key ( 1 .. 3, 'ä', 'カス', '_', '&' ) {

    # create non existing customer user login
    my $ContactRandom = 'unittest-' . $Key . $Helper->GetRandomID();

    # add assigned user
    my $UserID = $UserObject->UserAdd(
        UserLogin    => $ContactRandom,
        ValidID      => 1,
        ChangeUserID => 1,
        IsAgent      => 1
    );
    $Self->True(
        $UserID,
        "assigned UserAdd() - $UserID",
    );

    my $ContactID = $ContactObject->ContactAdd(
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

    my %Contact = $ContactObject->ContactGet(
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

    my $Update = $ContactObject->ContactUpdate(
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

    %Contact = $ContactObject->ContactGet(
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

    # START CaseSensitive
    $ConfigObject->{Contact}->{Params}->{SearchCaseSensitive} = 1;

    $Kernel::OM->ObjectsDiscard( Objects => ['Contact'] );
    $ContactObject = $Kernel::OM->Get('Contact');

    $CacheObject->CleanUp();

    # Customer Search
    %List = $Kernel::OM->Get('ObjectSearch')->Search(
        Search => {
            AND => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => lc( $ContactRandom )
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
        "ObjectSearch - Contact - Fulltext=\'" . lc( $ContactRandom ) . "\'- $ContactID is found",
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
                        Value    => lc("$ContactRandom"),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   =>  "ObjectSearch - Contact - Fulltext LIKE lc('') - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Fulltext',
                        Operator => 'LIKE',
                        Value    => lc("$ContactRandom*"),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   =>  "ObjectSearch - Contact - Fulltext LIKE lc('\$ContactRandom*') - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Fulltext',
                        Operator => 'LIKE',
                        Value    => lc("*$ContactRandom"),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   =>  "ObjectSearch - Contact - Fulltext LIKE lc(\"*\$ContactRandom\") - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Fulltext',
                        Operator => 'LIKE',
                        Value    => lc("*$ContactRandom*"),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   =>  "ObjectSearch - Contact - Fulltext CONTAINS lc(\"\*$ContactRandom\") - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Fulltext',
                        Operator => 'LIKE',
                        Value    => lc("$ContactRandom"),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   =>  "ObjectSearch - Contact - Fulltext LIKE uc('') - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Fulltext',
                        Operator => 'LIKE',
                        Value    => uc("$ContactRandom*"),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   =>  "ObjectSearch - Contact - Fulltext LIKE uc('\$ContactRandom*') - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Fulltext',
                        Operator => 'LIKE',
                        Value    => uc("*$ContactRandom"),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   =>  "ObjectSearch - Contact - Fulltext LIKE lucc(\"*\$ContactRandom\") - $ContactID",
        },
        {
            Search => {
                AND => [
                    {
                        Field    => 'Fulltext',
                        Operator => 'LIKE',
                        Value    => uc("*$ContactRandom*"),
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Text   =>  "ObjectSearch - Contact - Fulltext LIKE uc(\"\*$ContactRandom\") - $ContactID",
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
    $Update = $ContactObject->ContactUpdate(
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
        my $Success = $ContactObject->ContactDelete(
            ID => $ContactID,
        );

        $Self->True(
            $Success,
            "ContactDelete() - $ContactID",
        );
    }
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
