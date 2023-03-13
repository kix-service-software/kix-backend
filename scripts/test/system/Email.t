# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
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

use Kernel::System::EmailParser;

# get config object
my $ConfigObject = $Kernel::OM->Get('Config');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# do not really send emails
$ConfigObject->Set(
    Key   => 'SendmailModule',
    Value => 'Kernel::System::Email::DoNotSendEmail',
);

# test scenarios
my @Tests = (
    {
        Name => 'ascii',
        Data => {
            From     => 'john.smith@example.com',
            To       => 'john.smith2@example.com',
            Subject  => 'some subject',
            Body     => 'Some Body',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
        },
    },
    {
        Name => 'utf8 - de',
        Data => {
            From => '"Fritz Müller" <fritz@example.com>',
            To   => '"Hans Kölner" <friend@example.com>',
            Subject =>
                'This is a text with öäüßöäüß to check for problems äöüÄÖüßüöä!',
            Body     => "Some Body\nwith\n\nöäüßüüäöäüß1öää?ÖÄPÜ",
            MimeType => 'text/plain',
            Charset  => 'utf-8',
        },
    },
    {
        Name => 'utf8 - ru',
        Data => {
            From => '"Служба поддержки (support)" <me@example.com>',
            To   => 'friend@example.com',
            Subject =>
                'это специальныйсабжект для теста системы тикетов',
            Body     => "Some Body\nlala",
            MimeType => 'text/plain',
            Charset  => 'utf-8',
        },
    },
    {
        Name => 'utf8 - high unicode characters',
        Data => {
            From     => '"Служба поддержки (support)" <me@example.com>',
            To       => 'friend@example.com',
            Subject  => 'Test related to bug#9832',
            Body     => "\x{2660}",
            MimeType => 'text/plain',
            Charset  => 'utf-8',
        },
    },
    {
        Name => 'ignored recipient',
        Data => {
            From     => 'john.smith@example.com',
            To       => 'john.smith2@example.com,noreply-123456@nomail.com,test@test.org',
            Subject  => 'some subject',
            Body     => 'Some Body',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
        },
        Expect => {
            From     => 'john.smith@example.com',
            To       => 'john.smith2@example.com, test@test.org',
            Subject  => 'some subject',
            Body     => 'Some Body',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
        }
    },
    {
        Name => 'only ignored recipient',
        Data => {
            From     => 'john.smith@example.com',
            To       => 'noreply-123456@nomail.com',
            Subject  => 'some subject',
            Body     => 'Some Body',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
        },
        Expect => {
            From     => 'john.smith@example.com',
            To       => '',
            Subject  => 'some subject',
            Body     => 'Some Body',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
            asd      => 'asd',
        }
    },
    {
        Name => 'only ignored recipients',
        Data => {
            From     => 'john.smith@example.com',
            To       => 'noreply-123@nomail.com,noreply-456@nomail.com,noreply-789@nomail.com',
            Subject  => 'some subject',
            Body     => 'Some Body',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
        },
        Expect => {
            From     => 'john.smith@example.com',
            To       => '',
            Subject  => 'some subject',
            Body     => 'Some Body',
            MimeType => 'text/plain',
            Charset  => 'utf-8',
        }
    },
);

my $Count = 0;
for my $Encoding ( '', qw(base64 quoted-printable 8bit) ) {

    $Count++;
    my $CountSub = 0;
    for my $Test (@Tests) {

        $CountSub++;
        my $Name = "#$Count.$CountSub $Encoding $Test->{Name}";

        # set forcing of encoding
        $ConfigObject->Set(
            Key   => 'SendmailEncodingForce',
            Value => $Encoding,
        );

        $Kernel::OM->ObjectsDiscard( Objects => ['Email'] );
        my $EmailObject = $Kernel::OM->Get('Email');

        my ( $Header, $Body ) = $EmailObject->Send(
            %{ $Test->{Data} },
        );

        # start MIME::Tools workaround
        ${$Body} =~ s/\n/\r/g;

        # end MIME::Tools workaround
        my $Email = ${$Header} . "\n" . ${$Body};
        my @Array = split /\n/, $Email;

        # parse email
        my $ParserObject = Kernel::System::EmailParser->new(
            Email => \@Array,
        );

        # check header
        KEY:
        for my $Key (qw(From To Cc Subject)) {
            next KEY if !$Test->{Data}->{$Key};
            $Self->Is(
                $ParserObject->GetParam( WHAT => $Key ),
                defined $Test->{Expect}->{$Key} ? $Test->{Expect}->{$Key} : $Test->{Data}->{$Key},
                "$Name GetParam(WHAT => '$Key')",
            );
        }

        # check body
        if ( $Test->{Data}->{Body} ) {
            my $Body = $ParserObject->GetMessageBody();

            # start MIME::Tools workaround
            $Body =~ s/\r/\n/g;
            $Body =~ s/=\n//;
            $Body =~ s/\n$//;
            $Body =~ s/=$//;

            # end MIME::Tools workaround
            $Self->Is(
                $Body,
                $Test->{Expect}->{Body} || $Test->{Data}->{Body},
                "$Name GetMessageBody()",
            );
        }

        # check charset
        if ( $Test->{Data}->{Charset} ) {
            $Self->Is(
                $ParserObject->GetCharset(),
                $Test->{Expect}->{Charset} || $Test->{Data}->{Charset},
                "$Name GetCharset()",
            );
        }

        # check Content-Type
        if ( $Test->{Data}->{Type} ) {
            $Self->Is(
                ( split ';', $ParserObject->GetContentType() )[0],
                $Test->{Expect}->{Type} || $Test->{Data}->{Type},
                "$Name GetContentType()",
            );
        }
    }
}

# cleanup is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
