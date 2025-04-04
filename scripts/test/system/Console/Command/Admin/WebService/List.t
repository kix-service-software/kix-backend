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
        }
    },
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $WebServiceID,
    "Add Test WebService"
);

# get command object
my $CommandObject = $Kernel::OM->Get('Console::Command::Admin::WebService::List');

my ( $Result, $ExitCode );

{
    local *STDOUT;
    open STDOUT, '>:utf8', \$Result;    ## no critic
    $ExitCode = $CommandObject->Execute();
}

$Self->Is(
    $ExitCode,
    0,
    "List exit code",
);

$Self->True(
    scalar $Result =~ m{$WebService}xms,
    "WebServiceID is listed",
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
