# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Test::Net::LDAP::Util qw(ldap_mockify);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# prepare test organisations
my $OrganisationID1 =  $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => 'KIX',
    Name    => 'KIX Service Software GmbH',
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $OrganisationID1,
    'Created first organisation'
);
my $OrganisationID2 =  $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => 'capeIT',
    Name    => 'c.a.p.e. IT GmbH',
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $OrganisationID2,
    'Created second organisation'
);

# prepare config for sync
my $SyncConfig = {
    Host       => 'ldap://unittest',
    BaseDN     => 'dc=example,dc=com',
    UID        => 'uid',
    GroupDN    => 'cn=kixallow,ou=groups,dc=example,dc=com',
    AccessAttr => 'member',
    UserAttr   => 'UID',

    GroupDNBasedUsageContextSync => {
        'cn=agent,ou=groups,dc=example,dc=com' => {
            'IsAgent'    => 1,
            'IsCustomer' => 0
        },
        'cn=customer,ou=groups,dc=example,dc=com' => {
            'IsCustomer' => 1
        }
    },

    ContactUserSync => {
        'DynamicField_Source' => 'ARRAYJOIN[, ]:LDAP: {objectClass}',
        'Email'               => 'mail',
        'Firstname'           => 'givenName',
        'Lastname'            => 'sn',
        'OrganisationIDs'     => [
            'SET:' . $OrganisationID1,
            'ou'
        ],
        'PrimaryOrganisationID' => 'SET:' . $OrganisationID1,
        'City'                  => 'l',
        'Language'              => 'st',
        'Mobile'                => 'mobile',
        'Phone'                 => 'telephoneNumber',
        'Street'                => 'street',
        'Zip'                   => 'postalCode',
        'Comment'               => 'CONCAT:{sn}, {givenName} / {street}, {postalCode} {l}'
    }
};

# prepare test users
my %TestUsers = (
    'uid=user1,ou=users,dc=example,dc=com' => [
        objectClass => [ 'top', 'person', 'organizationalPerson', 'inetOrgPerson' ],
        uid         => 'syncuser1',
        ou          => 'capeIT',
        givenName   => 'Max',
        sn          => 'Mustermann',
        mail        => [
            'max.mustermann@kixdesk.com',
            'max.mustermann@cape-it.de',
            'info@kixdesk.com',
            '',
            'dummy1@kixdesk.com',
            'dummy2@kixdesk.com',
            'dummy3@kixdesk.com',
            'dummy4@kixdesk.com'
        ],
        l           => 'Chemnitz',
        postalCode  => '09113',
        street      => 'Schönherrstr. 8'
    ]
);

# prepare test groups
my %TestGroups = (
    'cn=kixallow,ou=groups,dc=example,dc=com' => [
        member => [
            'user1'
        ]
    ],
    'cn=agent,ou=groups,dc=example,dc=com' => [
        member => [
            'user1'
        ]
    ],
    'cn=customer,ou=groups,dc=example,dc=com' => []
);

# prepare user login for test
my $TestUserLogin = 'user1';

# get module
if ( !$Kernel::OM->Get('Main')->Require('Kernel::System::Auth::Sync::LDAP') ) {
        $Self->True(
        0,
        'Cannot find LDAP auth sync module!',
    );
    return;

}
my $Module = Kernel::System::Auth::Sync::LDAP->new(
    Config => $SyncConfig
);
if ( !$Module ) {
        $Self->True(
        0,
        'Get module instance failed!',
    );

    $Helper->Rollback();

    return;
}

# check required method
if ( !$Module->can('Sync') ) {
    $Self->True(
        0,
        "Module cannot \"Sync\"!"
    );

    $Helper->Rollback();

    return;
}

ldap_mockify {
    # prepare data for mocked ldap
    my $ldap = Net::LDAP->new($SyncConfig->{Host});

    for my $TestUserDN ( keys( %TestUsers ) ) {
        $ldap->add( $TestUserDN, attr => $TestUsers{ $TestUserDN } );
    }
    for my $TestGroupDN ( keys( %TestGroups ) ) {
        $ldap->add( $TestGroupDN, attr => $TestGroups{ $TestGroupDN } );
    }

    my $UserLogin = $Module->Sync(
        User => $TestUserLogin
    );
    $Self->Is(
        $UserLogin,
        $TestUserLogin,
        'Sync returned login'
    );

    # get user data
    my %User = $Kernel::OM->Get('User')->GetUserData(
        User => $UserLogin
    );
    $Self->Is(
        $User{UserLogin},
        $TestUserLogin,
        'User has correct login'
    );
    $Self->Is(
        $User{IsAgent},
        1,
        'User has correct IsAgent'
    );
    $Self->Is(
        $User{IsCustomer},
        0,
        'User has correct IsCustomer'
    );

    my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
        UserID        => $User{UserID},
        DynamicFields => 1
    );
    $Self->Is(
        $Contact{Firstname},
        'Max',
        'Contact has correct Firstname'
    );
    $Self->Is(
        $Contact{Lastname},
        'Mustermann',
        'Contact has correct Lastname'
    );
    $Self->Is(
        $Contact{Fullname},
        'Max Mustermann',
        'Contact has correct Fullname'
    );
    $Self->Is(
        $Contact{Email},
        'max.mustermann@kixdesk.com',
        'Contact has correct Email'
    );
    $Self->Is(
        $Contact{Email1},
        'max.mustermann@cape-it.de',
        'Contact has correct Email1'
    );
    $Self->Is(
        $Contact{Email2},
        'info@kixdesk.com',
        'Contact has correct Email2'
    );
    $Self->Is(
        $Contact{Email3},
        'dummy1@kixdesk.com',
        'Contact has correct Email3'
    );
    $Self->Is(
        $Contact{Email4},
        'dummy2@kixdesk.com',
        'Contact has correct Email4'
    );
    $Self->Is(
        $Contact{Email5},
        'dummy3@kixdesk.com',
        'Contact has correct Email5'
    );
    $Self->Is(
        $Contact{Phone},
        '',
        'Contact has correct Phone'
    );
    $Self->Is(
        $Contact{PrimaryOrganisationID},
        $OrganisationID1,
        'Contact has correct PrimaryOrganisationID'
    );
    $Self->IsDeeply(
        $Contact{OrganisationIDs},
        [ $OrganisationID1, $OrganisationID2 ],
        'Contact has correct OrganisationIDs'
    );
    $Self->IsDeeply(
        $Contact{DynamicField_Source},
        [ 'LDAP: top, person, organizationalPerson, inetOrgPerson' ],
        'Contact has correct DynamicField_Source'
    );
};

# rollback transaction on database
$Helper->Rollback();

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut