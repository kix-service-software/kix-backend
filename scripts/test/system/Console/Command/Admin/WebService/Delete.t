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

my $WebService = 'webservice' . $Helper->GetRandomID();

# create a base web service
my $WebServiceID = $Kernel::OM->Get('Webservice')->WebserviceAdd(
    Name   => $WebService,
    Config => {
        Provider => {
            Operation => {
                'Test::User::UserSearch' => {
                    Description           => '',
                    NoAuthorizationNeeded => 1,
                    Type                  => 'V1::Sessions::SessionCreate',
                },
            },
            Transport => {
                Config => {
                    KeepAlive             => '',
                    MaxLength             => '52428800',
                    RouteOperationMapping => {
                        'Test::User::UserSearch' => {
                            RequestMethod => [
                                'GET',
                                'POST'
                            ],
                            Route => '/Test'
                        }
                    }
                },
            },
        },
    },
    ValidID => 1,
    UserID  => 1,
);

# test cases
my @Tests = (
    {
        Name     => 'No Options',
        Options  => [],
        ExitCode => 1,
    },
    {
        Name     => 'Missing webservice-id value',
        Options  => ['--webservice-id'],
        ExitCode => 1,
    },
    {
        Name     => 'Non existing webservice-id',
        Options  => [ '--webservice-id', $WebService ],
        ExitCode => 1,
    },
    {
        Name     => 'Correct webservice-id',
        Options  => [ '--webservice-id', $WebServiceID ],
        ExitCode => 1,
    },
    {
        Name     => 'Already deleted webservice-id',
        Options  => [ '--webservice-id', $WebServiceID ],
        ExitCode => 1,
    },
);

# get command object
my $CommandObject = $Kernel::OM->Get('Console::Command::Admin::WebService::Delete');

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
