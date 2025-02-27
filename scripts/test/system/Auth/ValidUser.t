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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $AuthModule = 'Kernel::System::Auth::ValidUser';

# require module
return if ( !$Kernel::OM->Get('Main')->Require( $AuthModule ) );

# create backend object
my $AuthObject = $AuthModule->new(
    %{ $Self },
    Name   => 'UnitTest',
    Config => {
        Debug => 1
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
    'Name'   => 'UnitTest',
    'Config' => {
        RelevantClientIPs => ['127.0.0.1'],
        RelevantUsers     => ['admin','Test1']
    }
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
        Name     => 'Auth: ENV "REMOTE_ADDR" empty, Parameter "UserID" and "RemoteAddresses" empty',
        Environment => {
            REMOTE_ADDR => ''
        },
        Input       => {
            User            => '',
            RemoteAddresses => []
        },
        Expected    => {
            Result => undef,
            Log    => [
                {
                    Priority => 'notice',
                    Message  => '[Auth::ValidUser] No User given. (REMOTE_ADDR: \'Got no REMOTE_ADDR env!\', Backend: \'UnitTest\')',
                    Index    => 0
                }
            ]
        }
    },
    {
        Name     => 'Auth: ENV "REMOTE_ADDR" set invalid, Parameter "UserID" set unrelevant, "RemoteAddresses" empty',
        Environment => {
            REMOTE_ADDR => '127.0.0.2'
        },
        Input       => {
            User            => 'Test',
            RemoteAddresses => []
        },
        Expected    => {
            Result => undef,
            Log    => [
                {
                    Priority => 'debug',
                    Message  => '[Auth::ValidUser] Client IP does not match RelevantClientIPs config. (REMOTE_ADDR: \'127.0.0.2\', Backend: \'UnitTest\')',
                    Index    => 0
                }
            ]
        }
    },
    {
        Name     => 'Auth: ENV "REMOTE_ADDR" empty, Parameter "UserID" set unrelevant, "RemoteAddresses" set invalid',
        Environment => {
            REMOTE_ADDR => ''
        },
        Input       => {
            User            => 'Test',
            RemoteAddresses => ['127.0.0.2']
        },
        Expected    => {
            Result => undef,
            Log    => [
                {
                    Priority => 'debug',
                    Message  => '[Auth::ValidUser] Client IP does not match RelevantClientIPs config. (REMOTE_ADDR: \'127.0.0.2\', Backend: \'UnitTest\')',
                    Index    => 0
                }
            ]
        }
    },
    {
        Name     => 'Auth: ENV "REMOTE_ADDR" set invalid, Parameter "UserID" set unrelevant, "RemoteAddresses" set invalid',
        Environment => {
            REMOTE_ADDR => '127.0.0.2'
        },
        Input       => {
            User            => 'Test',
            RemoteAddresses => ['127.0.0.3']
        },
        Expected    => {
            Result => undef,
            Log    => [
                {
                    Priority => 'debug',
                    Message  => '[Auth::ValidUser] Client IP does not match RelevantClientIPs config. (REMOTE_ADDR: \'127.0.0.3\', Backend: \'UnitTest\')',
                    Index    => 0
                }
            ]
        }
    },
    {
        Name     => 'Auth: ENV "REMOTE_ADDR" set valid, Parameter "UserID" set unrelevant, "RemoteAddresses" set invalid',
        Environment => {
            REMOTE_ADDR => '127.0.0.1'
        },
        Input       => {
            User            => 'Test',
            RemoteAddresses => ['127.0.0.3']
        },
        Expected    => {
            Result => undef,
            Log    => [
                {
                    Priority => 'debug',
                    Message  => '[Auth::ValidUser] Client IP does not match RelevantClientIPs config. (REMOTE_ADDR: \'127.0.0.3\', Backend: \'UnitTest\')',
                    Index    => 0
                }
            ]
        }
    },
    {
        Name     => 'Auth: ENV "REMOTE_ADDR" set invalid, Parameter "UserID" set unrelevant, "RemoteAddresses" set valid',
        Environment => {
            REMOTE_ADDR => '127.0.0.2'
        },
        Input       => {
            User            => 'Test',
            RemoteAddresses => ['127.0.0.1']
        },
        Expected    => {
            Result => undef,
            Log    => [
                {
                    Priority => 'debug',
                    Message  => '[Auth::ValidUser] User \'Test\' does not match RelevantUsers config. (REMOTE_ADDR: \'127.0.0.1\', Backend: \'UnitTest\')',
                    Index    => 0
                }
            ]
        }
    },
    {
        Name     => 'Auth: ENV "REMOTE_ADDR" set invalid, Parameter "UserID" set invalid, "RemoteAddresses" set valid',
        Environment => {
            REMOTE_ADDR => '127.0.0.2'
        },
        Input       => {
            User            => 'Test1',
            RemoteAddresses => ['127.0.0.1']
        },
        Expected    => {
            Result => undef,
            Log    => [
                {
                    Priority => 'notice',
                    Message  => 'Panic! No UserData for user: \'Test1\'!!!',
                    Index    => 0
                },
                {
                    Priority => 'notice',
                    Message  => '[Auth::ValidUser] User \'Test1\' is not a valid user. (REMOTE_ADDR: \'127.0.0.1\', Backend: \'UnitTest\')',
                    Index    => 1
                }
            ]
        }
    },
    {
        Name     => 'Auth: ENV "REMOTE_ADDR" empty, Parameter "UserID" set valid, "RemoteAddresses" set valid',
        Environment => {
            REMOTE_ADDR => ''
        },
        Input       => {
            User            => 'admin',
            RemoteAddresses => ['127.0.0.1']
        },
        Expected    => {
            Result => 'admin',
            Log    => [
                {
                    Priority => 'notice',
                    Message  => '[Auth::ValidUser] User \'admin\' authentication ok. (REMOTE_ADDR: \'127.0.0.1\', Backend: \'UnitTest\')',
                    Index    => 0
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
    my $Result = $AuthObject->Auth(
        %{ $Test->{Input} }
    );
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
