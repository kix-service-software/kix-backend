# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
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

use MIME::Base64 qw(decode_base64);
use Net::LDAP;
use Net::LDAP::Util qw(escape_filter_value);
use Test::Net::LDAP::Util qw(ldap_mockify);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# test sub Convert
## ToDo: implement test to check correct charset conversion

# test sub DetectMIMETypeFromBase64
my @Tests = (
    {
        Name     => 'DetectMIMETypeFromBase64: Undefined MIMEType for undefined content',
        Content  => undef,
        Expected => undef,
    },
    {
        Name     => 'DetectMIMETypeFromBase64: Detect GIF',
        Content  => <<'END',
R0lGODlhAQABAP8AAAAAAAAAMwAAZgAAmQAAzAAA/wAzAAAzMwAzZgAzmQAzzAAz/wBmAABmMwBm
ZgBmmQBmzABm/wCZAACZMwCZZgCZmQCZzACZ/wDMAADMMwDMZgDMmQDMzADM/wD/AAD/MwD/ZgD/
mQD/zAD//zMAADMAMzMAZjMAmTMAzDMA/zMzADMzMzMzZjMzmTMzzDMz/zNmADNmMzNmZjNmmTNm
zDNm/zOZADOZMzOZZjOZmTOZzDOZ/zPMADPMMzPMZjPMmTPMzDPM/zP/ADP/MzP/ZjP/mTP/zDP/
/2YAAGYAM2YAZmYAmWYAzGYA/2YzAGYzM2YzZmYzmWYzzGYz/2ZmAGZmM2ZmZmZmmWZmzGZm/2aZ
AGaZM2aZZmaZmWaZzGaZ/2bMAGbMM2bMZmbMmWbMzGbM/2b/AGb/M2b/Zmb/mWb/zGb//5kAAJkA
M5kAZpkAmZkAzJkA/5kzAJkzM5kzZpkzmZkzzJkz/5lmAJlmM5lmZplmmZlmzJlm/5mZAJmZM5mZ
ZpmZmZmZzJmZ/5nMAJnMM5nMZpnMmZnMzJnM/5n/AJn/M5n/Zpn/mZn/zJn//8wAAMwAM8wAZswA
mcwAzMwA/8wzAMwzM8wzZswzmcwzzMwz/8xmAMxmM8xmZsxmmcxmzMxm/8yZAMyZM8yZZsyZmcyZ
zMyZ/8zMAMzMM8zMZszMmczMzMzM/8z/AMz/M8z/Zsz/mcz/zMz///8AAP8AM/8AZv8Amf8AzP8A
//8zAP8zM/8zZv8zmf8zzP8z//9mAP9mM/9mZv9mmf9mzP9m//+ZAP+ZM/+ZZv+Zmf+ZzP+Z///M
AP/MM//MZv/Mmf/MzP/M////AP//M///Zv//mf//zP///wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAAQABAIcAAAAAADMA
AGYAAJkAAMwAAP8AMwAAMzMAM2YAM5kAM8wAM/8AZgAAZjMAZmYAZpkAZswAZv8AmQAAmTMAmWYA
mZkAmcwAmf8AzAAAzDMAzGYAzJkAzMwAzP8A/wAA/zMA/2YA/5kA/8wA//8zAAAzADMzAGYzAJkz
AMwzAP8zMwAzMzMzM2YzM5kzM8wzM/8zZgAzZjMzZmYzZpkzZswzZv8zmQAzmTMzmWYzmZkzmcwz
mf8zzAAzzDMzzGYzzJkzzMwzzP8z/wAz/zMz/2Yz/5kz/8wz//9mAABmADNmAGZmAJlmAMxmAP9m
MwBmMzNmM2ZmM5lmM8xmM/9mZgBmZjNmZmZmZplmZsxmZv9mmQBmmTNmmWZmmZlmmcxmmf9mzABm
zDNmzGZmzJlmzMxmzP9m/wBm/zNm/2Zm/5lm/8xm//+ZAACZADOZAGaZAJmZAMyZAP+ZMwCZMzOZ
M2aZM5mZM8yZM/+ZZgCZZjOZZmaZZpmZZsyZZv+ZmQCZmTOZmWaZmZmZmcyZmf+ZzACZzDOZzGaZ
zJmZzMyZzP+Z/wCZ/zOZ/2aZ/5mZ/8yZ///MAADMADPMAGbMAJnMAMzMAP/MMwDMMzPMM2bMM5nM
M8zMM//MZgDMZjPMZmbMZpnMZszMZv/MmQDMmTPMmWbMmZnMmczMmf/MzADMzDPMzGbMzJnMzMzM
zP/M/wDM/zPM/2bM/5nM/8zM////AAD/ADP/AGb/AJn/AMz/AP//MwD/MzP/M2b/M5n/M8z/M///
ZgD/ZjP/Zmb/Zpn/Zsz/Zv//mQD/mTP/mWb/mZn/mcz/mf//zAD/zDP/zGb/zJn/zMz/zP///wD/
/zP//2b//5n//8z///8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAIBACvBQQAOw==
END
        Expected => 'image/gif',
    },
    {
        Name     => 'DetectMIMETypeFromBase64: Detect JPEG',
        Content  => <<'END',
/9j/4AAQSkZJRgABAQEAZABkAAD/2wBDAP//////////////////////////////////////////
////////////////////////////////////////////2wBDAf//////////////////////////
////////////////////////////////////////////////////////////wAARCAABAAEDASIA
AhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAP/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFAEB
AAAAAAAAAAAAAAAAAAAAAP/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AKAA/9k=
END
        Expected => 'image/jpeg',
    },
    {
        Name     => 'DetectMIMETypeFromBase64: Detect PNG',
        Content  => <<'END',
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAABbmlDQ1BpY2MAACiRdZE7SwNBFIW/
JIpBIxYqiFhsoWIRURTEUmORJkiICkZtkjUPIbsuuxsk2Ao2FgEL0cZX4T/QVrBVEARFELG09tWI
rHeMEJFkltn7cWbOZeYM+GMF3XAahsEwXTsRjWjzyQWt6ZkgnQQYZSilO9ZkPB6j7vi4xafqzaDq
VX9fzdGynHF08AWFx3TLdoUnhGNrrqV4S7hDz6eWhQ+Ew7YcUPhS6ekKPynOVfhNsT2bmAK/6qnl
/nD6D+t52xAeEO41CkX99zzqJqGMOTcjtVtmDw4JokTQSFNkhQIug1JNyay2b/jHN82qeHT5W5Sw
xZEjL96wqEXpmpGaFT0jX4GSyv1/nk52dKTSPRSBxkfPe+2Dpm34Knve56HnfR1B4AHOzap/VXIa
fxe9XNV696FtA04vqlp6B842oeveStmpHykg05/NwssJtCah/RqaFytZ/a5zfAez6/JEV7C7B/2y
v23pGytGaB4Ti1hlAAAACXBIWXMAAA9hAAAPYQGoP6dpAAAADElEQVQI12P4//8/AAX+Av7czFnn
AAAAAElFTkSuQmCC
END
        Expected => 'image/png',
    },
    {
        Name     => 'DetectMIMETypeFromBase64: Do NOT detect TIFF',
        Content  => <<'END',
SUkqAAwAAAD///8ADQAAAQMAAQAAAAEAAAABAQMAAQAAAAEAAAACAQMAAwAAAL4AAAADAQMAAQAA
AAEAAAAGAQMAAQAAAAIAAAARAQQAAQAAAAgAAAAVAQMAAQAAAAMAAAAWAQMAAQAAAAgAAAAXAQQA
AQAAAAMAAAAaAQUAAQAAAK4AAAAbAQUAAQAAALYAAAAcAQMAAQAAAAEAAABTAQMAAwAAAMQAAAAA
AAAA/////8lcjwL/////yVyPAggACAAIAAEAAQABAA==
END
        Expected => undef,
    },
);
for my $Test ( @Tests ) {
    my $MIMEType = $Kernel::OM->Get('LDAPUtils')->DetectMIMETypeFromBase64(
        Content => $Test->{Content},
    );

    $Self->Is(
        $MIMEType,
        $Test->{Expected},
        $Test->{Name},
    );
}

# prepare data for test image
my $TestImageBase64 = <<'END';
/9j/4AAQSkZJRgABAQEAZABkAAD/2wBDAAIBAQEBAQIBAQECAgICAgQDAgICAgUEBAMEBgUGBgYF
BgYGBwkIBgcJBwYGCAsICQoKCgoKBggLDAsKDAkKCgr/2wBDAQICAgICAgUDAwUKBwYHCgoKCgoK
CgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgr/wAARCAABAAEDASIA
AhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAn/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFAEB
AAAAAAAAAAAAAAAAAAAAAP/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AL+AA//Z
END
my $TestImage       = decode_base64($TestImageBase64);

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
my $OrganisationID3 =  $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => 'org1',
    Name    => 'Organisation 1',
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $OrganisationID3,
    'Created third organisation'
);
my $OrganisationID4 =  $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => 'org2',
    Name    => 'Organisation 2',
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $OrganisationID4,
    'Created fourth organisation'
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
        'Email'               => [
            'primaryMail',
            'mail'
        ],
        'Firstname'           => 'givenName',
        'Lastname'            => 'sn',
        'OrganisationIDs'     => [
            'SET:' . $OrganisationID1,
            'ou',
            'orgs'
        ],
        'PrimaryOrganisationID' => 'org',
        'City'                  => 'l',
        'Language'              => 'st',
        'Mobile'                => 'mobile',
        'Phone'                 => 'telephoneNumber',
        'Street'                => 'street',
        'Zip'                   => 'postalCode',
        'Comment'               => 'CONCAT:{sn}, {givenName} / {street}, {postalCode} {l}',
        'ImgThumbNail'          => 'TOBASE64:jpegPhoto',
        'ArrayTest'             => [
            'givenName',
            'sn'
        ],
        'ArrayIndex1'           => 'ARRAYINDEX[0]:orgs',
        'ArrayIndex2'           => 'ARRAYINDEX[2]:orgs',
        'ArrayIndex3'           => 'ARRAYINDEX[3]:orgs',
        'ArrayIndex4'           => 'ARRAYINDEX[0]:l',
        'ArrayIndex5'           => 'ARRAYINDEX[1]:l',
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
        primaryMail => 'max.mustermann@kixdesk.com',
        mail        => [
            'SMTP:max.mustermann@cape-it.de',
            'smtp:info@kixdesk.com',
            'max.mustermann@kixdesk.com',
            '',
            'dummy1@kixdesk.com',
            'dummy2@kixdesk.com',
            'dummy3@kixdesk.com',
            'dummy4@kixdesk.com'
        ],
        org         => $OrganisationID1,
        orgs        => [
            'org1',
            'Organisation 2',
            'unknown'
        ],
        l           => 'Chemnitz',
        postalCode  => '09113',
        street      => 'Schönherrstr. 8',
        jpegPhoto   => $TestImage,
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

ldap_mockify {
    # prepare data for mocked ldap
    my $ldap = Net::LDAP->new($SyncConfig->{Host});

    for my $TestUserDN ( keys( %TestUsers ) ) {
        $ldap->add( $TestUserDN, attr => $TestUsers{ $TestUserDN } );
    }
    for my $TestGroupDN ( keys( %TestGroups ) ) {
        $ldap->add( $TestGroupDN, attr => $TestGroups{ $TestGroupDN } );
    }

    my $Filter = "($SyncConfig->{UID}=" . escape_filter_value( 'syncuser1' ) . ')';
    my $Result = $ldap->search(
        base   => $SyncConfig->{BaseDN},
        filter => $Filter,
        attrs  => ['*','org','orgs','jpegPhoto'],
    );

    my $SyncContactRef = $Kernel::OM->Get('LDAPUtils')->ApplyContactMappingToLDAPResult(
        LDAPSearch           => $Result,
        Mapping              => $SyncConfig->{ContactUserSync},
        LDAPCharset          => 'utf-8',
        FallbackUnknownOrgID => 1,
    );
    $Self->IsDeeply(
        $SyncContactRef,
        {
            'DynamicField_Source' => 'LDAP: top, person, organizationalPerson, inetOrgPerson',
            'Email'               => 'max.mustermann@kixdesk.com',
            'Email1'              => 'max.mustermann@cape-it.de',
            'Email2'              => 'info@kixdesk.com',
            'Email3'              => 'dummy1@kixdesk.com',
            'Email4'              => 'dummy2@kixdesk.com',
            'Email5'              => 'dummy3@kixdesk.com',
            'Email6'              => 'dummy4@kixdesk.com',
            'Firstname'           => 'Max',
            'Lastname'            => 'Mustermann',
            'OrganisationIDs'     => [
                $OrganisationID1,
                $OrganisationID2,
                $OrganisationID3,
                $OrganisationID4,
                1,
            ],
            'PrimaryOrganisationID' => $OrganisationID1,
            'City'                  => 'Chemnitz',
            'Language'              => '',
            'Mobile'                => '',
            'Phone'                 => '',
            'Street'                => 'Schönherrstr. 8',
            'Zip'                   => '09113',
            'Comment'               => 'Mustermann, Max / Schönherrstr. 8, 09113 Chemnitz',
            'ImgThumbNail'          => <<'END',
/9j/4AAQSkZJRgABAQEAZABkAAD/2wBDAAIBAQEBAQIBAQECAgICAgQDAgICAgUEBAMEBgUGBgYF
BgYGBwkIBgcJBwYGCAsICQoKCgoKBggLDAsKDAkKCgr/2wBDAQICAgICAgUDAwUKBwYHCgoKCgoK
CgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgr/wAARCAABAAEDASIA
AhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAn/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFAEB
AAAAAAAAAAAAAAAAAAAAAP/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AL+AA//Z
END
            'ArrayTest'             => [
                'Max',
                'Mustermann'
            ],
            'ArrayIndex1'           => 'org1',
            'ArrayIndex2'           => 'unknown',
            'ArrayIndex3'           => '',
            'ArrayIndex4'           => 'Chemnitz',
            'ArrayIndex5'           => '',
        },
        'ApplyContactMappingToLDAPResult: Expected mapped data'
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