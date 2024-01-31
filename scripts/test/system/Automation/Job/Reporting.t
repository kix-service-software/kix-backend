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

my $AutomationObject = $Kernel::OM->Get('Automation');
my $ReportingObject  = $Kernel::OM->Get('Reporting');
my $MainObject       = $Kernel::OM->Get('Main');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my %Data = (
    Defintion_1_Name    => 'ReportDefFilter_1',
    Defintion_1_Comment => 'ReportDefCommentFilter_1',
    Defintion_2_Name    => 'ReportDefFilter_2',
    Defintion_2_Comment => 'ReportDefCommentFilter_2',
    Defintion_3_Name    => 'ReportDefFilter_3',
    Defintion_3_Comment => 'ReportDefCommentFilter_3'
);

my ($ReportingID_1, $ReportingID_2, $ReportingID_3) = _CreateReportingDefs();
if ($ReportingID_1) {
    my @TestData = (
        {
            Test   => 'without filter',
            Filter => undef,
            Expected => {
                Count => 3,
                IDs   => [$ReportingID_1, $ReportingID_2, $ReportingID_3]
            }
        },
        {
            Test   => 'AND filter for name of reporting definition 1',
            Filter => [
                {
                    AND => [
                        { Field => 'Name', Operator => 'EQ', Value => $Data{Defintion_1_Name} }
                    ]
                }
            ],
            Expected => {
                Count => 1,
                IDs   => [$ReportingID_1]
            }
        },
        {
            Test   => 'AND filter for name of reporting definition 1 (backward compatibility)', # filter is deprecated, should always be an array, but we will support it anyways
            Filter => {
                AND => [
                    { Field => 'Name', Operator => 'EQ', Value => $Data{Defintion_1_Name} }
                ]
            },
            Expected => {
                Count => 1,
                IDs   => [$ReportingID_1]
            }
        },
        {
            Test   => 'AND filter for comment of reporting definition 2',
            Filter => [
                {
                    AND => [
                        { Field => 'Comment', Operator => 'EQ', Value => $Data{Defintion_2_Comment} }
                    ]
                }
            ],
            Expected => {
                Count => 1,
                IDs   => [$ReportingID_2]
            }
        },
        {
            Test   => 'AND filter for comment of reporting definition 2 AND name of defintion 1',
            Filter => [
                {
                    AND => [
                        { Field => 'Comment', Operator => 'EQ', Value => $Data{Defintion_2_Comment} },
                        { Field => 'Name', Operator => 'EQ', Value => $Data{Defintion_1_Name} }
                    ]
                }
            ],
            Expected => {
                Count => 0,
                IDs   => []
            }
        },
        {
            Test   => 'AND filter for comment of reporting definition 2 AND name of defintion 1 (separate filter)',
            Filter => [
                {
                    AND => [
                        { Field => 'Comment', Operator => 'EQ', Value => $Data{Defintion_2_Comment} }
                    ]
                },
                {
                    AND => [
                        { Field => 'Name', Operator => 'EQ', Value => $Data{Defintion_1_Name} }
                    ]
                }
            ],
            Expected => {
                Count => 2,
                IDs   => [$ReportingID_1, $ReportingID_2]
            }
        }
    );

    # load job type backend module
    my $JobObject = $AutomationObject->_LoadJobTypeBackend(
        Name => 'Reporting',
    );
    $Self->True(
        $JobObject,
        'JobObject loaded',
    );

    # run checks
    foreach my $Test ( @TestData ) {
        my @ObjectIDs = $JobObject->Run(
            Data   => $Test->{Data},
            Filter => $Test->{Filter},
            UserID => 1,
        );

        # only reporting definitions wich are created by this test
        @ObjectIDs = $MainObject->GetCombinedList(
            ListA => \@ObjectIDs,
            ListB => [$ReportingID_1, $ReportingID_2, $ReportingID_3]
        );

        if ($Test->{Expected}->{Count}) {
            $Self->Is(
                scalar(@ObjectIDs),
                $Test->{Expected}->{Count},
                'Test "'.$Test->{Test}.'" - count ('.$Test->{Expected}->{Count}.')'
            );
        } else {
            $Self->False(
                scalar(@ObjectIDs),
                'Test "'.$Test->{Test}.'" - count (0)'
            );
        }

        if ($Test->{Expected}->{IDs}) {
            for my $ID (@{$Test->{Expected}->{IDs}}) {
                $Self->ContainedIn(
                    $ID,
                    \@ObjectIDs,
                    'Test "'.$Test->{Test}.'" - has ID',
                );
            }
        }
    }
}

# rollback transaction on database
$Helper->Rollback();

sub _CreateReportingDefs {
    my @ReportDefinitionIDs;
    for my $Index (1..3) {
        my $ReportDefinitionID = $Kernel::OM->Get('Reporting')->ReportDefinitionAdd(
            Name       => $Data{"Defintion_".$Index."_Name"},
            DataSource => 'TicketList',
            Comment    => $Data{"Defintion_".$Index."_Comment"},
            UserID     => 1
        );
        if ($ReportDefinitionID) {
            push(@ReportDefinitionIDs, $ReportDefinitionID);
        } else {
            $Self->True(
                0,
                "_CreateReportingDefs - could not create reporting definition (" . $Data{"Defintion_".$Index."_Name"} . ")",
            );
            return;
        }
    }
    return @ReportDefinitionIDs;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
