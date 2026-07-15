# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::PostMaster;

use MIME::Base64;

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# REMINDER:
# If there are problems with the certificates, they may have expired.
# Currently, they run until 2029 and 2034.
# Furthermore, these are self-signed certificates.

# begin transaction on database
$Helper->BeginWork();

my $HomeDir = $Kernel::OM->Get('Config')->Get('Home');
my @Certificates = ();
my @Files = (
    {
        Filename    => 'ExampleCA.pem',
        Filesize    => 2_800,
        ContentType => 'application/x-x509-ca-cert',
        Type        => 'Cert',
        CType       => 'SMIME',
    },
    {
        Filename    => 'ExampleKey.pem',
        Filesize    => 1_704,
        ContentType => 'application/x-x509-ca-cert',
        Type        => 'Private',
        Passphrase  => 'start123',
        CType       => 'SMIME',
    },
    {
        Filename    => 'Example.crt',
        Filesize    => 1_310,
        ContentType => 'application/pkix-cert',
        Type        => 'Cert',
        CType       => 'SMIME',
    },
    {
        Filename    => 'Example.key',
        Filesize    => 1_751,
        ContentType => 'application/x-iwork-keynote-sffkey',
        Type        => 'Private',
        Passphrase  => 'start123',
        CType       => 'SMIME',
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
        $File->{Filename} . ' / FileRead'
    );

    my $FileID = $Kernel::OM->Get('Certificate')->CertificateCreate(
        File => {                                   # required
            Content     => MIME::Base64::encode_base64( ${$Content} ),
            ContentType => $File->{ContentType},
            Filename    => $File->{Filename}
        },
        Type       => $File->{Type},
        Passphrase => $File->{Passphrase},
        CType      => $File->{CType},
        UserID     => 1
    );

    $Self->True(
        $Content,
        $File->{Filename} . ' / CertificateCreate'
    );

    push (
        @Certificates,
        {
            FileID => $FileID,
            Type   => $File->{Type},
        }
    )
}

# check log when To header is missing
my $Location = $HomeDir . '/scripts/test/system/sample/Certificate/Emails/UnitTest_Encrypted_Signed.box';
my $ContentRef = $Kernel::OM->Get('Main')->FileRead(
    Location => $Location,
    Mode     => 'binmode',
);
my @Return;
{
    my $PostMasterObject = Kernel::System::PostMaster->new(
        Email => $ContentRef,
    );

    @Return = $PostMasterObject->Run();
}

$Self->Is(
    scalar(@Return),
    1,
    'PostMaster returned one result'
);
$Self->Is(
    $Return[0][0],
    1,
    'PostMaster created new ticket'
);

# get article index
my @ArticleIndex = $Kernel::OM->Get('Ticket')->ArticleIndex(
    TicketID => $Return[0][1]
);
$Self->Is(
    scalar(@ArticleIndex),
    1,
    'Ticket has one article'
);

my $ArticlePlain = $Kernel::OM->Get('Ticket')->ArticlePlain(
    ArticleID => $ArticleIndex[0]
);
$Self->Is(
    $ArticlePlain,
    ${$ContentRef},
    'ArticlePlain has expected content'
);

# remove certs from fs. db is reset by transaction
for my $Cert ( @Certificates ) {
    my $Pre = $Cert->{Type} eq 'Cert' ? 'certs' : 'private';
    my $Success = $Kernel::OM->Get('Main')->FileDelete(
        Location => $HomeDir . '/var/ssl/'. $Pre . '/KIX_' . $Cert->{Type} . '_' . $Cert->{FileID}
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
