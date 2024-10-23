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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $AuthModule = 'Kernel::System::Auth::HTTPBasicAuth';

# require module
return if ( !$Kernel::OM->Get('Main')->Require( $AuthModule ) );

# create backend object
my $AuthObject = $AuthModule->new(
    %{ $Self },
    Name   => 'UnitTest',
    Config => {
        Replace       => 'Test',
        ReplaceRegExp => 'Try(\d+)',
        Debug         => 1
    }
);
$Self->Is(
    ref( $AuthObject ),
    $AuthModule,
    'Auth object has correct module ref'
);

## TODO: let backend handle its parameter, do not force self variables on it
# set name on auth object
$AuthObject->{Config} = {
    'Name' => 'UnitTest'
};

# check supported methods
for my $Method ( qw(Auth) ) {
    $Self->True(
        $AuthObject->can($Method),
        'Auth object can "' . $Method . '"'
    );
}

# check not supported methods
for my $Method ( qw(PreAuth GetPreAuthType GetAuthMethod) ) {
    $Self->False(
        $AuthObject->can($Method),
        'Auth object can not "' . $Method . '"'
    );
}

my @AuthTests = (
    {
        Name     => 'Auth: ENV "REMOTE_USER", "HTTP_REMOTE_USER" and "REMOTE_ADDR" empty',
        Environment => {
            REMOTE_USER      => '',
            HTTP_REMOTE_USER => '',
            REMOTE_ADDR      => ''
        },
        Expected    => {
            Result => undef,
            Log    => [
                {
                    Priority => 'notice',
                    Message  => '[Auth::HTTPBasicAuth] No User given by environment REMOTE_USER and HTTP_REMOTE_USER! (REMOTE_ADDR: \'Got no REMOTE_ADDR env!\', Backend: \'UnitTest\')',
                    Index    => 0
                }
            ]
        }
    },
    {
        Name     => 'Auth: ENV "REMOTE_USER" and "REMOTE_ADDR" set, "HTTP_REMOTE_USER" empty',
        Environment => {
            REMOTE_USER      => 'Test1',
            HTTP_REMOTE_USER => '',
            REMOTE_ADDR      => '127.0.0.1'
        },
        Expected    => {
            Result => '1',
            Log    => [
                {
                    Priority => 'notice',
                    Message  => '[Auth::HTTPBasicAuth] User \'1\' authentication ok. (REMOTE_ADDR: \'127.0.0.1\', Backend: \'UnitTest\')',
                    Index    => 0
                },
                {
                    Priority => 'debug',
                    Message  => '[Auth::HTTPBasicAuth] User \'Test1\' tried to authenticate. (REMOTE_ADDR: \'127.0.0.1\', Backend: \'UnitTest\')',
                    Index    => 0
                },
                {
                    Priority => 'debug',
                    Message  => '[Auth::HTTPBasicAuth] Pattern \'Test\' removed from given User. (REMOTE_ADDR: \'127.0.0.1\', Backend: \'UnitTest\')',
                    Index    => 1
                },
                {
                    Priority => 'debug',
                    Message  => '[Auth::HTTPBasicAuth] Pattern \'Try(\d+)\' replaced by first capture group for given User. (REMOTE_ADDR: \'127.0.0.1\', Backend: \'UnitTest\')',
                    Index    => 2
                }
            ]
        }
    },
    {
        Name     => 'Auth: ENV "HTTP_REMOTE_USER" and "REMOTE_ADDR" set, "REMOTE_USER" empty',
        Environment => {
            REMOTE_USER      => '',
            HTTP_REMOTE_USER => 'Try1',
            REMOTE_ADDR      => '127.0.0.1'
        },
        Expected    => {
            Result => '1',
            Log    => [
                {
                    Priority => 'notice',
                    Message  => '[Auth::HTTPBasicAuth] User \'1\' authentication ok. (REMOTE_ADDR: \'127.0.0.1\', Backend: \'UnitTest\')',
                    Index    => 0
                },
                {
                    Priority => 'debug',
                    Message  => '[Auth::HTTPBasicAuth] User \'Try1\' tried to authenticate. (REMOTE_ADDR: \'127.0.0.1\', Backend: \'UnitTest\')',
                    Index    => 0
                },
                {
                    Priority => 'debug',
                    Message  => '[Auth::HTTPBasicAuth] Pattern \'Test\' removed from given User. (REMOTE_ADDR: \'127.0.0.1\', Backend: \'UnitTest\')',
                    Index    => 1
                },
                {
                    Priority => 'debug',
                    Message  => '[Auth::HTTPBasicAuth] Pattern \'Try(\d+)\' replaced by first capture group for given User. (REMOTE_ADDR: \'127.0.0.1\', Backend: \'UnitTest\')',
                    Index    => 2
                }
            ]
        }
    },
    {
        Name     => 'Auth: ENV "REMOTE_USER", "HTTP_REMOTE_USER" and "REMOTE_ADDR" set',
        Environment => {
            REMOTE_USER      => 'TestTESTTry1',
            HTTP_REMOTE_USER => 'Try1',
            REMOTE_ADDR      => '127.0.0.1'
        },
        Expected    => {
            Result => 'TEST1',
            Log    => [
                {
                    Priority => 'notice',
                    Message  => '[Auth::HTTPBasicAuth] User \'TEST1\' authentication ok. (REMOTE_ADDR: \'127.0.0.1\', Backend: \'UnitTest\')',
                    Index    => 0
                },
                {
                    Priority => 'debug',
                    Message  => '[Auth::HTTPBasicAuth] User \'TestTESTTry1\' tried to authenticate. (REMOTE_ADDR: \'127.0.0.1\', Backend: \'UnitTest\')',
                    Index    => 0
                },
                {
                    Priority => 'debug',
                    Message  => '[Auth::HTTPBasicAuth] Pattern \'Test\' removed from given User. (REMOTE_ADDR: \'127.0.0.1\', Backend: \'UnitTest\')',
                    Index    => 1
                },
                {
                    Priority => 'debug',
                    Message  => '[Auth::HTTPBasicAuth] Pattern \'Try(\d+)\' replaced by first capture group for given User. (REMOTE_ADDR: \'127.0.0.1\', Backend: \'UnitTest\')',
                    Index    => 2
                }
            ]
        }
    },
);
for my $Test ( @AuthTests ) {
    # prepare environment
    for my $Attribute ( keys ( %{ $Test->{Environment} } ) ) {
        $ENV{ $Attribute } = $Test->{Environment}->{ $Attribute };
    }

    # use fresh log object for test
    $Kernel::OM->ObjectsDiscard(
        Objects => ['Log'],
    );

    # run Auth
    my $Result = $AuthObject->Auth();
    $Self->IsDeeply(
        $Result,
        $Test->{Expected}->{Result},
        $Test->{Name}
    );

    # check log message
    if ( ref( $Test->{Expected}->{Log} ) eq 'ARRAY' ) {
        for my $LogEntry ( @{ $Test->{Expected}->{Log} } ) {
            my $Message = $Kernel::OM->Get('Log')->GetLogEntry(
                Type  => $LogEntry->{Priority},
                What  => 'Message',
                Index => $LogEntry->{Index}
            );
            $Self->IsDeeply(
                $Message,
                $LogEntry->{Message},
                'Log for ' . $Test->{Name}
            );
        }
    }
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