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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# do not really send emails
$Kernel::OM->Get('Config')->Set(
    Key   => 'SendmailModule',
    Value => 'Email::Test',
);

# get email object
my $EmailObject = $Kernel::OM->Get('Email');

# get test email backed object
my $TestBackendObject = $Kernel::OM->Get('Email::Test');

my $Success = $TestBackendObject->CleanUp();
$Self->True(
    $Success,
    'Initial cleanup',
);

$Self->IsDeeply(
    $TestBackendObject->EmailsGet(),
    [],
    'Test backend empty after initial cleanup',
);

for ( 1 .. 2 ) {

    # call Send and get results
    my $Sent = $EmailObject->Send(
        From     => 'john.smith@example.com',
        To       => 'john.smith2@example.com',
        Subject  => 'some subject',
        Body     => 'Some Body',
        MimeType => 'text/html',
        Charset  => 'utf8',
    );

    $Self->True(
        $Sent->{BodyRef},
        "Email delivered to backend",
    );
}

my $Emails = $TestBackendObject->EmailsGet();

$Self->Is(
    scalar @{$Emails},
    2,
    "Emails fetched from backend",
);

for my $Index ( 0 .. 1 ) {
    $Self->Is(
        $Emails->[$Index]->{From},
        'john.smith@example.com',
        "From header",
    );
    $Self->IsDeeply(
        $Emails->[$Index]->{ToArray},
        ['john.smith2@example.com'],
        "To header",
    );
    $Self->True(
        $Emails->[$Index]->{Header},
        "Header field",
    );
    $Self->True(
        $Emails->[$Index]->{Body},
        "Body field",
    );
}

$Success = $TestBackendObject->CleanUp();
$Self->True(
    $Success,
    'Final cleanup',
);

$Self->IsDeeply(
    $TestBackendObject->EmailsGet(),
    [],
    'Test backend empty after final cleanup',
);

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
