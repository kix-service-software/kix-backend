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

# get web service object
my $WebserviceObject = $Kernel::OM->Get('Webservice');

# create a base web service
my $WebServiceID = $WebserviceObject->WebserviceAdd(
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

my $Home       = $Kernel::OM->Get('Config')->Get('Home');
my $TargetPath = "$Home/var/tmp/$WebService.yaml";

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
        Name     => 'Missing target-path',
        Options  => [ '--webservice-id', $WebServiceID ],
        ExitCode => 1,
    },
    {
        Name     => 'Missing target-path value',
        Options  => [ '--webservice-id', $WebServiceID, '--target-path' ],
        ExitCode => 1,
    },
    {
        Name     => 'Wrong webservice-id',
        Options  => [ '--webservice-id', $WebService, '--target-path', $TargetPath ],
        ExitCode => 1,
    },
    {
        Name     => 'Correct Dump',
        Options  => [ '--webservice-id', $WebServiceID, '--target-path', $TargetPath ],
        ExitCode => 1,
    },
);

# get needed objects
my $CommandObject = $Kernel::OM->Get('Console::Command::Admin::WebService::Dump');
my $MainObject    = $Kernel::OM->Get('Main');
my $YAMLObject    = $Kernel::OM->Get('YAML');

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

    if ( !$Test->{ExitCode} ) {

        my $WebService = $WebserviceObject->WebserviceGet(
            Name => $WebService,
        );

        my $ContentSCALARRef = $MainObject->FileRead(
            Location => $TargetPath,
            Mode     => 'utf8',
            Type     => 'Local',
            Result   => 'SCALAR',
        );

        my $Config = $YAMLObject->Load(
            Data => ${$ContentSCALARRef},
        );

        $Self->IsDeeply(
            $WebService->{Config},
            $Config,
            "$Test->{Name} - web service config"
        );
    }
}

if ( -e $TargetPath ) {

    my $Success = unlink $TargetPath;

    $Self->True(
        $Success,
        "Deleted temporary file $TargetPath with true",
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
