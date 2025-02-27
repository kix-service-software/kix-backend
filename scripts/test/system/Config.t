# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));
use Kernel::System::VariableCheck qw(:all);

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Config');
my $EncodeObject = $Kernel::OM->Get('Encode');

my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $Value = 'Testvalue';
$ConfigObject->Set(
    Key   => 'ConfigTestkey',
    Value => $Value,
);
my $Get = $ConfigObject->Get('ConfigTestkey');

$Self->Is(
    $Get,
    $Value,
    'Set() and Get()',
);

my $Home = $ConfigObject->Get('Home');
$Self->True(
    $Home,
    'check for configuration setting "Home"',
);

# obtains the default home path
my $DefaultHome = $ConfigObject->Get('Home');

# changes the home path
my $DummyPath = '/some/dummy/path/that/has/nothing/to/do/with/this';
$ConfigObject->Set(
    Key   => 'Home',
    Value => $DummyPath,
);

# obtains the current home path
my $NewHome = $ConfigObject->Get('Home');

# makes sure that the current home path is the one we set
$Self->Is(
    $NewHome,
    $DummyPath,
    'Test Set() with "Home" - both paths are equivalent.',
);

# makes sure that the default home path and the current are different
$Self->IsNot(
    $NewHome,
    $DefaultHome,
    'Test Set() with "Home" - new path differs from the default.',
);

# check FQDN config
my $FQDN = {
    Frontend => 'some-frontend',
    Backend  => 'some-backend'
};
$ConfigObject->Set(
    Key   => 'FQDN',
    Value => $FQDN
);
my $NewFQDN = $ConfigObject->Get('FQDN');
$Self->True(
    IsHashRefWithData($NewFQDN) || 0,
    'FQDN config test - is hash ref'
);
$Self->Is(
    $NewFQDN->{Frontend},
    $FQDN->{Frontend},
    'FQDN config test - frontend value'
);
# check FQDN replacement in config
$ConfigObject->Set(
    Key   => 'NotificationSenderEmail',
    Value => 'kix@<KIX_CONFIG_FQDN>'
);
my $SenderMail = $ConfigObject->Get('NotificationSenderEmail');
$Self->Is(
    $SenderMail,
    'kix@' . $FQDN->{Frontend},
    'FQDN config test - sender mail value (frontend)'
);
$ConfigObject->Set(
    Key   => 'NotificationSenderEmail',
    Value => 'kix@<KIX_CONFIG_FQDN_Backend>'
);
$SenderMail = $ConfigObject->Get('NotificationSenderEmail');
$Self->Is(
    $SenderMail,
    'kix@' . $FQDN->{Backend},
    'FQDN config test - sender mail value (backend)'
);

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
