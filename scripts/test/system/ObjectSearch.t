# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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

# get objectsearch object
my $ObjectSearch = $Kernel::OM->Get('ObjectSearch');

my @SearchTests = (
    {
        Name          => 'ObjectSearch > Search: No defined parameter',
        Parameter     => {
            Silent => 1
        },
        ResultDefined => ''
    },
    {
        Name          => 'ObjectSearch > Search: Missing ObjectType',
        Parameter     => {
            UserID => 1,
            Silent => 1
        },
        ResultDefined => ''
    },
    {
        Name          => 'ObjectSearch > Search: Missing UserID',
        Parameter     => {
            ObjectType => 'Ticket',
            Silent     => 1
        },
        ResultDefined => ''
    },
    {
        Name          => 'ObjectSearch > Search: Invalid ObjectType',
        Parameter     => {
            ObjectType => $Helper->GetRandomID(),
            UserID     => 1,
            Silent     => 1
        },
        ResultDefined => ''
    },
    {
        Name          => 'ObjectSearch > Search: Invalid UserType',
        Parameter     => {
            ObjectType => 'Ticket',
            UserID     => 1,
            UserType   => $Helper->GetRandomID(),
            Silent     => 1
        },
        ResultDefined => ''
    },
    {
        Name          => 'ObjectSearch > Search: Invalid Result',
        Parameter     => {
            ObjectType => 'Ticket',
            Result     => $Helper->GetRandomID(),
            UserID     => 1,
            Silent     => 1
        },
        ResultDefined => ''
    },
    {
        Name          => 'ObjectSearch > Search: Invalid Search',
        Parameter     => {
            ObjectType => 'Ticket',
            UserID     => 1,
            Search     => $Helper->GetRandomID(),
            Silent     => 1
        },
        ResultDefined => ''
    },
    {
        Name          => 'ObjectSearch > Search: Invalid Field in Search',
        Parameter     => {
            ObjectType => 'Ticket',
            UserID     => 1,
            Search     => {
                AND => [
                    {
                        Field    => $Helper->GetRandomID(),
                        Operator => 'EQ',
                        Value    => $Helper->GetRandomID()
                    }
                ]
            },
            Silent     => 1
        },
        ResultDefined => ''
    },
    {
        Name          => 'ObjectSearch > Search: Invalid Operator in Search',
        Parameter     => {
            ObjectType => 'Ticket',
            UserID     => 1,
            Search     => {
                AND => [
                    {
                        Field    => 'TicketID',
                        Operator => $Helper->GetRandomID(),
                        Value    => $Helper->GetRandomID()
                    }
                ]
            },
            Silent     => 1
        },
        ResultDefined => ''
    },
    {
        Name          => 'ObjectSearch > Search: Invalid Sort',
        Parameter     => {
            ObjectType => 'Ticket',
            UserID     => 1,
            Sort       => $Helper->GetRandomID(),
            Silent     => 1
        },
        ResultDefined => ''
    },
    {
        Name          => 'ObjectSearch > Search: Invalid Field in Sort',
        Parameter     => {
            ObjectType => 'Ticket',
            UserID     => 1,
            Sort       => [
                {
                    Field => $Helper->GetRandomID()
                }
            ],
            Silent     => 1
        },
        ResultDefined => ''
    },
    {
        Name          => 'ObjectSearch > Search: Invalid Limit',
        Parameter     => {
            ObjectType => 'Ticket',
            UserID     => 1,
            Limit      => $Helper->GetRandomID(),
            Silent     => 1
        },
        ResultDefined => ''
    },
    {
        Name          => 'ObjectSearch > Search: Invalid CacheTTL',
        Parameter     => {
            ObjectType => 'Ticket',
            UserID     => 1,
            CacheTTL   => $Helper->GetRandomID(),
            Silent     => 1
        },
        ResultDefined => ''
    },
    {
        Name          => 'ObjectSearch > Search: Minimal valid search',
        Parameter     => {
            ObjectType => 'Ticket',
            UserID     => 1
        },
        ResultDefined => '1'
    },
    {
        Name          => 'ObjectSearch > Search: UserType is Agent',
        Parameter     => {
            ObjectType => 'Ticket',
            UserType   => 'Agent',
            UserID     => 1
        },
        ResultDefined => '1'
    },
    {
        Name          => 'ObjectSearch > Search: UserType is Customer',
        Parameter     => {
            ObjectType => 'Ticket',
            UserType   => 'Customer',
            UserID     => 1
        },
        ResultDefined => '1'
    },
    {
        Name          => 'ObjectSearch > Search: Result is HASH',
        Parameter     => {
            ObjectType => 'Ticket',
            UserID     => 1,
            Result     => 'HASH'
        },
        ResultDefined => '1'
    },
    {
        Name          => 'ObjectSearch > Search: Result is ARRAY',
        Parameter     => {
            ObjectType => 'Ticket',
            UserID     => 1,
            Result     => 'ARRAY'
        },
        ResultDefined => '1'
    },
    {
        Name          => 'ObjectSearch > Search: Result is COUNT',
        Parameter     => {
            ObjectType => 'Ticket',
            UserID     => 1,
            Result     => 'COUNT'
        },
        ResultDefined => '1'
    },
    {
        Name          => 'ObjectSearch > Search: Accept Result in lower case',
        Parameter     => {
            ObjectType => 'Ticket',
            UserID     => 1,
            Result     => 'hash'
        },
        ResultDefined => '1'
    },
    {
        Name          => 'ObjectSearch > Search: CacheTTL is 0',
        Parameter     => {
            ObjectType => 'Ticket',
            UserID     => 1,
            CacheTTL   => 0
        },
        ResultDefined => '1'
    },
    {
        Name          => 'ObjectSearch > Search: Valid Search',
        Parameter     => {
            ObjectType => 'Ticket',
            UserID     => 1,
            Search     => {
                AND => [
                    {
                        Field    => 'TicketID',
                        Operator => 'EQ',
                        Value    => 1
                    }
                ]
            }
        },
        ResultDefined => '1'
    },
    {
        Name          => 'ObjectSearch > Search: Valid Sort',
        Parameter     => {
            ObjectType => 'Ticket',
            UserID     => 1,
            Sort       => [
                {
                    Field => 'TicketID'
                }
            ]
        },
        ResultDefined => '1'
    },
);
for my $Test ( @SearchTests ) {
    my $Result = $ObjectSearch->Search(
        %{ $Test->{Parameter} }
    );
    $Self->Is(
        defined( $Result ),
        $Test->{ResultDefined},
        $Test->{Name}
    );
}

my @GetSupportedAttributesTests = (
    {
        Name          => 'ObjectSearch > GetSupportedAttributes: Missing ObjectType',
        Parameter     => {
            Silent => 1
        },
        ResultDefined => '',
        ResultRef     => ''
    },
    {
        Name          => 'ObjectSearch > GetSupportedAttributes: Invalid ObjectType',
        Parameter     => {
            ObjectType => $Helper->GetRandomID(),
            Silent     => 1
        },
        ResultDefined => '',
        ResultRef     => ''
    },
);
for my $Test ( @GetSupportedAttributesTests ) {
    my $Result = $ObjectSearch->GetSupportedAttributes(
        %{ $Test->{Parameter} }
    );
    $Self->Is(
        defined( $Result ),
        $Test->{ResultDefined},
        $Test->{Name} . ' (defined)'
    );
    $Self->Is(
        ref( $Result ),
        $Test->{ResultRef},
        $Test->{Name} . ' (ref)'
    );
}

# begin transaction on database
$Helper->BeginWork();

# get general catalog entry for class 'Hardware'
my $ClassDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::ConfigItem::Class',
    Name  => 'Hardware',
);

# get general catalog entry for deployment state 'Production'
my $DeplStateDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::ConfigItem::DeploymentState',
    Name  => 'Production',
);

# get general catalog entry for incident state 'Operational'
my $InciStateDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::Core::IncidentState',
    Name  => 'Operational',
);

# get priority with ID 1
my %Priority = $Kernel::OM->Get('Priority')->PriorityGet(
    PriorityID => 1,
    UserID     => 1,
);

# get queue with ID 1
my %Queue = $Kernel::OM->Get('Queue')->QueueGet(
    ID => 1,
);

# get queue with ID 1
my %State = $Kernel::OM->Get('State')->StateGet(
    ID => 1,
);

# create test asset
my $AssetID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    ClassID => $ClassDataRef->{ItemID},
    UserID  => 1,
);

# get registered object types for backend database
my $RegisteredObjectTypes = $Kernel::OM->Get('Config')->Get('ObjectSearch::Database::ObjectType') || {};
for my $ObjectType ( sort( keys( %{ $RegisteredObjectTypes } ) ) ) {
    my $SupportedAttributes = $ObjectSearch->GetSupportedAttributes(
        ObjectType => $ObjectType
    );
    $Self->Is(
        defined( $SupportedAttributes ),
        '1',
        'ObjectSearch > GetSupportedAttributes: ObjectType ' . $ObjectType . ' (defined)'
    );
    $Self->Is(
        ref( $SupportedAttributes ),
        'ARRAY',
        'ObjectSearch > GetSupportedAttributes: ObjectType ' . $ObjectType . ' (ref)'
    );

    for my $Entry ( @{ $SupportedAttributes } ) {
        $Self->True(
            (
                ref( $Entry ) eq 'HASH'
                && defined( $Entry->{ObjectType} )
                && ref( $Entry->{ObjectType} ) eq ''
                && $Entry->{ObjectType} eq $ObjectType
                && defined( $Entry->{Property} )
                && ref( $Entry->{Property} ) eq ''
                && $Entry->{Property}
                && defined( $Entry->{IsSearchable} )
                && ref( $Entry->{IsSearchable} ) eq ''
                && defined( $Entry->{IsSortable} )
                && ref( $Entry->{IsSortable} ) eq ''
                && defined( $Entry->{Operators} )
                && ref( $Entry->{Operators} ) eq 'ARRAY'
                && defined( $Entry->{ValueType} )
                && ref( $Entry->{ValueType} ) eq ''
            ),
            'ObjectSearch > GetSupportedAttributes: ObjectType ' . $ObjectType . ' / Property ' . ($Entry->{Property} || '') . ' (expected structure)'
        );

        if ( $Entry->{IsSearchable} ) {
            if ( @{ $Entry->{Operators} } ) {
                for my $Operator ( @{ $Entry->{Operators} } ) {
                    my $SearchValue;
                    if ( $Entry->{ValueType} eq 'Integer' ) {
                        $SearchValue = 1;
                    }
                    elsif ( $Entry->{ValueType} eq 'Date' ) {
                        $SearchValue = '1990-01-01';
                    }
                    elsif ( $Entry->{ValueType} eq 'DateTime' ) {
                        $SearchValue = '1990-01-01 00:00:00';
                    }
                    elsif ( $Entry->{ValueType} eq 'Class.ID' ) {
                        $SearchValue = $ClassDataRef->{ItemID};
                    }
                    elsif ( $Entry->{ValueType} eq 'Class.Name' ) {
                        $SearchValue = $ClassDataRef->{Name};
                    }
                    elsif ( $Entry->{ValueType} eq 'DeploymentState.ID' ) {
                        $SearchValue = $DeplStateDataRef->{ItemID};
                    }
                    elsif ( $Entry->{ValueType} eq 'DeploymentState.Name' ) {
                        $SearchValue = $DeplStateDataRef->{Name};
                    }
                    elsif ( $Entry->{ValueType} eq 'IncidentState.ID' ) {
                        $SearchValue = $InciStateDataRef->{ItemID};
                    }
                    elsif ( $Entry->{ValueType} eq 'IncidentState.Name' ) {
                        $SearchValue = $InciStateDataRef->{Name};
                    }
                    elsif ( $Entry->{ValueType} eq 'Flag.y/n' ) {
                        $SearchValue = 'y';
                    }
                    elsif ( $Entry->{ValueType} eq 'Flag.ArrayOfHashes' ) {
                        $SearchValue = [
                            {
                                Flag  => 'Seen',
                                Value => 1
                            }
                        ];
                    }
                    elsif ( $Entry->{ValueType} eq 'Priority.Name' ) {
                        $SearchValue = $Priority{Name};
                    }
                    elsif ( $Entry->{ValueType} eq 'Queue.Name' ) {
                        $SearchValue = $Queue{Name};
                    }
                    elsif ( $Entry->{ValueType} eq 'State.Name' ) {
                        $SearchValue = $State{Name};
                    }
                    elsif ( $Entry->{ValueType} eq 'StateType.Name' ) {
                        $SearchValue = $State{TypeName};
                    }
                    elsif ( $Entry->{ValueType} eq 'Asset.ID' ) {
                        $SearchValue = $AssetID;
                    }
                    else {
                        $SearchValue = 'Test';
                    }

                    my $Result = $ObjectSearch->Search(
                        ObjectType => $ObjectType,
                        UserID     => 1,
                        Search     => {
                            AND => [
                                {
                                    Field    => $Entry->{Property},
                                    Operator => $Operator,
                                    Value    => $SearchValue
                                }
                            ]
                        }
                    );
                    $Self->Is(
                        defined( $Result ),
                        '1',
                        'ObjectSearch > Search: ObjectType ' . $ObjectType . ' / Property ' . ($Entry->{Property} || '') . ' IsSearchable / Operator ' . $Operator
                    );

                    if ( $Operator =~ m/IN/ ) {
                        $Result = $ObjectSearch->Search(
                            ObjectType => $ObjectType,
                            UserID     => 1,
                            Search     => {
                                AND => [
                                    {
                                        Field    => $Entry->{Property},
                                        Operator => $Operator,
                                        Value    => [ $SearchValue, $SearchValue ]
                                    }
                                ]
                            }
                        );
                        $Self->Is(
                            defined( $Result ),
                            '1',
                            'ObjectSearch > Search: ObjectType ' . $ObjectType . ' / Property ' . ($Entry->{Property} || '') . ' IsSearchable / Operator ' . $Operator . ' / value array'
                        );

                        $Result = $ObjectSearch->Search(
                            ObjectType => $ObjectType,
                            UserID     => 1,
                            Search     => {
                                AND => [
                                    {
                                        Field    => $Entry->{Property},
                                        Operator => $Operator,
                                        Value    => []
                                    }
                                ]
                            }
                        );
                        $Self->Is(
                            defined( $Result ),
                            '1',
                            'ObjectSearch > Search: ObjectType ' . $ObjectType . ' / Property ' . ($Entry->{Property} || '') . ' IsSearchable / Operator ' . $Operator . ' / empty value array'
                        );
                    }
                }
            }
            else {

            }
        }

        if ( $Entry->{IsSortable} ) {
            my $Result = $ObjectSearch->Search(
                ObjectType => $ObjectType,
                UserID     => 1,
                Sort       => [
                    {
                        Field => $Entry->{Property},
                    }
                ]
            );
            $Self->Is(
                defined( $Result ),
                '1',
                'ObjectSearch > Search: ObjectType ' . $ObjectType . ' / Property ' . ($Entry->{Property} || '') . ' IsSortable'
            );
        }
    }
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
