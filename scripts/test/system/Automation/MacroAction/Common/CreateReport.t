# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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

# some preparations
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

# create macro
my $MacroID = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'CreateReport - Macro',
    Type    => 'Reporting',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroID,
    'MacroAdd',
);

# create macro action
my $MacroActionID = $Kernel::OM->Get('Automation')->MacroActionAdd(
    MacroID    => $MacroID,
    Type       => 'CreateReport',
    Parameters => {
        DefinitionID  => $DefinitionID,
        OutputFormats => [ 'CSV' ],
    },
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $MacroActionID,
    'MacroActionAdd',
);

# update macro - set ExecOrder
my $Success = $Kernel::OM->Get('Automation')->MacroUpdate(
    ID        => $MacroID,
    ExecOrder => [ $MacroActionID ],
    UserID    => 1,
);
$Self->True(
    $Success,
    'MacroUpdate - ExecOrder',
);

my @Tests = (
    {
        Name   => 'Only DefinitionID',
        Input  => {
            DefinitionID => $DefinitionID,
        },
        Silent => 1,
    },
    {
        Name    => 'Valid OutputFormats',
        Input   => {
            DefinitionID  => $DefinitionID,
            OutputFormats => [ 'CSV' ],
        },
        Results => {
            Content => <<'END',
"id";"name";"valid_id"
"1";"valid";
"2";"invalid";
"3";"invalid-temporarily";
END
            ContentSize => '78',
            ContentType => 'text/csv',
            Format      => 'CSV',
        },
    },
    {
        Name    => 'Invalid OutputFormats',
        Input   => {
            DefinitionID  => $DefinitionID,
            OutputFormats => [ 'Invalid' ],
        },
        Results => undef,
    },
    {
        Name    => ' Non-configured OutputFormats',
        Input   => {
            DefinitionID  => $DefinitionID,
            OutputFormats => [ 'PDF' ],
        },
        Results => undef,
    },
);

for my $Test ( @Tests ) {
    if ( $Test->{FixedTimeSet} ) {
        $Helper->FixedTimeSet(
            $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                String => $Test->{FixedTimeSet},
            ),
        );
    }

    # update parameters of MacroAction
    $Success = $Kernel::OM->Get('Automation')->MacroActionUpdate(
        ID      => $MacroActionID,
        Parameters => {
            %{ $Test->{Input} },
        },
        Silent  => $Test->{Silent},
        UserID  => 1,
        ValidID => 1,
    );

    if ( exists( $Test->{Results} ) ) {
        $Self->True(
            $Success,
            $Test->{Name} . ': MacroActionUpdate',
        );

        # check if placeholder is used
        $Success = $Kernel::OM->Get('Automation')->MacroExecute(
            ID       => $MacroID,
            ObjectID => 1,
            UserID   => 1,
        );
        $Self->True(
            $Success,
            $Test->{Name} . ': MacroExecute',
        );

        if ( ref( $Test->{Results} ) ) {
            for my $ResultKey ( sort( keys( %{ $Test->{Results} } ) ) ) {
                $Self->Is(
                    $Kernel::OM->Get('Automation')->{MacroVariables}->{Report}->{Results}->[0]->{ $ResultKey },
                    $Test->{Results}->{ $ResultKey },
                    $Test->{Name} . ': MacroExecute - macro variable "Report.Results.' . $ResultKey . '" of check macro',
                );
            }
        }
        else {
            $Self->Is(
                $Kernel::OM->Get('Automation')->{MacroVariables}->{Reports},
                $Test->{Results},
                $Test->{Name} . ': MacroExecute - macro variable "Report" of check macro',
            );
        }
    }
    else {
        $Self->False(
            $Success,
            $Test->{Name} . ': MacroActionUpdate fails',
        );
    }

    if ( $Test->{FixedTimeSet} ) {
        $Helper->FixedTimeUnset();
    }
}

# update report for test with parameters
$Success = $Kernel::OM->Get('Reporting')->ReportDefinitionUpdate(
    ID         => $DefinitionID,
    DataSource => 'GenericSQL',
    Name       => 'Testreport with parameters',
    Config     => {
        DataSource => {
            SQL => {
                any => "SELECT id, name, change_time, change_by, create_time, create_by FROM valid WHERE name LIKE '\${Parameters.Name}%'"
            }
        },
        Parameters => [
            {
                Name => "Name",
                DataType => 'STRING',
                Required => 1,
            }
        ],
        OutputFormats => {
            CSV => {
                Columns => ['id', 'name', 'valid_id']
            },
        }
    },
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $Success,
    'ReportDefinitionUpdate()',
);

@Tests = (
    {
        Name    => 'Without required parameters',
        Input   => {
            DefinitionID  => $DefinitionID,
            OutputFormats => ['CSV'],
        },
        Results => undef,
    },
    {
        Name    => 'With required parameters',
        Input   => {
            DefinitionID  => $DefinitionID,
            OutputFormats => ['CSV'],
            Parameters => {
                Name => 'in',
            },
        },
        Results => {
            Content => <<'END',
"id";"name";"valid_id"
"2";"invalid";
"3";"invalid-temporarily";
END
            ContentSize => '65',
            ContentType => 'text/csv',
            Format      => 'CSV',
        },
    },
);

for my $Test ( @Tests ) {
    if ( $Test->{FixedTimeSet} ) {
        $Helper->FixedTimeSet(
            $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                String => $Test->{FixedTimeSet},
            ),
        );
    }

    # update parameters of MacroAction
    $Success = $Kernel::OM->Get('Automation')->MacroActionUpdate(
        ID      => $MacroActionID,
        Parameters => {
            %{ $Test->{Input} },
        },
        UserID  => 1,
        ValidID => 1,
    );
    $Self->True(
        $Success,
        $Test->{Name} . ': MacroActionUpdate',
    );

    # check if placeholder is used
    $Success = $Kernel::OM->Get('Automation')->MacroExecute(
        ID       => $MacroID,
        ObjectID => 1,
        UserID   => 1,
    );
    $Self->True(
        $Success,
        $Test->{Name} . ': MacroExecute',
    );

    if ( ref( $Test->{Results} ) ) {
            for my $ResultKey ( sort( keys( %{ $Test->{Results} } ) ) ) {
                $Self->Is(
                    $Kernel::OM->Get('Automation')->{MacroVariables}->{Report}->{Results}->[0]->{ $ResultKey },
                    $Test->{Results}->{ $ResultKey },
                    $Test->{Name} . ': MacroExecute - macro variable "Report.Results.' . $ResultKey . '" of check macro',
                );
            }
    }
    else {
        $Self->Is(
            $Kernel::OM->Get('Automation')->{MacroVariables}->{Report},
            $Test->{Results},
            $Test->{Name} . ': MacroExecute - macro variable "Report" of check macro',
        );
    }

    if ( $Test->{FixedTimeSet} ) {
        $Helper->FixedTimeUnset();
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
