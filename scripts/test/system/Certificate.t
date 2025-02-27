# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use MIME::Base64;

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# check supported methods
for my $Method (
    qw(
        CertificateCreate CertificateExists CertificateGet
        CertificateDelete CertificateToFS Encrypt Decrypt
        Verify Sign
    )
) {
    $Self->True(
        $Kernel::OM->Get('Certificate')->can($Method),
        'Certificate can "' . $Method . q{"}
    );
}

# REMINDER:
# If there are problems with the certificates, they may have expired.
# Currently, they run until 2029 and 2034.
# Furthermore, these are self-signed certificates.

# begin transaction on database
$Helper->BeginWork();

my $HomeDir = $Kernel::OM->Get('Config')->Get('Home');
my @Certificates = _ReadCertificates();
my @Emails       = _ReadEmails();

my @NegativTests = (
    # CERTIFICATECREATE
    {
        Function => 'CertificateCreate',
        Data     => {},
        Expected => undef,
        Name     => 'Certificate: Create / Missing Paramters'
    },
    {
        Function => 'CertificateCreate',
        Data     => {
            Type       => 'Cert',
            CType      => 'SMIME'
        },
        Expected => undef,
        Name     => 'Certificate: Create / No File given'
    },
    {
        Function => 'CertificateCreate',
        Data     => {
            File => {
                %{$Certificates[0]},
                Content => undef
            },
            Type       => 'Cert',
            CType      => 'SMIME'
        },
        Expected => undef,
        Name     => 'Certificate: Create / No Content given'
    },
    {
        Function => 'CertificateCreate',
        Data     => {
            File  => $Certificates[0],
            CType => 'SMIME'
        },
        Expected => undef,
        Name     => 'Certificate: Create / No Type given'
    },
    {
        Function => 'CertificateCreate',
        Data     => {
            File  => $Certificates[0],
            Type  => 'Private',
            CType => 'SMIME'
        },
        Expected => undef,
        Name     => 'Certificate: Create / No Passphrase when type Private given'
    },
    # EO CERTIFICATECREATE
    # CERTIFICATEEXISTS
    {
        Function => 'CertificateExists',
        Data     => {},
        Expected => undef,
        Name     => 'Certificate: Exists / No Filename'
    },
    {
        Function => 'CertificateExists',
        Data     => {
            HasCertificate => 1
        },
        Expected => undef,
        Name     => 'Certificate: Exists / No Type / HasCertificate'
    },
    {
        Function => 'CertificateExists',
        Data     => {
            HasCertificate => 1,
            Type           => 'Private'
        },
        Expected => undef,
        Name     => 'Certificate: Exists / No Attributes'
    },
    # EO CERTIFICATEEXISTS
    # CERTIFICATEGET
    {
        Function => 'CertificateGet',
        Data     => {
        },
        Expected => undef,
        Name     => 'Certificate: Get / Missing Parameters'
    },
    {
        Function => 'CertificateGet',
        Data     => {
            ID => undef
        },
        Expected => undef,
        Name     => 'Certificate: Get / No ID'
    },
    # EO CERTIFICATEGET
    # CERTIFICATEDELETE
    {
        Function => 'CertificateDelete',
        Data     => {},
        Expected => undef,
        Name     => 'Certificate: Delete / Missing Parameters'
    },
    {
        Function => 'CertificateDelete',
        Data     => {
            ID => undef
        },
        Expected => undef,
        Name     => 'Certificate: Delete / No ID'
    },
    # EO CERTIFICATEDELETE
);

for my $Test ( @NegativTests ) {
    my $Function = $Test->{Function};
    my $Result   = $Kernel::OM->Get('Certificate')->$Function(
        %{$Test->{Data}},
        Silent => 1
    );

    $Self->Is(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

# Certificate: Create / Get / Exists
my @CertificateIDs;
my @TestsCGE = (
    {
        Function => 'CertificateCreate',
        Data     => {
            File       => $Certificates[1],
            Type       => 'Private',
            Passphrase => 'start123',
            CType      => 'SMIME',
            Silent     => 1
        },
        Expected => undef,
        Name     => 'Certificate: Create / Type .PEM | application/x-x509-ca-cert / Private Key / No Certificate exists'
    },
    {
        Function => 'CertificateCreate',
        Data     => {
            File  => $Certificates[0],
            Type  => 'Cert',
            CType => 'SMIME'
        },
        Expected => 1,
        Name     => 'Certificate: Create / Type .PEM | application/x-x509-ca-cert / Certificate'
    },
    {
        Function => 'CertificateGet',
        Data     => {
            ID => '###ID###'
        },
        Index    => 0,
        Expected => {
            'CType'       => 'SMIME',
            'Email'       => 'example@unittest.org',
            'EndDate'     => '2034-04-23 08:40:48',
            'FileID'      => '###ID###',
            'Filename'    => 'KIX_Cert_###ID###',
            'Filepath'    => $Kernel::OM->Get('Config')->Get('Home') . '/var/ssl/certs/KIX_Cert_###ID###',
            'Fingerprint' => '18:0D:E0:E2:A1:AC:C9:46:92:5A:C7:A1:72:28:33:78:0E:68:4E:07',
            'Hash'        => '2930f735',
            'Issuer'      => 'C =  DE, ST =  Saxony, L =  Example, O =  Example, OU =  Example, CN =  Example, emailAddress =  example@unittest.org',
            'Modulus'     => 'C1EB549A1D0AE1C1A7179A5E5C87AAC2482B448E6491CF335BB93A941EE5AA503F458557FE39C1AA6603FAD9C4BA8277042C9C260983E1820EDCA2379218BE946B09092B06B0DEBF91C13E47314443EE5267D3BF40B925009A4D246A5C003916BF2CF4ED350289EBBD63087638A5ED1A6D3B3A7B0DC5BF739ECB25FCFFF004BFB4FE0B4B5767C5FCEED8AFF8A28810AC30298F414AE70AA4B87A4ED5364B7BC6A82CFC880B356FC225C354ECB775F58E8E626FDA9CD79B09676F22F6025B1CB4BBAE818C3971020CD500F9B0AF4060DA6BA99D58EEAAC34442B4CF21A350DEA3D1394B45DB720AB3232A6CB3C17BA4D89440CDF9294C3BA60F2269C08DF0845B',
            'Serial'      => '5A01B5766B5C040B20CFF7E09E998A9B580BA0F4',
            'StartDate'   => '2024-04-25 08:40:48',
            'Subject'     => 'C =  DE, ST =  Saxony, L =  Example, O =  Example, OU =  Example, CN =  Example, emailAddress =  example@unittest.org',
            'Type'        => 'Cert'
        },
        Name     => 'Certificate: Get / Type .PEM | application/x-x509-ca-cert / Certificate'
    },
    {
        Function => 'CertificateGet',
        Data     => {
            ID      => '###ID###',
            Include => 'Content'
        },
        Index    => 0,
        Expected => {
            'CType'       => 'SMIME',
            'Email'       => 'example@unittest.org',
            'EndDate'     => '2034-04-23 08:40:48',
            'FileID'      => '###ID###',
            'Filename'    => 'KIX_Cert_###ID###',
            'Filepath'    => $Kernel::OM->Get('Config')->Get('Home') . '/var/ssl/certs/KIX_Cert_###ID###',
            'Fingerprint' => '18:0D:E0:E2:A1:AC:C9:46:92:5A:C7:A1:72:28:33:78:0E:68:4E:07',
            'Hash'        => '2930f735',
            'Issuer'      => 'C =  DE, ST =  Saxony, L =  Example, O =  Example, OU =  Example, CN =  Example, emailAddress =  example@unittest.org',
            'Modulus'     => 'C1EB549A1D0AE1C1A7179A5E5C87AAC2482B448E6491CF335BB93A941EE5AA503F458557FE39C1AA6603FAD9C4BA8277042C9C260983E1820EDCA2379218BE946B09092B06B0DEBF91C13E47314443EE5267D3BF40B925009A4D246A5C003916BF2CF4ED350289EBBD63087638A5ED1A6D3B3A7B0DC5BF739ECB25FCFFF004BFB4FE0B4B5767C5FCEED8AFF8A28810AC30298F414AE70AA4B87A4ED5364B7BC6A82CFC880B356FC225C354ECB775F58E8E626FDA9CD79B09676F22F6025B1CB4BBAE818C3971020CD500F9B0AF4060DA6BA99D58EEAAC34442B4CF21A350DEA3D1394B45DB720AB3232A6CB3C17BA4D89440CDF9294C3BA60F2269C08DF0845B',
            'Serial'      => '5A01B5766B5C040B20CFF7E09E998A9B580BA0F4',
            'StartDate'   => '2024-04-25 08:40:48',
            'Subject'     => 'C =  DE, ST =  Saxony, L =  Example, O =  Example, OU =  Example, CN =  Example, emailAddress =  example@unittest.org',
            'Type'        => 'Cert',
            'Content'     => <<'END'
LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUQrVENDQXVHZ0F3SUJBZ0lVV2dHMWRtdGNC
QXNnei9mZ25wbUttMWdMb1BRd0RRWUpLb1pJaHZjTkFRRUwKQlFBd2dZc3hDekFKQmdOVkJBWVRB
a1JGTVE4d0RRWURWUVFJREFaVFlYaHZibmt4RURBT0JnTlZCQWNNQjBWNApZVzF3YkdVeEVEQU9C
Z05WQkFvTUIwVjRZVzF3YkdVeEVEQU9CZ05WQkFzTUIwVjRZVzF3YkdVeEVEQU9CZ05WCkJBTU1C
MFY0WVcxd2JHVXhJekFoQmdrcWhraUc5dzBCQ1FFV0ZHVjRZVzF3YkdWQWRXNXBkSFJsYzNRdWIz
Sm4KTUI0WERUSTBNRFF5TlRBNE5EQTBPRm9YRFRNME1EUXlNekE0TkRBME9Gb3dnWXN4Q3pBSkJn
TlZCQVlUQWtSRgpNUTh3RFFZRFZRUUlEQVpUWVhodmJua3hFREFPQmdOVkJBY01CMFY0WVcxd2JH
VXhFREFPQmdOVkJBb01CMFY0CllXMXdiR1V4RURBT0JnTlZCQXNNQjBWNFlXMXdiR1V4RURBT0Jn
TlZCQU1NQjBWNFlXMXdiR1V4SXpBaEJna3EKaGtpRzl3MEJDUUVXRkdWNFlXMXdiR1ZBZFc1cGRI
UmxjM1F1YjNKbk1JSUJJakFOQmdrcWhraUc5dzBCQVFFRgpBQU9DQVE4QU1JSUJDZ0tDQVFFQXdl
dFVtaDBLNGNHbkY1cGVYSWVxd2tnclJJNWtrYzh6VzdrNmxCN2xxbEEvClJZVlgvam5CcW1ZRCt0
bkV1b0ozQkN5Y0pnbUQ0WUlPM0tJM2toaStsR3NKQ1NzR3NONi9rY0UrUnpGRVErNVMKWjlPL1FM
a2xBSnBOSkdwY0FEa1d2eXowN1RVQ2lldTlZd2gyT0tYdEdtMDdPbnNOeGI5em5zc2wvUC93Qkwr
MAovZ3RMVjJmRi9PN1lyL2lpaUJDc01DbVBRVXJuQ3FTNGVrN1ZOa3Q3eHFncy9JZ0xOVy9DSmNO
VTdMZDE5WTZPClltL2FuTmViQ1dkdkl2WUNXeHkwdTY2QmpEbHhBZ3pWQVBtd3IwQmcybXVwblZq
dXFzTkVRclRQSWFOUTNxUFIKT1V0RjIzSUtzeU1xYkxQQmU2VFlsRUROK1NsTU82WVBJbW5BamZD
RVd3SURBUUFCbzFNd1VUQWRCZ05WSFE0RQpGZ1FVOUVpTDdDVTIxWTI0NDh0L3lEekVJTGY4RmVj
d0h3WURWUjBqQkJnd0ZvQVU5RWlMN0NVMjFZMjQ0OHQvCnlEekVJTGY4RmVjd0R3WURWUjBUQVFI
L0JBVXdBd0VCL3pBTkJna3Foa2lHOXcwQkFRc0ZBQU9DQVFFQXNPUTIKWjVPa1Q2cG90elJVaDdE
eGUxUVlpR2xJdWVFNzQycWZLUnd1Q01tUFg0R3V5UnZjWXlSWlBxbjdRVWNHblhxVgpEWHJtdWJW
dkRrSmx2RzRYVWgvdlMzWEdLRFdIZFVVb0ZTUGp5QVRMOC9qWGdYVXpXdXN6a2EwOEhZejhEMEE0
CkRsZWJUNkk4SExMZmdLdGcwTUZKY0ZhL2Rib0dXSVlNcHNYYnpPOE1nQWo5enhyci93TlRnbzNP
U3VLTjFGbFYKR2JFa2Yrbk5vVEx0amdlQnU1OVg5NUhKclhURHN1bG9XbWN0aHQ4SFQvaEtqSGhZ
ODN5c3ZVdXFSWlQ2aER0eApsUmdRbE9ic2EzSFZPMnZ3MGczaVJ4dnNRVGl3WURxc2NmSHljZG93
VHVrV0FlQWRyWm9PY2xyR1hjbVJEc3JuCjRHSkRIU2hSNEJSL2grQWhVQT09Ci0tLS0tRU5EIENF
UlRJRklDQVRFLS0tLS0K
END
        },
        Name     => 'Certificate: Get / Type .PEM | application/x-x509-ca-cert / Certificate / Include Content'
    },
    {
        Function => 'CertificateExists',
        Data     => {
            Filename => 'Certificate/SMIME/Cert/###Fingerprint###',
            Silent   => 1
        },
        Index    => 0,
        Expected => 1,
        Name     => 'Certificate: Exists / Type .PEM | application/x-x509-ca-cert / Certificate'
    },
    {
        Function => 'CertificateCreate',
        Data     => {
            File       => $Certificates[1],
            Type       => 'Private',
            Passphrase => 'start123',
            CType      => 'SMIME'
        },
        Expected => 1,
        Name     => 'Certificate: Create / Type .PEM | application/x-x509-ca-cert / Private Key '
    },
    {
        Function => 'CertificateGet',
        Data     => {
            ID => '###ID###'
        },
        Index    => 1,
        Expected => {
            'CType'       => 'SMIME',
            'Email'       => 'example@unittest.org',
            'EndDate'     => '2034-04-23 08:40:48',
            'FileID'      => '###ID###',
            'Filename'    => 'KIX_Private_###ID###',
            'Filepath'    => $Kernel::OM->Get('Config')->Get('Home') . '/var/ssl/private/KIX_Private_###ID###',
            'Fingerprint' => '18:0D:E0:E2:A1:AC:C9:46:92:5A:C7:A1:72:28:33:78:0E:68:4E:07',
            'Hash'        => '2930f735',
            'Issuer'      => 'C =  DE, ST =  Saxony, L =  Example, O =  Example, OU =  Example, CN =  Example, emailAddress =  example@unittest.org',
            'Modulus'     => 'C1EB549A1D0AE1C1A7179A5E5C87AAC2482B448E6491CF335BB93A941EE5AA503F458557FE39C1AA6603FAD9C4BA8277042C9C260983E1820EDCA2379218BE946B09092B06B0DEBF91C13E47314443EE5267D3BF40B925009A4D246A5C003916BF2CF4ED350289EBBD63087638A5ED1A6D3B3A7B0DC5BF739ECB25FCFFF004BFB4FE0B4B5767C5FCEED8AFF8A28810AC30298F414AE70AA4B87A4ED5364B7BC6A82CFC880B356FC225C354ECB775F58E8E626FDA9CD79B09676F22F6025B1CB4BBAE818C3971020CD500F9B0AF4060DA6BA99D58EEAAC34442B4CF21A350DEA3D1394B45DB720AB3232A6CB3C17BA4D89440CDF9294C3BA60F2269C08DF0845B',
            'Serial'      => '5A01B5766B5C040B20CFF7E09E998A9B580BA0F4',
            'StartDate'   => '2024-04-25 08:40:48',
            'Subject'     => 'C =  DE, ST =  Saxony, L =  Example, O =  Example, OU =  Example, CN =  Example, emailAddress =  example@unittest.org',
            'Type'        => 'Private'
        },
        Name     => 'Certificate: Get / Type .PEM | application/x-x509-ca-cert / Private Key'
    },
    {
        Function => 'CertificateGet',
        Data     => {
            ID      => '###ID###',
            Include => 'Content'
        },
        Index    => 1,
        Expected => {
            'CType'       => 'SMIME',
            'Email'       => 'example@unittest.org',
            'EndDate'     => '2034-04-23 08:40:48',
            'FileID'      => '###ID###',
            'Filename'    => 'KIX_Private_###ID###',
            'Filepath'    => $Kernel::OM->Get('Config')->Get('Home') . '/var/ssl/private/KIX_Private_###ID###',
            'Fingerprint' => '18:0D:E0:E2:A1:AC:C9:46:92:5A:C7:A1:72:28:33:78:0E:68:4E:07',
            'Hash'        => '2930f735',
            'Issuer'      => 'C =  DE, ST =  Saxony, L =  Example, O =  Example, OU =  Example, CN =  Example, emailAddress =  example@unittest.org',
            'Modulus'     => 'C1EB549A1D0AE1C1A7179A5E5C87AAC2482B448E6491CF335BB93A941EE5AA503F458557FE39C1AA6603FAD9C4BA8277042C9C260983E1820EDCA2379218BE946B09092B06B0DEBF91C13E47314443EE5267D3BF40B925009A4D246A5C003916BF2CF4ED350289EBBD63087638A5ED1A6D3B3A7B0DC5BF739ECB25FCFFF004BFB4FE0B4B5767C5FCEED8AFF8A28810AC30298F414AE70AA4B87A4ED5364B7BC6A82CFC880B356FC225C354ECB775F58E8E626FDA9CD79B09676F22F6025B1CB4BBAE818C3971020CD500F9B0AF4060DA6BA99D58EEAAC34442B4CF21A350DEA3D1394B45DB720AB3232A6CB3C17BA4D89440CDF9294C3BA60F2269C08DF0845B',
            'Serial'      => '5A01B5766B5C040B20CFF7E09E998A9B580BA0F4',
            'StartDate'   => '2024-04-25 08:40:48',
            'Subject'     => 'C =  DE, ST =  Saxony, L =  Example, O =  Example, OU =  Example, CN =  Example, emailAddress =  example@unittest.org',
            'Type'        => 'Private',
            'Content'     => <<'END'
LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUV2QUlCQURBTkJna3Foa2lHOXcwQkFRRUZB
QVNDQktZd2dnU2lBZ0VBQW9JQkFRREI2MVNhSFFyaHdhY1gKbWw1Y2g2ckNTQ3RFam1TUnp6TmJ1
VHFVSHVXcVVEOUZoVmYrT2NHcVpnUDYyY1M2Z25jRUxKd21DWVBoZ2c3YwpvamVTR0w2VWF3a0pL
d2F3M3IrUndUNUhNVVJEN2xKbjA3OUF1U1VBbWswa2Fsd0FPUmEvTFBUdE5RS0o2NzFqCkNIWTRw
ZTBhYlRzNmV3M0Z2M09leXlYOC8vQUV2N1QrQzB0WFo4WDg3dGl2K0tLSUVLd3dLWTlCU3VjS3BM
aDYKVHRVMlMzdkdxQ3o4aUFzMWI4SWx3MVRzdDNYMWpvNWliOXFjMTVzSloyOGk5Z0piSExTN3Jv
R01PWEVDRE5VQQorYkN2UUdEYWE2bWRXTzZxdzBSQ3RNOGhvMURlbzlFNVMwWGJjZ3F6SXlwc3M4
RjdwTmlVUU0zNUtVdzdwZzhpCmFjQ044SVJiQWdNQkFBRUNnZ0VBTXAyTVBaV3JDM1lTZVJTdjRK
TUF2U2s5TWUzQXpsWTQzNDRmZmgzNmNGUDEKejkyWU5DRTdMWkRuSlFqR1VyQlBCR1hvYy8wejBS
NnpabDlwQmRjemwyWEF2QVhnL3pXRTV6UjdYdlc3RGNnYwo5a0RNd01ZU3BHK2lCd2xEN2tMNGJ2
bjdEQmMwREcvZHhRV21aZTdaVG5hSWFTRkpYUDQxM1pMRTNaNm9OWFNuCkxEeDZNeEdRK1Y3SnY2
NUlablllVHJScFZRdHVxTDFtYzIvUElYNjVEZ3NvaEVKbHpkZU1iVTRZSUMrUGd1Y1YKM3RuQnIz
VC9lNDJTTDNYWVc1dUk0a0pqVk9pL2xPODROZnFwSW5sYUFwMDhIOExVSzFaT0x2STAwNXRMenhn
VwpxRnhJVUdZZ1h0S05OQitTQkZ6ZkFuS290ZldTOUp6ZzJtQzVWVnkxOFFLQmdRRDlxNVNLMDIw
cHVUWTA3cnlFCmlubkdZRFNycUFjaGhvdjlsUUdFN0I5YS9PcHNOangvR3NJZzlqdXd0VlFDNW0y
NVlwWDBrTEVSby9QNTRxUVgKT0lxQU9hRlloZ2JBNUg4cUl4SHA0alRIM1VOT2pXYU8veDFzcEZ0
bXc5UGh3Sk56ZTltRkxDMUF3NEVkQXUxcApVdVJzYndlL2tTRFRGWHRMS3VDMGl5QmZaUUtCZ1FE
RHMwUWFLbTNJeWJJd0VIM2YxN2dNdllJaUN2Mjh4Z2lqCnFCNStOdDU2a2RPdkg3N0gzM1JXYjJV
VVpNVENmVFNpZ2JvNVBNN2lkbmRMQ0hmZnJmM012WUZiekRodFoybEIKRXBuUnpIQjg0bG5LYTdO
MXNuNnpIU2xBaC9PS0k2bWQ0QjdOd1JuYk1Tc0wyTDlXb2pwMTZjRkJSNlM2dWFQQgpNY21WSDZw
NHZ3S0JnRVJSRzFZd0RxdzM5ME5XTUdzNXFBWW5Ec2hVSG1lSEJ0aXFjcGhMeHo0SDgxSmxZUEdT
ClVVbnpScXdXaWFPbVQxS29IRjZiUVRUUkJQbjljZGZYSUdYY0gzbnB6cFBRZGZieEx2ZmdOZnJG
dWtURGpDVmkKeTVmZ3c4VHZaSGJlR0ZmM3VPTkd2SUUrcGQwY1ZyZ1EzUGZmQnlVdWZycWFoSFAv
L2poaFo3eUpBb0dBVmxsaQpBajJZWlZFQnE0MkxUTnBOSG1uNzRuT0JFK3M1WXFUS2w1dzBQRmJk
MVZhbmdsK0pZSjRVTnBSajhRRDMyWUJ1Ckg5VkIzOUN2d0U3RFBkSHl1NFVlYjlmRFNocW42WXVB
alg2c1g1NHNTbEdOUkxCMmtTZWJ6UnB2amhOQVF5WGgKMFoyVGdCREkwcGhYaksxV0tETDFENDND
RkpYV3VHYjBjRFVocmRjQ2dZQjFNems5TXdLNzlBRGw2V2pDVFRFOQppbkJQbmlsU2N6UDdHSzdS
VENpdVZiVnVYQ1J2eVJHaHZMazNjamFHSkNSUmducWVaS0tpQ09TZ3g0YnBndlBVCnJ6ZmU1UWVF
U0VxQTAwbGZmL08vMVlvTVU0YTY4NVkwOGt2WTBSTkl0dlBacEMyVm1ZTEpqL25IUUlDZWVRSEoK
TUVWd0FIYUlhWXh3dE9CUXBNZFFuZz09Ci0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0K
END
        },
        Name     => 'Certificate: Get / Type .PEM | application/x-x509-ca-cert / Private Key / Include Content'
    },
    {
        Function => 'CertificateExists',
        Data     => {
            Modulus         => '###Modulus###',
            Type            => 'Private',
            HasCertificate  => 1,
            CType           => 'SMIME',
            Silent          => 1
        },
        Index    => 1,
        Expected => 1,
        Name     => 'Certificate: Exists / Type .PEM | application/x-x509-ca-cert / Private Key / Exists Certificate'
    },
    {
        Function => 'CertificateExists',
        Data     => {
            Filename => 'Certificate/SMIME/Private/###Fingerprint###',
            Silent   => 1
        },
        Index    => 1,
        Expected => 1,
        Name     => 'Certificate: Exists / Type .PEM | application/x-x509-ca-cert / Private Key'
    },
    {
        Function => 'CertificateCreate',
        Data     => {
            File  => $Certificates[2],
            Type  => 'Cert',
            CType => 'SMIME'
        },
        Expected => 1,
        Name     => 'Certificate: Create / Type .CRT | application/pkix-cert / Certificate'
    },
    {
        Function => 'CertificateGet',
        Data     => {
            ID => '###ID###'
        },
        Index    => 2,
        Expected => {
            'CType'       => 'SMIME',
            'Email'       => 'example@unittest.org',
            'EndDate'     => '2029-04-24 08:44:04',
            'FileID'      => '###ID###',
            'Filename'    => 'KIX_Cert_###ID###',
            'Filepath'    => $Kernel::OM->Get('Config')->Get('Home') . '/var/ssl/certs/KIX_Cert_###ID###',
            'Fingerprint' => 'CE:9A:76:C0:B4:8A:C4:B6:C7:3D:CF:F4:A9:A5:CC:60:3D:E9:7D:47',
            'Hash'        => 'a292bbe5',
            'Issuer'      => 'C =  DE, L =  Example, O =  Example, CN =  Unit Test, emailAddress =  example@unittest.org',
            'Modulus'     => 'C3914528F589E7AAC8F55DECD9E2AF9F2FAF0667E8B5E63522A80748E6A1F96E7BA5EEC024DEBDB94A70FC2679EB5ECE77B26F9CFBAC96C065753A008FA8D888116C3DFAAA43DE313356D83FD794031DB70F01BF3007F12185A763F0B55A10EAA306492B2504323AD1F7904263F775E5AE47750F7AA7A6F367614F7F6519F8E56438A0F279931CD1955DC4F6368CFED754CA3EE1295A0C8EFB64272042901445272D9E573027754B2FE8DA92B9C8948B53EBCDDE62BFF8FBCCEDBC46A3FC843B52DBCDEDE084913B6CA23FB95B90C9CE1427DF30DEAC6359FBE9EC501A9C2F368387D22DAACCD726DF3F66D9CA26C7BCBEBD643C066A566CD15A14EDED0EEFCF',
            'Serial'      => '02E3486D597C5309C1CAA42F83021DB43A6DDE9D',
            'StartDate'   => '2024-04-25 08:44:04',
            'Subject'     => 'C =  DE, L =  Example, O =  Example, CN =  Unit Test, emailAddress =  example@unittest.org',
            'Type'        => 'Cert'
        },
        Name     => 'Certificate: Get / Type .CRT | application/pkix-cert / Certificate'
    },
    {
        Function => 'CertificateGet',
        Data     => {
            ID      => '###ID###',
            Include => 'Content'
        },
        Index    => 2,
        Expected => {
            'CType'       => 'SMIME',
            'Email'       => 'example@unittest.org',
            'EndDate'     => '2029-04-24 08:44:04',
            'FileID'      => '###ID###',
            'Filename'    => 'KIX_Cert_###ID###',
            'Filepath'    => $Kernel::OM->Get('Config')->Get('Home') . '/var/ssl/certs/KIX_Cert_###ID###',
            'Fingerprint' => 'CE:9A:76:C0:B4:8A:C4:B6:C7:3D:CF:F4:A9:A5:CC:60:3D:E9:7D:47',
            'Hash'        => 'a292bbe5',
            'Issuer'      => 'C =  DE, L =  Example, O =  Example, CN =  Unit Test, emailAddress =  example@unittest.org',
            'Modulus'     => 'C3914528F589E7AAC8F55DECD9E2AF9F2FAF0667E8B5E63522A80748E6A1F96E7BA5EEC024DEBDB94A70FC2679EB5ECE77B26F9CFBAC96C065753A008FA8D888116C3DFAAA43DE313356D83FD794031DB70F01BF3007F12185A763F0B55A10EAA306492B2504323AD1F7904263F775E5AE47750F7AA7A6F367614F7F6519F8E56438A0F279931CD1955DC4F6368CFED754CA3EE1295A0C8EFB64272042901445272D9E573027754B2FE8DA92B9C8948B53EBCDDE62BFF8FBCCEDBC46A3FC843B52DBCDEDE084913B6CA23FB95B90C9CE1427DF30DEAC6359FBE9EC501A9C2F368387D22DAACCD726DF3F66D9CA26C7BCBEBD643C066A566CD15A14EDED0EEFCF',
            'Serial'      => '02E3486D597C5309C1CAA42F83021DB43A6DDE9D',
            'StartDate'   => '2024-04-25 08:44:04',
            'Subject'     => 'C =  DE, L =  Example, O =  Example, CN =  Unit Test, emailAddress =  example@unittest.org',
            'Type'        => 'Cert',
            'Content'     => <<'END'
LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURtekNDQW9PZ0F3SUJBZ0lVQXVOSWJWbDhV
d25CeXFRdmd3SWR0RHB0M3Awd0RRWUpLb1pJaHZjTkFRRUwKQlFBd2FqRUxNQWtHQTFVRUJoTUNS
RVV4RURBT0JnTlZCQWNNQjBWNFlXMXdiR1V4RURBT0JnTlZCQW9NQjBWNApZVzF3YkdVeEVqQVFC
Z05WQkFNTUNWVnVhWFFnVkdWemRERWpNQ0VHQ1NxR1NJYjNEUUVKQVJZVVpYaGhiWEJzClpVQjFi
bWwwZEdWemRDNXZjbWN3SGhjTk1qUXdOREkxTURnME5EQTBXaGNOTWprd05ESTBNRGcwTkRBMFdq
QnEKTVFzd0NRWURWUVFHRXdKRVJURVFNQTRHQTFVRUJ3d0hSWGhoYlhCc1pURVFNQTRHQTFVRUNn
d0hSWGhoYlhCcwpaVEVTTUJBR0ExVUVBd3dKVlc1cGRDQlVaWE4wTVNNd0lRWUpLb1pJaHZjTkFR
a0JGaFJsZUdGdGNHeGxRSFZ1CmFYUjBaWE4wTG05eVp6Q0NBU0l3RFFZSktvWklodmNOQVFFQkJR
QURnZ0VQQURDQ0FRb0NnZ0VCQU1PUlJTajEKaWVlcXlQVmQ3Tm5pcjU4dnJ3Wm42TFhtTlNLb0Iw
am1vZmx1ZTZYdXdDVGV2YmxLY1B3bWVldGV6bmV5YjV6NwpySmJBWlhVNkFJK28ySWdSYkQzNnFr
UGVNVE5XMkQvWGxBTWR0dzhCdnpBSDhTR0ZwMlB3dFZvUTZxTUdTU3NsCkJESTYwZmVRUW1QM2Rl
V3VSM1VQZXFlbTgyZGhUMzlsR2ZqbFpEaWc4bm1USE5HVlhjVDJOb3orMTFUS1B1RXAKV2d5Tysy
UW5JRUtRRkVVbkxaNVhNQ2QxU3kvbzJwSzV5SlNMVSt2TjNtSy8rUHZNN2J4R28veUVPMUxiemUz
ZwpoSkU3YktJL3VWdVF5YzRVSjk4dzNxeGpXZnZwN0ZBYW5DODJnNGZTTGFyTTF5YmZQMmJaeWli
SHZMNjlaRHdHCmFsWnMwVm9VN2UwTzc4OENBd0VBQWFNNU1EY3dDUVlEVlIwVEJBSXdBREFMQmdO
VkhROEVCQU1DQmVBd0hRWUQKVlIwbEJCWXdGQVlJS3dZQkJRVUhBd0lHQ0NzR0FRVUZCd01FTUEw
R0NTcUdTSWIzRFFFQkN3VUFBNElCQVFDQgpRUi9DNVZmcSs1VEZaODN6VU9za0hHRGMxZkhWcGlL
dG5CamF1SEUyaEJwb0s0V0xtbGtXM0xtRkRGVDltS0VFCi8vaXU1WTRFdzVwZ01ZY0UrcFZwYkdE
SzZkbXgxTGlVWEhSOXNFclRxdUZ0RFA4TEdtaktVdVEwd3JNcytpUUwKUHFQWktnalJvZjRHcFFX
eG1mWWhEazIzNWNlYkpkZXZGczIwT3V4Y3pZanJDVm1aQkxlVTk1MjYrNEJZT2dlawpDMmp2czM0
NVNtc3FTN1htVnZ5WjNINTFRdjRwMmR3OFh3a0pOWm54U3lOUWl4R1E3M3ZIcDUxTDIvTHd0WGhZ
CjJmMVhHZ3pybkxzYlBmWDQ1TFhLSTJLbGhUR1RtQUtZckxydFd4MlpDTEs1WmUxaEhHUmoxdURU
Zy9oa3ZMQjQKanorZkFnOEx0dWovMW9kK09zWWIKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
END
        },
        Name     => 'Certificate: Get / Type .CRT | application/pkix-cert / Certificate / Include Content'
    },
    {
        Function => 'CertificateExists',
        Data     => {
            Filename => 'Certificate/SMIME/Cert/###Fingerprint###',
            Silent   => 1
        },
        Index    => 2,
        Expected => 1,
        Name     => 'Certificate: Exists / Type .CRT | application/pkix-cert / Certificate'
    },
    {
        Function => 'CertificateCreate',
        Data     => {
            File  => $Certificates[3],
            Type  => 'Cert',
            CType => 'SMIME'
        },
        Expected => 1,
        Name     => 'Certificate: Create / Type .CSR | application/pkcs10 / Certificate'
    },
    {
        Function => 'CertificateGet',
        Data     => {
            ID => '###ID###'
        },
        Index    => 3,
        Expected => {
            'CType'       => 'SMIME',
            'FileID'      => '###ID###',
            'Filename'    => 'KIX_Cert_###ID###',
            'Filepath'    => $Kernel::OM->Get('Config')->Get('Home') . '/var/ssl/certs/KIX_Cert_###ID###',
            'Fingerprint' => 'da:39:a3:ee:5e:6b:4b:0d:32:55:bf:ef:95:60:18:90:af:d8:07:09',
            'Modulus'     => 'C3914528F589E7AAC8F55DECD9E2AF9F2FAF0667E8B5E63522A80748E6A1F96E7BA5EEC024DEBDB94A70FC2679EB5ECE77B26F9CFBAC96C065753A008FA8D888116C3DFAAA43DE313356D83FD794031DB70F01BF3007F12185A763F0B55A10EAA306492B2504323AD1F7904263F775E5AE47750F7AA7A6F367614F7F6519F8E56438A0F279931CD1955DC4F6368CFED754CA3EE1295A0C8EFB64272042901445272D9E573027754B2FE8DA92B9C8948B53EBCDDE62BFF8FBCCEDBC46A3FC843B52DBCDEDE084913B6CA23FB95B90C9CE1427DF30DEAC6359FBE9EC501A9C2F368387D22DAACCD726DF3F66D9CA26C7BCBEBD643C066A566CD15A14EDED0EEFCF',
            'Subject'     => 'C =  DE, L =  Example, O =  Example, CN =  Unit Test, emailAddress =  example@unittest.org',
            'Type'        => 'Cert'
        },
        Name     => 'Certificate: Get / Type .CSR | application/pkcs10 / Certificate'
    },
    {
        Function => 'CertificateGet',
        Data     => {
            ID      => '###ID###',
            Include => 'Content'
        },
        Index    => 3,
        Expected => {
            'CType'       => 'SMIME',
            'FileID'      => '###ID###',
            'Filename'    => 'KIX_Cert_###ID###',
            'Filepath'    => $Kernel::OM->Get('Config')->Get('Home') . '/var/ssl/certs/KIX_Cert_###ID###',
            'Fingerprint' => 'da:39:a3:ee:5e:6b:4b:0d:32:55:bf:ef:95:60:18:90:af:d8:07:09',
            'Modulus'     => 'C3914528F589E7AAC8F55DECD9E2AF9F2FAF0667E8B5E63522A80748E6A1F96E7BA5EEC024DEBDB94A70FC2679EB5ECE77B26F9CFBAC96C065753A008FA8D888116C3DFAAA43DE313356D83FD794031DB70F01BF3007F12185A763F0B55A10EAA306492B2504323AD1F7904263F775E5AE47750F7AA7A6F367614F7F6519F8E56438A0F279931CD1955DC4F6368CFED754CA3EE1295A0C8EFB64272042901445272D9E573027754B2FE8DA92B9C8948B53EBCDDE62BFF8FBCCEDBC46A3FC843B52DBCDEDE084913B6CA23FB95B90C9CE1427DF30DEAC6359FBE9EC501A9C2F368387D22DAACCD726DF3F66D9CA26C7BCBEBD643C066A566CD15A14EDED0EEFCF',
            'Subject'     => 'C =  DE, L =  Example, O =  Example, CN =  Unit Test, emailAddress =  example@unittest.org',
            'Type'        => 'Cert',
            'Content'     => <<'END'
LS0tLS1CRUdJTiBDRVJUSUZJQ0FURSBSRVFVRVNULS0tLS0KTUlJQ3J6Q0NBWmNDQVFBd2FqRUxN
QWtHQTFVRUJoTUNSRVV4RURBT0JnTlZCQWNNQjBWNFlXMXdiR1V4RURBTwpCZ05WQkFvTUIwVjRZ
VzF3YkdVeEVqQVFCZ05WQkFNTUNWVnVhWFFnVkdWemRERWpNQ0VHQ1NxR1NJYjNEUUVKCkFSWVVa
WGhoYlhCc1pVQjFibWwwZEdWemRDNXZjbWN3Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3
QXcKZ2dFS0FvSUJBUUREa1VVbzlZbm5xc2oxWGV6WjRxK2ZMNjhHWitpMTVqVWlxQWRJNXFINWJu
dWw3c0FrM3IyNQpTbkQ4Sm5uclhzNTNzbStjKzZ5V3dHVjFPZ0NQcU5pSUVXdzkrcXBEM2pFelZ0
Zy8xNVFESGJjUEFiOHdCL0VoCmhhZGo4TFZhRU9xakJra3JKUVF5T3RIM2tFSmo5M1hscmtkMUQz
cW5wdk5uWVU5L1pSbjQ1V1E0b1BKNWt4elIKbFYzRTlqYU0vdGRVeWo3aEtWb01qdnRrSnlCQ2tC
UkZKeTJlVnpBbmRVc3Y2TnFTdWNpVWkxUHJ6ZDVpdi9qNwp6TzI4UnFQOGhEdFMyODN0NElTUk8y
eWlQN2xia01uT0ZDZmZNTjZzWTFuNzZleFFHcHd2Tm9PSDBpMnF6TmNtCjN6OW0yY29teDd5K3ZX
UThCbXBXYk5GYUZPM3REdS9QQWdNQkFBR2dBREFOQmdrcWhraUc5dzBCQVFzRkFBT0MKQVFFQWho
QjRjd1BmdXVKSUc4MW1pU2RPdzVIZ3kzRzUrZXVNbUxhYmQ2THBzMXpzRURGVHFheHZ4ZXNGQmxj
aApsanJsaWlFNnNrcjBmb2VXNjdaODllUnY0V3FMTjhrNmlPN0Z2NXBEMWJ5cGpGQmVWdFpMQVky
RHk4bWFGcE00CnpHb2pMdjQxR0FlaitNYUVCa3lKR3BxalVvVEpPY3VsTmpBeXNKUVFCNnNEL0tq
Rk9WRXN4d1A0SUhueTQvK0cKYUxCM3ZZQnQ0UmNybks0Z2JuV216NXloZ2JGbFlPNW1lNVd2UHpD
cTVxK2Nhb2RjaHpRYjFVWGhMY2NsWHdjTgpuY3pMNjUzV0Q1czFGcGRSWUNoOCtYTStJaUNid1p2
b1M0TmNycTgxUDQzMndqZjlwdExiRURMYWJsakJMZkZXCjdLUEhYNGtJSWpPUDhGUXhIZ3Y5Y0I2
SVVBPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUgUkVRVUVTVC0tLS0tCg==
END
        },
        Name     => 'Certificate: Get / Type .CSR | application/pkcs10 / Certificate / Include Content'
    },
    {
        Function => 'CertificateExists',
        Data     => {
            Filename => 'Certificate/SMIME/Cert/###Fingerprint###',
            Silent   => 1
        },
        Index    => 3,
        Expected => 1,
        Name     => 'Certificate: Exists / Type .CSR | application/pkcs10 / Certificate'
    },
    {
        Function => 'CertificateCreate',
        Data     => {
            File       => $Certificates[4],
            Type       => 'Private',
            Passphrase => 'start123',
            CType      => 'SMIME'
        },
        Expected => 1,
        Name     => 'Certificate: Create / Type .KEY | application/x-iwork-keynote-sffkey / Private Key '
    },
    {
        Function => 'CertificateGet',
        Data     => {
            ID => '###ID###'
        },

        Index    => 4,
        Expected => {
            'CType'       => 'SMIME',
            'EndDate'     => '2029-04-24 08:44:04',
            'Email'       => 'example@unittest.org',
            'FileID'      => '###ID###',
            'Filename'    => 'KIX_Private_###ID###',
            'Filepath'    => $Kernel::OM->Get('Config')->Get('Home') . '/var/ssl/private/KIX_Private_###ID###',
            'Fingerprint' => 'CE:9A:76:C0:B4:8A:C4:B6:C7:3D:CF:F4:A9:A5:CC:60:3D:E9:7D:47',
            'Hash'        => 'a292bbe5',
            'Issuer'      => 'C =  DE, L =  Example, O =  Example, CN =  Unit Test, emailAddress =  example@unittest.org',
            'Modulus'     => 'C3914528F589E7AAC8F55DECD9E2AF9F2FAF0667E8B5E63522A80748E6A1F96E7BA5EEC024DEBDB94A70FC2679EB5ECE77B26F9CFBAC96C065753A008FA8D888116C3DFAAA43DE313356D83FD794031DB70F01BF3007F12185A763F0B55A10EAA306492B2504323AD1F7904263F775E5AE47750F7AA7A6F367614F7F6519F8E56438A0F279931CD1955DC4F6368CFED754CA3EE1295A0C8EFB64272042901445272D9E573027754B2FE8DA92B9C8948B53EBCDDE62BFF8FBCCEDBC46A3FC843B52DBCDEDE084913B6CA23FB95B90C9CE1427DF30DEAC6359FBE9EC501A9C2F368387D22DAACCD726DF3F66D9CA26C7BCBEBD643C066A566CD15A14EDED0EEFCF',
            'Serial'      => '02E3486D597C5309C1CAA42F83021DB43A6DDE9D',
            'StartDate'   => '2024-04-25 08:44:04',
            'Subject'     => 'C =  DE, L =  Example, O =  Example, CN =  Unit Test, emailAddress =  example@unittest.org',
            'Type'        => 'Private'
        },
        Name     => 'Certificate: Get / Type .KEY | application/x-iwork-keynote-sffkey / Private Key'
    },
    {
        Function => 'CertificateGet',
        Data     => {
            ID      => '###ID###',
            Include => 'Content'
        },

        Index    => 4,
        Expected => {
            'CType'       => 'SMIME',
            'EndDate'     => '2029-04-24 08:44:04',
            'Email'       => 'example@unittest.org',
            'FileID'      => '###ID###',
            'Filename'    => 'KIX_Private_###ID###',
            'Filepath'    => $Kernel::OM->Get('Config')->Get('Home') . '/var/ssl/private/KIX_Private_###ID###',
            'Fingerprint' => 'CE:9A:76:C0:B4:8A:C4:B6:C7:3D:CF:F4:A9:A5:CC:60:3D:E9:7D:47',
            'Hash'        => 'a292bbe5',
            'Issuer'      => 'C =  DE, L =  Example, O =  Example, CN =  Unit Test, emailAddress =  example@unittest.org',
            'Modulus'     => 'C3914528F589E7AAC8F55DECD9E2AF9F2FAF0667E8B5E63522A80748E6A1F96E7BA5EEC024DEBDB94A70FC2679EB5ECE77B26F9CFBAC96C065753A008FA8D888116C3DFAAA43DE313356D83FD794031DB70F01BF3007F12185A763F0B55A10EAA306492B2504323AD1F7904263F775E5AE47750F7AA7A6F367614F7F6519F8E56438A0F279931CD1955DC4F6368CFED754CA3EE1295A0C8EFB64272042901445272D9E573027754B2FE8DA92B9C8948B53EBCDDE62BFF8FBCCEDBC46A3FC843B52DBCDEDE084913B6CA23FB95B90C9CE1427DF30DEAC6359FBE9EC501A9C2F368387D22DAACCD726DF3F66D9CA26C7BCBEBD643C066A566CD15A14EDED0EEFCF',
            'Serial'      => '02E3486D597C5309C1CAA42F83021DB43A6DDE9D',
            'StartDate'   => '2024-04-25 08:44:04',
            'Subject'     => 'C =  DE, L =  Example, O =  Example, CN =  Unit Test, emailAddress =  example@unittest.org',
            'Type'        => 'Private',
            'Content'     => <<'END'
LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpQcm9jLVR5cGU6IDQsRU5DUllQVEVECkRF
Sy1JbmZvOiBERVMtRURFMy1DQkMsNzlFOUY1N0NENzgwQ0NGOAoKOG92aHhYbmR0ZUFSczVYZkky
OGtiUTNDb0IvYkJoU0t4TVlHZk91eVBpOTVMZHFCYzlPVFAzblhlVUxFK2h2bAorQzVhNzhvbUk1
MVlWVWRwR2ZraUpwOWZrR2FXZ2RqU1RRSU9YWTZDSU5tNWpXZ1BadXlLbS9kU1JzTFg0M2w0Ci94
elRObm5GdVJ5UUI2RTB6bWFyMmlZMEZ5OXEvTnY5cjN5NS9QSmU0TVJTK3F4OWNEMEdyajd5TW5N
c3U3ZUcKc2pMYy9XVDQzeTBuaFZxSmlNbmlLaXN4OE4yVURMZmtUTGtpY3k5MjI2eW9Pek4zT3Y0
cWFFWWhzeFEvYUxxRwovcmVpZ2RoMjBLZTl6QTF2MzlzSGZkRzgyZVJhS2hUVmYxUGdZdVRwdGVk
Y0lkR2FYSGVIOE1CbWlwSEttTGlTClA3a2M2aUplcXp2Y2txVEZQRTBzSWJtQ1JsUDFXVVdLMTRn
Q0FROEN2R0g0WlN6WWlrMDNmODlNZE1hSVRFbGEKeUxMN2VQSmdPRWh6N3RyUVlZejZQTzNRUzlZ
ZGZSRDRRSXk2T1MyRFJSMmx3QUZ0cmJ6NW5zTEZOZHllTTBOVQoyM2JwWEdxWml6VHI0Vkhod090
T09TaWJxTU5SU1VYbTZXMW4xNmlnVElKU054em1WK0MzaFl3OFNjdzlFWDZiCnVOMDhqTWdDVkRB
WnRqZ2k0K1d1SzR3c3h4YUpjMElsS0ZZa1dEcTA3Y09ZWDkzbXl6SmxpZS9Eb29IeGNidHYKWDVS
K2dkMVdNMFE3N2gybTNJc0JCN3BIekhRcTRyTk03OEpjdVNHdTNqZjBlUGcyVzdxaGcza2I0R3Zj
SnZzOQpTb04vM2FRckVOT0t1by9ocDVEdXVzaklLOG5qWFlnNFRpNC9WSlAvWm81VDVQQncxWlRK
dU5lMTJmRGxqUHA5Ci8xUFgrTUZHa2U4enVnUDN2Y0ROc2lueEhKV1hUMTJRcGxVZ2UxM2ZiaWNS
bCt3WTk3Z2dJV1R6RHluS0paclIKcDZpKzFiU3phT0haQnl1Wlh3VUlTMkpzTis4SUxGK1NnZklZ
VVRIa3U3WE1iV2phQytYYTVXUE5aWWdFM0RhdApMcjNJcHVCOEp6SzZpS0JzS3U3WkZaektNWjU0
U00zc29rTGNHQnlham43VlRsdnIxOWY4enIzclpEZGN0emFqCkFpdXdTWXVwVEk4dDcrNDdwQnBi
eHM3QzVoUGQ0bTFFakJLZ2E5WUtwSm9oeG9qd25Ba0EzclJENnhpOWdGMkEKelM0cVU1cU1jNDA1
TWNIKytoaWR2K1YrTG9pV0xzMkFWbjFIcTBUbHBPMGNjOS95dURIOVczRDBIL3pueHQzQQprdzhp
WUUrQVl3TXNVNVREd0J1YWQ2ZmJLTlRoY1Y3SjNzSG9DRHdaOUYxUCtCOGRwWDBCRFR1MGJrcUo5
clFyCnpsemNiV1V4ZEwybmxLNmp0bVhvZ3IwSko4QyszSXV3YmZhMUpSZVFmaXBFSldXaE5SRXJU
Sm5jWk1heDNUWU4KeEtBSU9uS2U2RmE4Um80bjNBbWFxeHAxMWREUkVDUUdwbjZSZjNUbzlvMXBl
K0VRSENybzM1MFhFT0FlTjJ1Vgp3ZnhQYXZSeTd5bDVORzY3dis3RWYyTUJyQXpqOVI2b2h2ZWNw
N0I2NnBpcDVkTlFWbGp4UUhBNkVHQ3JWSWZBCkNnWEpBUCtKMStvdXRuOXIyWXE5bG9PQ0lubEFl
NWV3aDJGTHVzbk5KaS9CU2krMVhlOXBTK2hWdWZqdCtxM2QKemtOLzFBOFFDTFJZekJtaGRHRW1z
aHFVTm5SdjFXS2t3ZXRlKzVROU4rbitzNDBxUUpvcW1tbVMwcjA3VkwxcQpPd0RpU0pMUDhuRVh1
dzdBa01sNDdnMHFWZnVmZTVFUG1RTjg5ajJjSVNJdzkzRkxHeUZtWVp3WGhoOVVoVDhPClFxTHVj
YkJXVWcveDU2Q2xuRk8zZDZlOXNtcWtxblVlVDZRNHVZZmZhV1ZBTXBEVFVEVXNKT3hQUFB1RnNC
b2gKUjVkU0lWVy9wQWh4bUJ4eE0vUGRiaGZOTU5zWFF2dWx6eEpMRUZpaFFBUlNURGZBV2tENExF
SUNDc2poL1lPLwotLS0tLUVORCBSU0EgUFJJVkFURSBLRVktLS0tLQo=
END
        },
        Name     => 'Certificate: Get / Type .KEY | application/x-iwork-keynote-sffkey / Private Key / Include Content'
    },
    {
        Function => 'CertificateExists',
        Data     => {
            Modulus         => '###Modulus###',
            Type            => 'Private',
            HasCertificate  => 1,
            CType           => 'SMIME',
            Silent          => 1
        },
        Index    => 4,
        Expected => 1,
        Name     => 'Certificate: Exists / Type .KEY | application/x-iwork-keynote-sffkey / Private Key / Exists Certificate'
    },
    {
        Function => 'CertificateExists',
        Data     => {
            Filename => 'Certificate/SMIME/Private/###Fingerprint###',
            Silent   => 1
        },
        Index    => 4,
        Expected => 1,
        Name     => 'Certificate: Exists / Type .KEY | application/x-iwork-keynote-sffkey / Private Key'
    },
);

for my $Test ( @TestsCGE ) {
    my $Function = $Test->{Function};

    my $Data = $Test;
    if ( defined $Test->{Index} ) {
        my $Tmp = $Kernel::OM->Get('JSON')->Encode(
            Data => $Data
        );
        for my $Key ( keys %{$CertificateIDs[$Test->{Index}]} ) {
            my $Pattern = "###$Key###";
            my $Replace = $CertificateIDs[$Test->{Index}]->{$Key};

            $Tmp =~ s/$Pattern/$Replace/g;
        }

        $Data = $Kernel::OM->Get('JSON')->Decode(
            Data => $Tmp
        );
    }

    if (
        $Function eq 'CertificateGet'
        && scalar(@CertificateIDs)
    ) {
        $Data->{Data}->{ID} = $CertificateIDs[$Data->{Index}]->{ID};
    }

    my $Result   = $Kernel::OM->Get('Certificate')->$Function(
        %{$Data->{Data}}
    );

    if ( $Function eq 'CertificateGet' ) {
        $Self->IsDeeply(
            $Result,
            $Data->{Expected},
            $Data->{Name}
        );
    }
    else {
        if ( $Data->{Expected} ) {
            $Self->True(
                $Result,
                $Data->{Name}
            );
        }
        else {
            $Self->False(
                $Result,
                $Data->{Name}
            );
        }
    }

    if (
        $Function eq 'CertificateCreate'
        && $Result
    ) {
        push(
            @CertificateIDs,
            {
                ID => $Result
            }
        );
    }

    if (
        $Function eq 'CertificateGet'
        && $Result
    ) {
        %{$CertificateIDs[$Data->{Index}]} = (
            %{$CertificateIDs[$Data->{Index}]},
            %{$Result}
        );
    }

    $Kernel::OM->ObjectsDiscard(
        Objects => ['Certificate'],
    );
}

# Certificate: Sign / Encrypt / Verify / Decrypt
my $IgnoreEmailPattern = $Kernel::OM->Get('Config')->Get('IgnoreEmailAddressesAsRecipients');
my @TestsSE = (
    {
        Functions => [ 'Sign' ],
        Data      => {
            To       => 'friend@example.com',
            Subject  => 'UnitTest Sign!',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
            Body     => 'Some nice text',
            Silent   => 1
        },
        Expected => [
            undef
        ],
        Name     => 'Certificate: Sign / no From / no sign'
    },
    {
        Functions => [ 'Sign' ],
        Data      => {
            From     => 'me@example.com',
            To       => 'friend@example.com',
            Subject  => 'UnitTest Sign!',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
            Body     => 'Some nice text',
            Silent   => 1
        },
        Expected => [
            []
        ],
        Name     => 'Certificate: Sign / no sign'
    },
    {
        Functions => [ 'Sign' ],
        Data      => {
            From     => 'example@unittest.org',
            To       => 'friend@example.com',
            Subject  => 'UnitTest Sign!',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
            Body     => 'Some nice text',
            Silent   => 1
        },
        Expected => [
            [
                {
                    'Key'   => 'SMIMESigned',
                    'Value' => 1
                }
            ]
        ],
        Name     => 'Certificate: Sign / no sign'
    },
    {
        Functions => [ 'Encrypt' ],
        Data      => {
            From     => 'me@example.com',
            Subject  => 'UnitTest Sign!',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
            Body     => 'Some nice text',
            Silent   => 1,
            Encrypt  => 1,
            IgnoreEmailPattern => $IgnoreEmailPattern
        },
        Expected => [
            undef
        ],
        Name     => 'Certificate: Encrypt / encrypt and send / no to / no encrypted'
    },
    {
        Functions => [ 'Encrypt' ],
        Data      => {
            From     => 'me@example.com',
            To       => 'friend@example.com',
            Subject  => 'UnitTest Sign!',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
            Body     => 'Some nice text',
            Silent   => 1,
            Encrypt  => 1,
            IgnoreEmailPattern => $IgnoreEmailPattern
        },
        Expected => [
            [
                {
                    'Key' => 'SMIMEEncrypted',
                    'Value' => 1
                },
                {
                    'Key' => 'SMIMEEncryptedError',
                    'Value' => 'Could not be sent, because no certificate found!'
                }
            ]
        ],
        Name     => 'Certificate: Encrypt / encrypt and send / no encrypted'
    },
    {
        Functions => [ 'Encrypt' ],
        Data      => {
            From     => 'me@example.com',
            To       => 'example@unittest.org',
            Subject  => 'UnitTest Sign!',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
            Body     => 'Some nice text',
            Silent   => 1,
            Encrypt  => 1,
            IgnoreEmailPattern => $IgnoreEmailPattern
        },
        Expected => [
            [
                {
                    'Key'   => 'SMIMEEncrypted',
                    'Value' => 1
                }
            ]
        ],
        Name     => 'Certificate: Encrypt / encrypt and send / Encrypted'
    },
    {
        Functions => [ 'Encrypt' ],
        Data      => {
            From     => 'me@example.com',
            To       => 'friend@example.com',
            Subject  => 'UnitTest Sign!',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
            Body     => 'Some nice text',
            Silent   => 1,
            Encrypt  => 2,
            IgnoreEmailPattern => $IgnoreEmailPattern
        },
        Expected => [
            [
                {
                    'Key' => 'SMIMEEncrypted',
                    'Value' => 1
                },
                {
                    'Key' => 'SMIMEEncryptedError',
                    'Value' => 'No certificate found!'
                }
            ]
        ],
        Name     => 'Certificate: Encrypt / encrypt if possible / no encrypted'
    },
    {
        Functions => [ 'Encrypt' ],
        Data      => {
            From     => 'me@example.com',
            To       => 'example@unittest.org',
            Subject  => 'UnitTest Sign!',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
            Body     => 'Some nice text',
            Silent   => 1,
            Encrypt  => 2,
            IgnoreEmailPattern => $IgnoreEmailPattern
        },
        Expected => [
            [
                {
                    'Key' => 'SMIMEEncrypted',
                    'Value' => 1
                }
            ]
        ],
        Name     => 'Certificate: Encrypt / encrypt if possible / no encrypted'
    },
    {
        Functions => [
            'Sign',
            'Encrypt'
        ],
        Data      => {
            From     => 'me@example.com',
            To       => 'me@example.com',
            Subject  => 'UnitTest Sign!',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
            Body     => 'Some nice text',
            Silent   => 1,
            Encrypt  => 2,
            IgnoreEmailPattern => $IgnoreEmailPattern
        },
        Expected => [
            [],
            [
                {
                    'Key' => 'SMIMEEncrypted',
                    'Value' => 1
                },
                {
                    'Key' => 'SMIMEEncryptedError',
                    'Value' => 'No certificate found!'
                }
            ]
        ],
        Name     => 'Certificate: Sign + Encrypt / encrypt if possible / no encrypted / no sign'
    },
    {
        Functions => [
            'Sign',
            'Encrypt'
        ],
        Data      => {
            From     => 'example@unittest.org',
            To       => 'example@unittest.org',
            Subject  => 'UnitTest Sign!',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
            Body     => 'Some nice text',
            Silent   => 1,
            Encrypt  => 2,
            IgnoreEmailPattern => $IgnoreEmailPattern
        },
        Expected => [
            [
                {
                    'Key' => 'SMIMESigned',
                    'Value' => 1
                }
            ],
            [
                {
                    'Key' => 'SMIMEEncrypted',
                    'Value' => 1
                }
            ]
        ],
        Name     => 'Certificate: Sign + Encrypt / encrypt if possible / encrypted / sign'
    }
);

for my $Test ( @TestsSE ) {

    my %Header;
    # do some encode
    ATTRIBUTE:
    for my $Attribute (qw(From To Cc Subject)) {
        next ATTRIBUTE if !$Test->{Data}->{$Attribute};
        $Header{$Attribute} = $Kernel::OM->Get('Email')->_EncodeMIMEWords(
            Field   => $Attribute,
            Line    => $Header{$Attribute},
            Charset => $Test->{Data}->{Charset},
        );
    }

    $Header{'X-Mailer'}     = "UnitTest Mail Service";
    $Header{'X-Powered-By'} = 'KIX (https://www.kixdesk.com/)';
    $Header{Type}           = $Test->{Data}->{MimeType} || 'text/plain';
    $Header{Encoding}       = 'quoted-printable';
    $Header{'Message-ID'}   = $Kernel::OM->Get('Email')->GenerateMessageID();

    # add date header
    $Header{Date} = 'Date: ' . $Kernel::OM->Get('Time')->MailTimeStamp();

    $Kernel::OM->Get('Encode')->EncodeOutput( \$Test->{Data}->{Body} );
    my $Entity = MIME::Entity->build(
        %Header,
        Data => $Test->{Data}->{Body}
    );

    my $Index = 0;
    for my $Function ( @{ $Test->{Functions} } ) {
        my %Result = $Kernel::OM->Get('Certificate')->$Function(
            %{$Test->{Data}},
            Entity => $Entity
        );
        $Self->IsDeeply(
            $Result{Flags},
            $Test->{Expected}->[$Index],
            $Test->{Name}
        );
        $Index++;
    }

    $Kernel::OM->ObjectsDiscard(
        Objects => ['Certificate'],
    );
}

# Certificate: Verify / Decrypt
# NOTE: the certificates are only self signed
my @TestsVD = (
    {
        Functions => [ 'Verify' ],
        Data      => {
            Silent => 1
        },
        Expected => [
            undef
        ],
        Name     => [ "Certificate: Verify / $Emails[0]->{Filename} / no Content / no verify" ]
    },
    {
        Functions => [ 'Verify' ],
        Data      => {
            %{$Emails[0]},
            Silent => 1
        },
        Expected => [
            undef
        ],
        Name     => [ "Certificate: Verify / $Emails[0]->{Filename} / no Type / no verify" ]
    },
    {
        Functions => [ 'Verify' ],
        Data      => {
            %{$Emails[0]},
            Type   => 'Test',
            Silent => 1
        },
        Expected => [
            undef
        ],
        Name     => [ "Certificate: Verify / $Emails[0]->{Filename} / invalid Type / no verify" ]
    },
    {
        Functions => [ 'Verify' ],
        Data      => {
            %{$Emails[0]},
            Type   => 'Email'
        },
        Expected => [
            [
                {
                    'Value' => 1,
                    'Key'   => 'SMIMESigned'
                },
                {
                    'Key'   => 'SMIMESignedError',
                    'Value' => "OpenSSL: Verification failure\n".'; self-signed certificate'
                }
            ]
        ],
        Name     => [ "Certificate: Verify / $Emails[0]->{Filename} / verified" ]
    },
    {
        Functions => [ 'Decrypt' ],
        Data      => {
            Silent => 1
        },
        Expected => [
            undef
        ],
        Name     => [ "Certificate: Decrypt / $Emails[1]->{Filename} / no Content / no decrypted" ]
    },
    {
        Functions => [ 'Decrypt' ],
        Data      => {
            %{$Emails[1]},
            Silent => 1
        },
        Expected => [
            undef
        ],
        Name     => [ "Certificate: Decrypt / $Emails[1]->{Filename} / no Type / no decrypted" ]
    },
    {
        Functions => [ 'Decrypt' ],
        Data      => {
            %{$Emails[1]},
            Type   => 'Test',
            Silent => 1
        },
        Expected => [
            undef
        ],
        Name     => [ "Certificate: Decrypt / $Emails[1]->{Filename} / invalid Type / no decrypted" ]
    },
    {
        Functions => [ 'Decrypt' ],
        Data      => {
            %{$Emails[1]},
            Type   => 'Email'
        },
        Expected => [
            [
                {
                    'Key'   => 'SMIMEEncrypted',
                    'Value' => 1
                }
            ]
        ],
        Name     => [ "Certificate: Decrypt / $Emails[1]->{Filename} / encrypted" ]
    },
    {
        Functions => [
            'Decrypt',
            'Verify'
        ],
        Data      => {
            %{$Emails[0]},
            Type => 'Email'
        },
        Expected => [
            1,
            [
                {
                    'Value' => 1,
                    'Key'   => 'SMIMESigned'
                },
                {
                    'Key'   => 'SMIMESignedError',
                    'Value' => "OpenSSL: Verification failure\n".'; self-signed certificate'
                }
            ]
        ],
        Name => [
            "Certificate: Decrypt + Verify / $Emails[0]->{Filename} / decryption / not encrypted",
            "Certificate: Decrypt + Verify / $Emails[0]->{Filename} / verification / verified"
        ]
    },
    {
        Functions => [
            'Decrypt',
            'Verify'
        ],
        Data      => {
            %{$Emails[1]},
            Type => 'Email'
        },
        Expected => [
            [
                {
                    'Key' => 'SMIMEEncrypted',
                    'Value' => 1
                }
            ],
            [
                {
                    'Value' => 1,
                    'Key'   => 'SMIMESigned'
                },
                {
                    'Key'   => 'SMIMESignedError',
                    'Value' => "OpenSSL: Verification failure\n".'; self-signed certificate'
                }
            ]
        ],
        Name => [
            "Certificate: Decrypt + Verify / $Emails[1]->{Filename} / decryption / decrypted",
            "Certificate: Decrypt + Verify / $Emails[1]->{Filename} / verification / verified"
        ]
    }
);

for my $Test ( @TestsVD ) {
    my $Content = $Test->{Data}->{Content};
    my $Index = 0;

    for my $Function ( @{ $Test->{Functions} } ) {
        my $Result = $Kernel::OM->Get('Certificate')->$Function(
            %{$Test->{Data}},
            Content => $Content
        );

        if ( IsArrayRef($Test->{Expected}->[$Index]) ) {
            $Self->IsDeeply(
                $Result->{Flags},
                $Test->{Expected}->[$Index],
                $Test->{Name}->[$Index]
            );
            $Content = $Result->{Content};
        }
        else {
            $Self->Is(
                $Result,
                $Test->{Expected}->[$Index],
                $Test->{Name}->[$Index]
            );
        }
        $Index++;
    }

    $Kernel::OM->ObjectsDiscard(
        Objects => ['Certificate']
    );
}

# Removing only the certificats and keys in the directory
_RemoveFiles();

# Certificate: Export / Export Certificates/Private Keys to FS
my $Result = $Kernel::OM->Get('Certificate')->CertificateToFS();

$Self->Is(
    $Result,
    1,
    'Certificate: Export / Export Certificates/Private Keys to FS'
);

_ExistsFilesInFS();

# Certificate: Delete
my @DeleteTests = (
    {
        Function => 'CertificateDelete',
        Data     => {
            ID  => $CertificateIDs[0]->{ID}
        },
        Expected => 1,
        Name     => 'Certificate: Delete / Type .PEM | application/x-x509-ca-cert / Certificate'
    },
    {
        Function => 'CertificateExists',
        Data     => {
            Filename => 'Certificate/SMIME/Cert/' . $CertificateIDs[0]->{Fingerprint},
        },
        Expected => undef,
        Name     => 'Certificate: Exists / Type .PEM | application/x-x509-ca-cert / Certificate'
    },
    {
        Function => 'CertificateDelete',
        Data     => {
            ID  => $CertificateIDs[1]->{ID}
        },
        Expected => 1,
        Name     => 'Certificate: Delete / Type .PEM | application/x-x509-ca-cert / Private Key '
    },
    {
        Function => 'CertificateExists',
        Data     => {
            Filename => 'Certificate/SMIME/Cert/' . $CertificateIDs[1]->{Fingerprint},
        },
        Expected => undef,
        Name     => 'Certificate: Exists / Type .PEM | application/x-x509-ca-cert / Private Key'
    },
    {
        Function => 'CertificateDelete',
        Data     => {
            ID  => $CertificateIDs[2]->{ID}
        },
        Expected => 1,
        Name     => 'Certificate: Delete / Type .CRT | application/pkix-cert / Certificate'
    },
    {
        Function => 'CertificateExists',
        Data     => {
            Filename => 'Certificate/SMIME/Cert/' . $CertificateIDs[2]->{Fingerprint},
        },
        Expected => undef,
        Name     => 'Certificate: Exists / Type .CRT | application/pkix-cert / Certificate'
    },
    {
        Function => 'CertificateDelete',
        Data     => {
            ID  => $CertificateIDs[3]->{ID}
        },
        Expected => 1,
        Name     => 'Certificate: Delete / Type .CSR | application/pkcs10 / Certificate'
    },
    {
        Function => 'CertificateExists',
        Data     => {
            Filename => 'Certificate/SMIME/Cert/' . $CertificateIDs[3]->{Fingerprint},
        },
        Expected => undef,
        Name     => 'Certificate: Exists / Type .CSR | application/pkcs10 / Certificate'
    },
    {
        Function => 'CertificateDelete',
        Data     => {
            ID  => $CertificateIDs[4]->{ID}
        },
        Expected => 1,
        Name     => 'Certificate: Delete / Type .KEY | application/x-iwork-keynote-sffkey / Private Key '
    },
    {
        Function => 'CertificateExists',
        Data     => {
            Filename => 'Certificate/SMIME/Cert/' . $CertificateIDs[4]->{Fingerprint},
        },
        Expected => undef,
        Name     => 'Certificate: Exists / Type .KEY | application/x-iwork-keynote-sffkey / Private Key'
    },
);

for my $Test ( @DeleteTests ) {
    my $Function = $Test->{Function};

    my $Result   = $Kernel::OM->Get('Certificate')->$Function(
        %{$Test->{Data}}
    );

    $Self->Is(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );
}


sub _RemoveFiles {
    my ( %Param ) = @_;

    for my $Cert ( @CertificateIDs ) {
        my $Pre = $Cert->{Type} eq 'Cert' ? 'certs' : 'private';
        my $Success = $Kernel::OM->Get('Main')->FileDelete(
            Location        => $HomeDir . '/var/ssl/'. $Pre . '/KIX_' . $Cert->{Type} . '_' . $Cert->{FileID}
        );
    }

    return 1;
}

sub _ExistsFilesInFS {
    my ( %Param ) = @_;
    my %Counts = (
        Cert    => 0,
        Private => 0
    );

    for my $Cert ( @CertificateIDs ) {
        my $Pre = $Cert->{Type} eq 'Cert' ? 'certs' : 'private';
        my $Cnt = $Kernel::OM->Get('Main')->FileRead(
            Location        => $HomeDir . '/var/ssl/'. $Pre . '/KIX_' . $Cert->{Type} . '_' . $Cert->{FileID},
            Result          => 'SCALAR',
            DisableWarnings => 1
        );
        if ( $Cnt ) {
            $Counts{$Cert->{Type}}++;
        }
    }


    $Self->IsDeeply(
        \%Counts,
        {
            Cert    => 3,
            Private => 2
        },
        'Certificate: Export / Check / Count: Certificates 3 | Private Key 2'
    );

    return 1;
}

sub _ReadCertificates {
    my ( %Param ) = @_;

    my @List;
    my @Files = (
        {
            Filename    => 'ExampleCA.pem',
            Filesize    => 2_800,
            ContentType => 'application/x-x509-ca-cert',
            Name        => 'Certificate: Read / Type .PEM | application/x-x509-ca-cert / Certificate'
        },
        {
            Filename    => 'ExampleKey.pem',
            Filesize    => 1_704,
            ContentType => 'application/x-x509-ca-cert',
            Name        => 'Certificate: Read / Type .PEM | application/x-x509-ca-cert / Private Key'
        },
        {
            Filename    => 'Example.crt',
            Filesize    => 1_310,
            ContentType => 'application/pkix-cert',
            Name        => 'Certificate: Read / Type .CRT | application/pkix-cert / Certificate'
        },
        {
            Filename    => 'Example.csr',
            Filesize    => 1_009,
            ContentType => 'application/pkcs10',
            Name        => 'Certificate: Read / Type .CSR | application/pkcs10 / Certificate'
        },
        {
            Filename    => 'Example.key',
            Filesize    => 1_751,
            ContentType => 'application/x-iwork-keynote-sffkey',
            Name        => 'Certificate: Read / Type .KEY | application/x-iwork-keynote-sffkey / Private Key'
        }
    );

    for my $File ( @Files ) {
        my $Content = $Kernel::OM->Get('Main')->FileRead(
            Directory => $HomeDir . '/scripts/test/system/sample/Certificate/Certificates',
            Filename  => $File->{Filename},
            Mode      => 'binmode'
        );

        $Self->True(
            $Content,
            $File->{Name} . ' / Exists'
        );

        push (
            @List,
            {
                Filename    => $File->{Filename},
                Filesize    => $File->{Filesize},
                ContentType => $File->{ContentType},
                Content     => MIME::Base64::encode_base64( ${$Content} )
            }
        )
    }

    return @List;
}

sub _ReadEmails {
    my ( %Param ) = @_;

    my @List;
    my @Files = (
        {
            Filename    => 'UnitTest_Signed.box',
            Filesize    => 4_279,
            ContentType => 'application/vnd.previewsystems.box',
            Name        => 'Certificate: Read / UnitTest_Signed.box / Email'
        },
        {
            Filename    => 'UnitTest_Encrypted_Signed.box',
            Filesize    => 6_778,
            ContentType => 'application/vnd.previewsystems.box',
            Name        => 'Certificate: Read / UnitTest_Encrypted_Signed.box / Email'
        }
    );

    for my $File ( @Files ) {
        my $Content = $Kernel::OM->Get('Main')->FileRead(
            Directory => $HomeDir . '/scripts/test/system/sample/Certificate/Emails',
            Filename  => $File->{Filename},
            Mode      => 'binmode'
        );

        $Self->True(
            $Content,
            $File->{Name} . ' / Exists'
        );

        my @Email = split( /\n/sm, ${ $Content } );
        for my $Line (@Email) {
            $Line .= "\n";
        }

        push (
            @List,
            {
                Filename    => $File->{Filename},
                Filesize    => $File->{Filesize},
                ContentType => $File->{ContentType},
                Content     => \@Email
            }
        )
    }

    return @List;
}

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
