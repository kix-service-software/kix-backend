# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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

use Kernel::System::PostMaster;

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# This test checks if KIX correctly detects that an email must not be auto-responded to.
my @Tests = (
    {
        Name => 'Regular mail',
        Email =>
            'From: test@home.com
To: test@home.com
Subject: Testmail

Body
',
        EmailParams => {
            From          => 'test@home.com',
            'X-KIX-Loop' => '',
        },
    },
    {
        Name => 'Precedence',
        Email =>
            'From: test@home.com
To: test@home.com
Precedence: bulk
Subject: Testmail

Body
',
        EmailParams => {
            From          => 'test@home.com',
            'X-KIX-Loop' => 'yes',
        },
    },
    {
        Name => 'X-Loop',
        Email =>
            'From: test@home.com
To: test@home.com
X-Loop: yes
Subject: Testmail

Body
',
        EmailParams => {
            From          => 'test@home.com',
            'X-KIX-Loop' => 'yes',
        },
    },
    {
        Name => 'X-No-Loop',
        Email =>
            'From: test@home.com
To: test@home.com
X-No-Loop: yes
Subject: Testmail

Body
',
        EmailParams => {
            From          => 'test@home.com',
            'X-KIX-Loop' => 'yes',
        },
    },
    {
        Name => 'X-KIX-Loop',
        Email =>
            'From: test@home.com
To: test@home.com
X-KIX-Loop: yes
Subject: Testmail

Body
',
        EmailParams => {
            From          => 'test@home.com',
            'X-KIX-Loop' => 'yes',
        },
    },
    {
        Name => 'Auto-submitted: auto-generated',
        Email =>
            'From: test@home.com
To: test@home.com
Auto-submitted: auto-generated
Subject: Testmail

Body
',
        EmailParams => {
            From          => 'test@home.com',
            'X-KIX-Loop' => 'yes',
        },
    },
    {
        Name => 'Auto-Submitted: auto-replied',
        Email =>
            'From: test@home.com
To: test@home.com
Auto-Submitted: auto-replied
Subject: Testmail

Body
',
        EmailParams => {
            From          => 'test@home.com',
            'X-KIX-Loop' => 'yes',
        },
    },
    {
        Name => 'Auto-submitted: no',
        Email =>
            'From: test@home.com
To: test@home.com
Auto-submitted: no
Subject: Testmail

Body
',
        EmailParams => {
            From          => 'test@home.com',
            'X-KIX-Loop' => '',
        },
    },
);

for my $Test (@Tests) {

    my @Email = split( /\n/, $Test->{Email} );

    my $PostMasterObject = Kernel::System::PostMaster->new(
        Email => \@Email,
    );

    my $EmailParams = $PostMasterObject->GetEmailParams();

    for my $EmailParam ( sort keys %{ $Test->{EmailParams} } ) {
        $Self->Is(
            $EmailParams->{$EmailParam},
            $Test->{EmailParams}->{$EmailParam},
            "$Test->{Name} - $EmailParam",
        );
    }
}

# cleanup cache is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
