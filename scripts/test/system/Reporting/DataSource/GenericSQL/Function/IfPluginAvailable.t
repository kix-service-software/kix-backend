# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;
use File::Path;

use Kernel::System::VariableCheck qw(:all);
use vars (qw($Self));

# get ReportDefinition object
my $ReportingObject = $Kernel::OM->Get('Reporting');
my $FunctionObject = $ReportingObject->_LoadDataSourceBackend(Name => 'GenericSQL')->_LoadFunctionBackend(Name => 'if_plugin_available');

#
# log tests
#

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $Home = $Kernel::OM->Get('Config')->Get('Home');
my $Success = mkdir( "$Home/plugins/test", 0770 );

$Self->True(
    $Success,
    'Create Plugin Directory',
);

$Success = $Kernel::OM->Get('Main')->FileWrite(
    Location => "$Home/plugins/test/RELEASE",
    Content  => \"PRODUCT = test"
);

$Self->True(
    $Success,
    'Create RELEASE file',
);

my @Tests = (
    {
        Test   => 'plugin does not exist',
        Parameters => {
            Plugin => 'none',
            Text   => 'this is a test'
        },
        Expect => ''
    },
    {
        Test   => 'plugin exists',
        Parameters => {
            Plugin => 'test',
            Text   => 'this is a test'
        },
        Expect => 'this is a test'
    },
);

foreach my $Test ( @Tests ) {
    my $Result = $FunctionObject->Run(
        %{$Test->{Parameters}}
    );

    $Self->Is(
        $Result,
        $Test->{Expect},
        'Run() - '.$Test->{Test},
    );
}

$Success = rmtree("$Home/plugins/test");
$Self->True(
    $Success,
    'Remove Plugin Directory',
);

# cleanup is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
