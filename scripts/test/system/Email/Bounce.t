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

$Kernel::OM->Get('Config')->Set(
    Key   => 'SendmailModule',
    Value => 'Kernel::System::Email::DoNotSendEmail',
);

local $ENV{TZ} = 'UTC';
my $Helper     = $Kernel::OM->Get('UnitTest::Helper');
my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2014-01-01 12:00:00',
);
$Helper->FixedTimeSet($SystemTime);

my $EmailObject = $Kernel::OM->Get('Email');

my @Tests = (
    {
        Name   => 'Simple email',
        Params => {
            From         => 'from@bounce.com',
            To           => 'to@bounce.com',
            'Message-ID' => '<bounce@mail>',
            Email        => <<'EOF',
From: test@home.com
To: test@kixdesk.com
Message-ID: <original@mail>
Subject: Bounce test

Testmail
EOF
        },
        Result => <<'EOF',
From: test@home.com
To: test@kixdesk.com
Message-ID: <original@mail>
Subject: Bounce test
Resent-Message-ID: <bounce@mail>
Resent-To: to@bounce.com
Resent-From: from@bounce.com
Resent-Date: Wed, 1 Jan 2014 12:00:00 +0000

Testmail
EOF
    },
);

for my $Test (@Tests) {
    my ( $Header, $Body ) = $EmailObject->Bounce(
        %{ $Test->{Params} }
    );
    $Self->Is(
        $$Header . "\n" . $$Body,
        $Test->{Result},
        "$Test->{Name} Bounce()",
    );
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
