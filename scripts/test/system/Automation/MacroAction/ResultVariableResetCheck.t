# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# list of all macro actions provided and there result variables
my %MacroActions = ();
for my $MacroAction (
    qw(
        Loop ExecuteMacro ExtractText AssembleObject CreateReport VariableSet Conditional
    )
) {
    my $BackendObject = $Kernel::OM->Get('Automation')->_LoadMacroActionTypeBackend(
        MacroType => 'Synchronisation',
        Name      => $MacroAction,
    );
    if ( $BackendObject ) {
        my %Definition = $BackendObject->DefinitionGet();

        $MacroActions{ $MacroAction } = {
            MacroType       => 'Synchronisation',
            ResultVariables => {}
        };
        if ( IsHashRefWithData( $Definition{Results} ) ) {
            for my $ResultVariable ( values( %{ $Definition{Results} } ) ) {
                $MacroActions{ $MacroAction }->{ResultVariables}->{ $ResultVariable->{Name} } = {
                    Defined => 0,
                    NotDefined => 0
                };
            }
        }
    }
    else {
        $Self->True(
            0,
            'LoadMacroActionTypeBackend - Common::' . $MacroAction,
        );
    }
}
for my $MacroAction (
    qw(
        ArticleAttachmentsDelete ArticleCreate ArticleDelete ContactSet DynamicFieldSet
        LockSet OrganisationSet OwnerSet PrioritySet ResponsibleSet StateSet TeamSet
        TicketCreate TicketDelete TitleSet TypeSet FetchAssetAttributes
    )
) {
    my $BackendObject = $Kernel::OM->Get('Automation')->_LoadMacroActionTypeBackend(
        MacroType => 'Ticket',
        Name      => $MacroAction,
    );
    if ( $BackendObject ) {
        my %Definition = $BackendObject->DefinitionGet();

        $MacroActions{ $MacroAction } = {
            MacroType       => 'Ticket',
            ResultVariables => {}
        };
        if ( IsHashRefWithData( $Definition{Results} ) ) {
            for my $ResultVariable ( values( %{ $Definition{Results} } ) ) {
                $MacroActions{ $MacroAction }->{ResultVariables}->{ $ResultVariable->{Name} } = {
                    Defined => 0,
                    NotDefined => 0
                };
            }
        }
    }
    else {
        $Self->True(
            0,
            'LoadMacroActionTypeBackend - Ticket::' . $MacroAction,
        );
    }
}

### prepare data ###
# create definition
my $DefinitionID = $Kernel::OM->Get('Reporting')->ReportDefinitionAdd(
    DataSource => 'GenericSQL',
    Name       => 'Testreport without parameters',
    Config     => {
        DataSource => {
            SQL => {
                any => 'SELECT id, name, change_time, change_by, create_time, create_by FROM valid'
            }
        },
        OutputFormats => {
            CSV => {
                Columns => ['id', 'name', 'valid_id']
            },
        }
    },
    UserID => 1,
);

# create ticket
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title           => 'Testticket Unittest',
    TypeID          => 1,
    StateID         => 1,
    PriorityID      => 1,
    QueueID         => 1,
    OwnerID         => 1,
    UserID          => 1,
    LockID          => 1,
);
### EO prepare data ###

# create check macro
my $MacroIDCheck = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'Check Macro',
    Type    => 'Synchronisation',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroIDCheck,
    'Check MacroAdd',
);

# create macro
my $MacroID = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'Loop Macro',
    Type    => 'Synchronisation',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroID,
    'Loop MacroAdd',
);

# create macro action
my $MacroActionID = $Kernel::OM->Get('Automation')->MacroActionAdd(
    MacroID    => $MacroID,
    Type       => 'Loop',
    Parameters => {
        Values  => '',
        MacroID => $MacroIDCheck,
    },
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $MacroActionID,
    'Loop MacroActionAdd',
);

# update macro - set ExecOrder
my $Success = $Kernel::OM->Get('Automation')->MacroUpdate(
    ID        => $MacroID,
    ExecOrder => [ $MacroActionID ],
    UserID    => 1,
);
$Self->True(
    $Success,
    'Loop MacroUpdate - ExecOrder',
);

my @Tests = (
    {
        CheckType       => 'AssembleObject',
        CheckParameters => {
            Definition => '${ObjectID.Test}',
            Type       => 'JSON'
        },
        LoopValues      => [
            {Test => '{"Test":"Test"}'}
        ],
        DefinedResult   => 1
    },
    {
        CheckType       => 'AssembleObject',
        CheckParameters => {
            Definition => '${ObjectID.Test}',
            Type       => 'JSON'
        },
        LoopValues      => [
            {Test => '{"Test":"Test"}'},
            {Test => undef}
        ],
        DefinedResult   => 0
    },
    {
        CheckType       => 'CreateReport',
        CheckParameters => {
            DefinitionID  => '${ObjectID}',
            OutputFormats => [ 'CSV' ],
        },
        LoopValues      => [
            $DefinitionID
        ],
        DefinedResult   => 1
    },
    {
        CheckType       => 'CreateReport',
        CheckParameters => {
            DefinitionID  => '${ObjectID}',
            OutputFormats => [ 'CSV' ],
        },
        LoopValues      => [
            $DefinitionID,
            999999
        ],
        DefinedResult   => 0
    },
    {
        CheckType       => 'ExtractText',
        CheckParameters => {
            RegEx => '${ObjectID.Test}'
        },
        LoopValues      => [
            {Test => '(.+)'}
        ],
        DefinedResult   => 1
    },
    {
        CheckType       => 'ExtractText',
        CheckParameters => {
            RegEx => '${ObjectID.Test}'
        },
        LoopValues      => [
            {Test => '(.+)'},
            {Test => undef}
        ],
        DefinedResult   => 0
    },
    {
        CheckType       => 'VariableSet',
        CheckParameters => {
            Value => '${ObjectID.Test}'
        },
        LoopValues      => [
            {Test => 'Test'}
        ],
        DefinedResult   => 1
    },
    {
        CheckType       => 'VariableSet',
        CheckParameters => {
            Value => '${ObjectID.Test}'
        },
        LoopValues      => [
            {Test => 'Test'},
            {Test => undef}
        ],
        DefinedResult   => 0
    },
    {
        CheckType       => 'ArticleCreate',
        CheckParameters => {
            Subject => 'Test',
            Body    => 'Test',
        },
        LoopValues      => [
            $TicketID
        ],
        DefinedResult   => 1
    },
    {
        CheckType       => 'ArticleCreate',
        CheckParameters => {
            Subject => 'Test',
            Body    => 'Test',
        },
        LoopValues      => [
            $TicketID,
            999999
        ],
        DefinedResult   => 0
    },
    {
        CheckType       => 'TicketCreate',
        CheckParameters => {
            ContactEmailOrID => '${ObjectID}',
            Priority         => '3 normal',
            State            => 'open',
            Title            => 'Test',
            Team             => 'Service Desk',
            Subject          => 'Test',
            Body             => 'Test',

        },
        LoopValues      => [
            'test@kixdesk.com'
        ],
        DefinedResult   => 1
    },
    {
        CheckType       => 'TicketCreate',
        CheckParameters => {
            ContactEmailOrID => '${ObjectID}',
            Priority         => '3 normal',
            State            => 'open',
            Title            => 'Test',
            Team             => 'Service Desk',
            Subject          => 'Test',
            Body             => 'Test',

        },
        LoopValues      => [
            'test@kixdesk.com',
            ''
        ],
        DefinedResult   => 0
    },
);

for my $Test ( @Tests ) {
    next if ( !defined( $MacroActions{ $Test->{CheckType} } ) );

    # prepare testname
    my $TestName = $Test->{CheckType} . ' - ' . ( $Test->{DefinedResult} ? '' : 'Not ' ) . 'Defined Result - ';

    # update macro - set ExecOrder
    $Success = $Kernel::OM->Get('Automation')->MacroUpdate(
        ID     => $MacroIDCheck,
        Type   => $MacroActions{ $Test->{CheckType} }->{MacroType},
        UserID => 1,
    );
    $Self->True(
        $Success,
        $TestName . 'Check MacroUpdate - Type',
    );

    # create macro action
    my $MacroActionIDCheck = $Kernel::OM->Get('Automation')->MacroActionAdd(
        MacroID    => $MacroIDCheck,
        Type       => $Test->{CheckType},
        Parameters => $Test->{CheckParameters},
        ValidID    => 1,
        UserID     => 1,
    );
    $Self->True(
        $MacroActionIDCheck,
        $TestName . 'Check MacroActionAdd',
    );

    # update macro - set ExecOrder
    $Success = $Kernel::OM->Get('Automation')->MacroUpdate(
        ID        => $MacroIDCheck,
        ExecOrder => [ $MacroActionIDCheck ],
        UserID    => 1,
    );
    $Self->True(
        $Success,
        $TestName . 'Check MacroUpdate - Type',
    );

    # update parameters of Loop MacroAction
    $Success = $Kernel::OM->Get('Automation')->MacroActionUpdate(
        ID         => $MacroActionID,
        Parameters => {
            Values  => $Test->{LoopValues},
            MacroID => $MacroIDCheck,
        },
        UserID  => 1,
        ValidID => 1,
    );
    $Self->True(
        $Success,
        $TestName . 'Loop MacroActionUpdate',
    );

    {
        # silence console output
        local *STDOUT;
        local *STDERR;
        open STDOUT, '>>', "/dev/null";
        open STDERR, '>>', "/dev/null";

        # check if placeholder is used
        $Success = $Kernel::OM->Get('Automation')->MacroExecute(
            ID       => $MacroID,
            ObjectID => 1,
            UserID   => 1,
        );

        close STDOUT;
        close STDERR;
    };
    $Self->True(
        $Success,
        $TestName . 'Loop MacroExecute',
    );

    my $HasResultVariables = IsHashRefWithData( $MacroActions{ $Test->{CheckType} }->{ResultVariables} );
    $Self->True(
        $HasResultVariables,
        $TestName . 'Has ResultVariables',
    );

    if ( $HasResultVariables ) {
        for my $ResultVariable ( sort( keys( %{ $MacroActions{ $Test->{CheckType} }->{ResultVariables} } ) ) ) {
            my $DefinedResult = defined( $Kernel::OM->Get('Automation')->{MacroVariables}->{ $ResultVariable } );

            if ( $Test->{DefinedResult} ) {
                $Self->True(
                    $DefinedResult,
                    $TestName . 'MacroVariable "' . $ResultVariable . '" is defined',
                );

                $MacroActions{ $Test->{CheckType} }->{ResultVariables}->{ $ResultVariable }->{Defined} = 1;
            }
            else {
                $Self->True(
                    !$DefinedResult,
                    $TestName . 'MacroVariable "' . $ResultVariable . '" is not defined',
                );

                $MacroActions{ $Test->{CheckType} }->{ResultVariables}->{ $ResultVariable }->{NotDefined} = 1;
            }
        }
    }
}

for my $MacroAction ( sort( keys( %MacroActions ) ) ) {
    if ( IsHashRefWithData( $MacroActions{ $MacroAction }->{ResultVariables} ) ) {
        for my $Check ( qw( Defined NotDefined ) ) {
            for my $ResultVariable ( sort( keys( %{ $MacroActions{ $MacroAction }->{ResultVariables} } ) ) ) {
                if ( !$MacroActions{ $MacroAction }->{ResultVariables}->{ $ResultVariable }->{ $Check } ) {
                    $Self->True(
                        $MacroActions{ $MacroAction }->{ResultVariables}->{ $ResultVariable }->{ $Check },
                        $MacroAction . ' - "' . $Check . '" check for "' . $ResultVariable . '"',
                    );
                }
            }
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
