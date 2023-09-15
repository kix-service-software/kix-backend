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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $WebService = 'webservice' . $Helper->GetRandomID();

my $Home = $Kernel::OM->Get('Config')->Get('Home');

# test cases
my @Tests = (
    {
        Name     => 'No Options',
        Options  => [],
        ExitCode => 1,
    },
    {
        Name     => 'Missing name value',
        Options  => ['--name'],
        ExitCode => 1,
    },
    {
        Name     => 'Missing source-path',
        Options  => [ '--name', $WebService ],
        ExitCode => 1,
    },
    {
        Name     => 'Missing source-path value',
        Options  => [ '--name', $WebService, '--source-path' ],
        ExitCode => 1,
    },

    {
        Name     => 'Non existing source-path',
        Options  => [ '--name', $WebService, '--source-path', $WebService ],
        ExitCode => 1,
    },
    {
        Name    => 'Non YAML source-path',
        Options => [
            '--name', $WebService, '--source-path',
            "$Home/scripts/test/system/Console/Command/Admin/WebService/GenericTicketConnectorSOAP.wsdl"
        ],
        ExitCode => 1,
    },
    {
        Name    => 'Non web service YAML source-path',
        Options => [
            '--name', $WebService, '--source-path',
            "$Home/scripts/test/system/Console/Command/Admin/WebService/BookOrdering.yml"
        ],
        ExitCode => 1,
    },
    # {
    #     Name    => 'Correct YAML source-path',
    #     Options => [
    #         '--name', $WebService, '--source-path',
    #         "$Home/scripts/test/system/Console/Command/Admin/WebService/GenericTicketConnectorSOAP.yml"
    #     ],
    #     ExitCode => 0,
    # },
    # {
    #     Name    => 'Duplicate name',
    #     Options => [
    #         '--name', $WebService, '--source-path',
    #         "$Home/scripts/test/system/Console/Command/Admin/WebService/GenericTicketConnectorSOAP.yml"
    #     ],
    #     ExitCode => 1,
    # },
);

# get command object
my $CommandObject = $Kernel::OM->Get('Console::Command::Admin::WebService::Add');

# silence console output
local *STDOUT;
local *STDERR;
open STDOUT, '>>', "/dev/null";
open STDERR, '>>', "/dev/null";

for my $Test (@Tests) {

    my $ExitCode = $CommandObject->Execute( @{ $Test->{Options} } );

    $Self->Is(
        $ExitCode,
        $Test->{ExitCode},
        "$Test->{Name}",
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

