# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get needed objects
my $WebserviceObject = $Kernel::OM->Get('Webservice');

my $RandomID = $Kernel::OM->Get('UnitTest::Helper')->GetRandomID();

my @Tests = (
    {
        Name          => 'test 1',
        SuccessAdd    => 1,
        SuccessUpdate => 1,
        HistoryCount  => 1,
        Add           => {
            Config => {
                Name        => 'Nagios',
                Description => 'Connector to send and receive date from Nagios.',
                Provider => {
                    Transport => {
                        Config => {
                            NameSpace  => '',
                            SOAPAction => '',
                            Encoding   => '',
                            Endpoint   => '',
                        },
                    },
                    Operation => {
                        Operation1 => {
                            Mapping => {
                                Inbound => {
                                    1 => 2,
                                    2 => 4,
                                },
                                Outbound => {
                                    1 => 2,
                                    2 => 5,
                                },
                            },
                            Type => 'Test::Test',
                        },
                        Operation2 => {
                            Mapping => {
                                Inbound => {
                                    1 => 2,
                                    2 => 4,
                                },
                                Outbound => {
                                    1 => 2,
                                    2 => 5,
                                },
                            },
                        },
                    },
                },
            },
            ValidID => 1,
            UserID  => 1,
        },
    },
    {
        Name          => 'test 2',
        SuccessAdd    => 1,
        SuccessUpdate => 1,
        HistoryCount  => 1,
        Add           => {
            Config => {
                Name        => 'Nagios',
                Description => 'Connector to send and receive date from Nagios 2.',
                Debugger    => {
                    DebugThreshold => 'debug',
                    TestMode       => 1,
                },
                Provider => {
                    Transport => {
                        Type   => 'HTTP::SOAP',
                        Config => {
                            NameSpace  => '!"§$%&/()=?Ü*ÄÖL:L@,.-',
                            SOAPAction => '',
                            Encoding   => '',
                            Endpoint =>
                                'iojfoiwjeofjweoj ojerojgv oiaejroitjvaioejhtioja viorjhiojgijairogj aiovtq348tu 08qrujtio juortu oquejrtwoiajdoifhaois hnaeruoigbo eghjiob jaer89ztuio45u603u4i9tj340856u903 jvipojziopeji',
                        },
                    },
                    Operation => {
                        Operation1 => {
                            Mapping => {
                                Inbound => {
                                    1 => 2,
                                    2 => 4,
                                },
                                Outbound => {
                                    1 => 2,
                                    2 => 5,
                                },
                            },
                            Type => 'Test::Test',
                        },
                        Operation2 => {
                            Mapping => {
                                Inbound => {
                                    1 => 2,
                                    2 => 4,
                                },
                                Outbound => {
                                    1 => 2,
                                    2 => 5,
                                },
                            },
                        },
                    },
                },
            },
            ValidID => 2,
            UserID  => 1,
        },
    },
    {
        Name          => 'test 3',
        SuccessAdd    => 0,
        SuccessUpdate => 0,
        HistoryCount  => 2,
        Add           => {
            Config  => {},
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
        Update => {
            Config  => { 1 => 1 },
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 4',
        SuccessAdd    => 1,
        SuccessUpdate => 0,
        HistoryCount  => 2,
        Add           => {
            Config => {
                Name        => 'Nagios',
                Description => 'Connector to send and receive date from Nagios 2.'
                    . "\nasdkaosdkoa\tsada\n",
                Debugger => {
                    DebugThreshold => 'debug',
                    TestMode       => 1,
                },
                Provider => {
                    Transport => {
                        Type => '',
                    },
                },
            },
            ValidID => 2,
            UserID  => 1,
        },
        Update => {
            Config  => undef,
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },

    # the name must be 'test 4', because the purpose if that it fails on
    {
        Name          => 'test 4',
        SuccessAdd    => 0,
        SuccessUpdate => 0,
        HistoryCount  => 0,
        Add           => {
            Config => {
                Name        => 'Nagios',
                Description => 'Connector to send and receive date from Nagios 2.',
                Debugger    => {
                    DebugThreshold => 'debug',
                    TestMode       => 1,
                },
                Provider => {
                    Transport => {
                        Type => '',
                    },
                },
            },
            ValidID => 2,
            UserID  => 1,
            Silent  => 1,
        },
        Update => {
            Config  => undef,
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 5 - Invalid Config Add (Undef)',
        SuccessAdd    => 0,
        SuccessUpdate => 0,
        HistoryCount  => 0,
        Add           => {
            Config  => undef,
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 6 - Invalid Config Add (String)',
        SuccessAdd    => 0,
        SuccessUpdate => 0,
        HistoryCount  => 0,
        Add           => {
            Config  => 'Something',
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 7 - Invalid Config Add (Missing DebugThreshold)',
        SuccessAdd    => 0,
        SuccessUpdate => 0,
        HistoryCount  => 2,
        Add           => {
            Config => {
                Debugger => {},
                Provider => undef,
            },
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 8 - Invalid Config Add (Empty DebugThreshold)',
        SuccessAdd    => 0,
        SuccessUpdate => 0,
        HistoryCount  => 2,
        Add           => {
            Config => {
                Debugger => {
                    DebugThreshold => '',
                },
                Provider => undef,
            },
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 9 - Invalid Config Add (Undefined Provider)',
        SuccessAdd    => 0,
        SuccessUpdate => 0,
        HistoryCount  => 2,
        Add           => {
            Config => {
                Debugger => {
                    DebugThreshold => 'debug',
                },
                Provider => undef,
            },
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 10 - Invalid Config Add (String Provider)',
        SuccessAdd    => 0,
        SuccessUpdate => 0,
        HistoryCount  => 2,
        Add           => {
            Config => {
                Debugger => {
                    DebugThreshold => 'debug',
                },
                Provider => 'string',
            },
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 11 - Invalid Config Add (Empty Provider)',
        SuccessAdd    => 0,
        SuccessUpdate => 0,
        HistoryCount  => 2,
        Add           => {
            Config => {
                Debugger => {
                    DebugThreshold => 'debug',
                },
                Provider => {},
            },
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 12 - Invalid Config Add (Wrong Provider)',
        SuccessAdd    => 0,
        SuccessUpdate => 0,
        HistoryCount  => 2,
        Add           => {
            Config => {
                Debugger => {
                    DebugThreshold => 'debug',
                },
                Provider => {
                    Other => 1,
                },
            },
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 13 - Invalid Config Add (String Provider Transport)',
        SuccessAdd    => 0,
        SuccessUpdate => 0,
        HistoryCount  => 2,
        Add           => {
            Config => {
                Debugger => {
                    DebugThreshold => 'debug',
                },
                Provider => {
                    Transport => 'string',
                },
            },
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 14 - Invalid Config Add (Empty Provider Transport)',
        SuccessAdd    => 0,
        SuccessUpdate => 0,
        HistoryCount  => 2,
        Add           => {
            Config => {
                Debugger => {
                    DebugThreshold => 'debug',
                },
                Provider => {
                    Transport => {},
                },
            },
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 15 - Invalid Config Add (Wrong Provider Transport) must success',
        SuccessAdd    => 1,
        SuccessUpdate => 1,
        HistoryCount  => 1,
        Add           => {
            Config => {
                Debugger => {
                    DebugThreshold => 'debug',
                },
                Provider => {
                    Transport => {
                        Other => 1
                    },
                },
            },
            ValidID => 1,
            UserID  => 1,
        },
    },
    {
        Name          => 'test 16 - Invalid Config Update (string Config)',
        SuccessAdd    => 1,
        SuccessUpdate => 0,
        HistoryCount  => 1,
        Add           => {
            Config => {
                Debugger => {
                    DebugThreshold => 'debug',
                },
                Provider => {
                    Transport => {
                        Type => 'HTTP::Test'
                    },
                },
            },
            ValidID => 1,
            UserID  => 1,
        },
        Update => {
            Config  => 'string',
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 17 - Invalid Config Update (empty Config)',
        SuccessAdd    => 1,
        SuccessUpdate => 0,
        HistoryCount  => 1,
        Add           => {
            Config => {
                Debugger => {
                    DebugThreshold => 'debug',
                },
                Provider => {
                    Transport => {
                        Type => 'HTTP::Test'
                    },
                },
            },
            ValidID => 1,
            UserID  => 1,
        },
        Update => {
            Config  => {},
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 18 - Invalid Config Update (missing Debugger)',
        SuccessAdd    => 1,
        SuccessUpdate => 0,
        HistoryCount  => 1,
        Add           => {
            Config => {
                Debugger => {
                    DebugThreshold => 'debug',
                },
                Provider => {
                    Transport => {
                        Type => 'HTTP::Test'
                    },
                },
            },
            ValidID => 1,
            UserID  => 1,
        },
        Update => {
            Config => {
                Debugger => undef,
                Provider => {}
            },
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 19 - Invalid Config Update (empty Debugger)',
        SuccessAdd    => 1,
        SuccessUpdate => 0,
        HistoryCount  => 1,
        Add           => {
            Config => {
                Debugger => {
                    DebugThreshold => 'debug',
                },
                Provider => {
                    Transport => {
                        Type => 'HTTP::Test'
                    },
                },
            },
            ValidID => 1,
            UserID  => 1,
        },
        Update => {
            Config => {
                Debugger => {},
                Provider => {}
            },
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 20 - Invalid Config Update (missing Debugger DebugThreshold)',
        SuccessAdd    => 1,
        SuccessUpdate => 0,
        HistoryCount  => 1,
        Add           => {
            Config => {
                Debugger => {
                    DebugThreshold => 'debug',
                },
                Provider => {
                    Transport => {
                        Type => 'HTTP::Test'
                    },
                },
            },
            ValidID => 1,
            UserID  => 1,
        },
        Update => {
            Config => {
                Debugger => {
                    TestMode => 1,
                },
                Provider => {}
            },
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
    {
        Name          => 'test 21 - Invalid Config Update (empty Debugger DebugThreshold)',
        SuccessAdd    => 1,
        SuccessUpdate => 0,
        HistoryCount  => 1,
        Add           => {
            Config => {
                Debugger => {
                    DebugThreshold => 'debug',
                },
                Provider => {
                    Transport => {
                        Type => 'HTTP::Test'
                    },
                },
            },
            ValidID => 1,
            UserID  => 1,
        },
        Update => {
            Config => {
                Debugger => {
                    DebugThreshold => '',
                },
                Provider => {}
            },
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },
);

my @WebserviceIDs;
TEST:
for my $Test (@Tests) {

    # add config
    my $WebserviceID = $WebserviceObject->WebserviceAdd(
        %{ $Test->{Add} },
        Name => $Test->{Name} . ' ' . $RandomID,
    );
    if ( !$Test->{SuccessAdd} ) {
        $Self->False(
            $WebserviceID,
            "$Test->{Name} - WebserviceAdd()",
        );
        next TEST;
    }
    else {
        $Self->True(
            $WebserviceID,
            "$Test->{Name} - WebserviceAdd()",
        );
    }

    # remember id to delete it later
    push @WebserviceIDs, $WebserviceID;

    # get config
    my $Webservice = $WebserviceObject->WebserviceGet(
        ID => $WebserviceID,
    );

    # verify config
    $Self->Is(
        $Test->{Name} . ' ' . $RandomID,
        $Webservice->{Name},
        "$Test->{Name} - WebserviceGet()",
    );
    $Self->IsDeeply(
        $Webservice->{Config},
        $Test->{Add}->{Config},
        "$Test->{Name} - WebserviceGet() - Config",
    );

    my $WebserviceByName = $WebserviceObject->WebserviceGet(
        Name => $Test->{Name} . ' ' . $RandomID,
    );

    $Self->IsDeeply(
        \$WebserviceByName,
        \$Webservice,
        "$Test->{Name} - WebserviceGet() with Name parameter result",
    );

    # get config from cache
    my $WebserviceFromCache = $WebserviceObject->WebserviceGet(
        ID => $WebserviceID,
    );

    # verify config from cache
    $Self->Is(
        $Test->{Name} . ' ' . $RandomID,
        $WebserviceFromCache->{Name},
        "$Test->{Name} - WebserviceGet() from cache",
    );
    $Self->IsDeeply(
        $WebserviceFromCache->{Config},
        $Test->{Add}->{Config},
        "$Test->{Name} - WebserviceGet() from cache- Config",
    );

    $Self->IsDeeply(
        $Webservice,
        $WebserviceFromCache,
        "$Test->{Name} - WebserviceGet() - Cache and DB",
    );

    my $WebserviceByNameFromCache = $WebserviceObject->WebserviceGet(
        Name => $Test->{Name} . ' ' . $RandomID,
    );

    $Self->IsDeeply(
        \$WebserviceByNameFromCache,
        \$WebserviceFromCache,
        "$Test->{Name} - WebserviceGet() with Name parameter result from cache",
    );

    # update config with a modification
    if ( !$Test->{Update} ) {
        $Test->{Update} = $Test->{Add};
    }
    my $Success = $WebserviceObject->WebserviceUpdate(
        %{ $Test->{Update} },
        ID   => $WebserviceID,
        Name => $Test->{Name} . ' ' . $RandomID,
    );
    if ( !$Test->{SuccessUpdate} ) {
        $Self->False(
            $Success,
            "$Test->{Name} - WebserviceUpdate() False",
        );
        next TEST;
    }
    else {
        $Self->True(
            $Success,
            "$Test->{Name} - WebserviceUpdate() True",
        );
    }

    # get config
    $Webservice = $WebserviceObject->WebserviceGet(
        ID     => $WebserviceID,
        UserID => 1,
    );

    # verify config
    $Self->Is(
        $Test->{Name} . ' ' . $RandomID,
        $Webservice->{Name},
        "$Test->{Name} - WebserviceGet()",
    );
    $Self->IsDeeply(
        $Webservice->{Config},
        $Test->{Update}->{Config},
        "$Test->{Name} - WebserviceGet() - Config",
    );

    $WebserviceByName = $WebserviceObject->WebserviceGet(
        Name => $Test->{Name} . ' ' . $RandomID,
    );

    $Self->IsDeeply(
        \$WebserviceByName,
        \$Webservice,
        "$Test->{Name} - WebserviceGet() with Name parameter result",
    );

    # verify if cache was also updated
    if ( $Test->{SuccessUpdate} ) {
        my $WebserviceUpdateFromCache = $WebserviceObject->WebserviceGet(
            ID     => $WebserviceID,
            UserID => 1,
        );

        # verify config from cache
        $Self->Is(
            $Test->{Name} . ' ' . $RandomID,
            $WebserviceUpdateFromCache->{Name},
            "$Test->{Name} - WebserviceGet() from cache",
        );
        $Self->IsDeeply(
            $WebserviceUpdateFromCache->{Config},
            $Test->{Update}->{Config},
            "$Test->{Name} - WebserviceGet() from cache- Config",
        );
    }
}

# list check from DB
my $WebserviceList = $WebserviceObject->WebserviceList( Valid => 0 );
for my $WebserviceID (@WebserviceIDs) {
    $Self->True(
        scalar $WebserviceList->{$WebserviceID},
        "WebserviceList() from DB found Webservice $WebserviceID",
    );
}

# list check from cache
$WebserviceList = $WebserviceObject->WebserviceList( Valid => 0 );
for my $WebserviceID (@WebserviceIDs) {
    $Self->True(
        scalar $WebserviceList->{$WebserviceID},
        "WebserviceList() from Cache found Webservice $WebserviceID",
    );
}

# delete config
for my $WebserviceID (@WebserviceIDs) {
    my $Success = $WebserviceObject->WebserviceDelete(
        ID     => $WebserviceID,
        UserID => 1,
    );
    $Self->True(
        $Success,
        "WebserviceDelete() deleted Webservice $WebserviceID",
    );
    $Success = $WebserviceObject->WebserviceDelete(
        ID     => $WebserviceID,
        UserID => 1,
    );
    $Self->False(
        $Success,
        "WebserviceDelete() deleted Webservice $WebserviceID",
    );
}

# list check from DB
$WebserviceList = $WebserviceObject->WebserviceList( Valid => 0 );
for my $WebserviceID (@WebserviceIDs) {
    $Self->False(
        scalar $WebserviceList->{$WebserviceID},
        "WebserviceList() did not find webservice $WebserviceID",
    );
}

# list check from cache
$WebserviceList = $WebserviceObject->WebserviceList( Valid => 0 );
for my $WebserviceID (@WebserviceIDs) {
    $Self->False(
        scalar $WebserviceList->{$WebserviceID},
        "WebserviceList() from cache did not find webservice $WebserviceID",
    );
}

# cleanup cache
$Kernel::OM->Get('Cache')->CleanUp();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
