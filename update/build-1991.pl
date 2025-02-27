#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1991',
    },
);

use vars qw(%INC);

# create the initial reports
_CreateReports();

sub _CreateReports {
    my ( $Self, %Param ) = @_;

    # get ID of relevant role
    my $ReportUserRoleID = $Kernel::OM->Get('Role')->RoleLookup(
        Role => 'Report User',
    );
    if (!$ReportUserRoleID) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Cannot find 'Report User' role."
        );
    }

    # get IDs of relevant permission types
    my %PermissionTypeID;
    foreach my $Type ( qw(Resource Object) ) {
        $PermissionTypeID{$Type} = $Kernel::OM->Get('Role')->PermissionTypeLookup(
            Name => $Type
        );
        if (!$PermissionTypeID{$Type}) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Cannot find permission type '$Type'."
            );
        }
    }

    my @Definitions = (
        {
            Name       => Kernel::Language::Translatable('Duration in State and Team'),
            Comment    => Kernel::Language::Translatable('Lists of tickets with their durations in specified states and teams.'),
            DataSource => 'GenericSQL',
            Config     => {
                "DataSource" => {
                    "SQL" => {
                        "any" => "base64(U0VMRUNUIAogICAgdC50biBBUyAiVGlja2V0TnVtYmVyIiwKICAgIHRvcmcubmFtZSBBUyAiT3JnYW5pc2F0aW9uIiwKICAgIHQudGl0bGUgQVMgIlRpdGxlIiwKICAgIHRzLm5hbWUgQVMgIkN1cnJlbnRTdGF0ZSIsCiAgICB0cS5uYW1lIEFTICJDdXJyZW50VGVhbSIsCiAgICB0LmlkIEFTICJTdGF0ZUR1cmF0aW9uTmV3IiwKICAgIHQuaWQgQVMgIlN0YXRlQ291bnROZXciLAogICAgdC5pZCBBUyAiU3RhdGVEdXJhdGlvbk9wZW4iLAogICAgdC5pZCBBUyAiU3RhdGVDb3VudE9wZW4iLAogICAgdC5pZCBBUyAiU3RhdGVEdXJhdGlvblBlbmRpbmdSZW1pbmRlciIsCiAgICB0LmlkIEFTICJTdGF0ZUNvdW50UGVuZGluZ1JlbWluZGVyIiwKICAgIHQuaWQgQVMgIlRlYW1EdXJhdGlvblNlcnZpY2VEZXNrIiwKICAgIHQuaWQgQVMgIlRlYW1Db3VudFNlcnZpY2VEZXNrIgoKRlJPTSB0aWNrZXQgQVMgdApMRUZUIEpPSU4gb3JnYW5pc2F0aW9uIEFTIHRvcmcgT04gdC5vcmdhbmlzYXRpb25faWQgPSB0b3JnLmlkCklOTkVSIEpPSU4gdGlja2V0X3N0YXRlIEFTIHRzIE9OIHQudGlja2V0X3N0YXRlX2lkID0gdHMuaWQKSU5ORVIgSk9JTiBxdWV1ZSBBUyB0cSBPTiB0LnF1ZXVlX2lkID0gdHEuaWQKICAgICAgICAgICAgICAKV0hFUkUgKCAnJHtQYXJhbWV0ZXJzLk9yZ2FuaXNhdGlvbklETGlzdD8wfScgPSAnMCcgT1IgdC5vcmdhbmlzYXRpb25faWQgSU4gKCR7UGFyYW1ldGVycy5PcmdhbmlzYXRpb25JRExpc3Q / MH0pICkKICBBTkQgKCAnJHtQYXJhbWV0ZXJzLlR5cGVJRExpc3Q / MH0nID0gJzAnIE9SIHQudHlwZV9pZCBJTiAoJHtQYXJhbWV0ZXJzLlR5cGVJRExpc3Q / MH0pICkKICBBTkQgKCAnJHtQYXJhbWV0ZXJzLlN0YXRlSURMaXN0PzB9JyA9ICcwJyBPUiB0LnRpY2tldF9zdGF0ZV9pZCBJTiAoJHtQYXJhbWV0ZXJzLlN0YXRlSURMaXN0PzB9KSApCgpPUkRFUiBCWSB0LnRuOw ==)"
                    },
                    "OutputHandler" => [
                        {
                            "States" => [
                                "new ",
                                "open",
                                "pending reminder"
                            ],
                            "Columns" => [
                                "StateDurationNew",
                                "StateDurationOpen",
                                "StateDurationPendingReminder"
                            ],
                            "Name" => "TicketStateDuration"
                        },
                        {
                            "Name" => "TicketStateCount",
                            "States" => [
                                "new",
                                "open",
                                "pending reminder"
                            ],
                            "Columns" => [
                                "StateCountNew",
                                "StateCountOpen",
                                "StateCountPendingReminder"
                            ]
                        },
                        {
                            "Name" => "TicketTeamDuration",
                            "RelevantStates" => ["open"],
                            "StopStates" => ["closed"],
                            "Columns" => ["TeamDurationServiceDesk"],
                            "Teams" => ["Service Desk"]
                        },
                        {
                            "Columns" => ["TeamCountServiceDesk"],
                            "Teams" => ["Service Desk"],
                            "Name" => "TicketTeamCount"
                        }
                    ]
                },
                "OutputFormats" => {
                    "CSV" => {
                        "Separator" => ", ",
                        "Quote" => "\"",
                        "IncludeColumnHeader" => 1
                    }
                },
                "Parameters" => [
                    {
                        "References" => "Organisation.ID",
                        "Multiple" => 1,
                        "Default" => undef,
                        "DataType" => "NUMERIC",
                        "ReadOnly" => 0,
                        "Label" => "Organisations",
                        "Required" => 0,
                        "Name" => "OrganisationIDList",
                        "PossibleValues" => undef
                    },
                    {
                        "References" => "TicketType.ID",
                        "DataType" => "NUMERIC",
                        "Multiple" => 1,
                        "Default" => undef,
                        "Required" => 0,
                        "Label" => "Ticket Types",
                        "PossibleValues" => undef,
                        "Name" => "TypeIDList",
                        "Description" => undef,
                        "ReadOnly" => 0
                    },
                    {
                        "ReadOnly" => 0,
                        "Description" => undef,
                        "PossibleValues" => undef,
                        "Name" => "StateIDList",
                        "Required" => 0,
                        "Label" => "Ticket States",
                        "DataType" => "NUMERIC",
                        "Default" => undef,
                        "Multiple" => 1,
                        "References" => "TicketState.ID"
                    }
                ]
            }
        }
    );

    my @DefinitionIDs;

    DEFINITION:
    foreach my $Definition ( @Definitions ) {
        my $DefinitionID = $Kernel::OM->Get('Reporting')->ReportDefinitionAdd(
            %{$Definition},
            UserID => 1,
        );
        if ( !$DefinitionID ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Cannot create report definition."
            );
            next DEFINITION;
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "Created report definition $DefinitionID."
            );
        }
        push @DefinitionIDs, $DefinitionID;


        if ( $ReportUserRoleID && scalar(keys %PermissionTypeID) == 2 && $DefinitionID ) {
            # assign resource permission
            my $Result = $Kernel::OM->Get('Role')->PermissionAdd(
                RoleID     => $ReportUserRoleID,
                TypeID     => $PermissionTypeID{Resource},
                Target     => '/reporting/reportdefinitions/' . $DefinitionID,
                Value      => 2,
                IsRequired => 0,
                Comment    => "Permission for Report User",
                UserID     => 1,
            );

            if ( !$Result ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message => "Could not create resource permission for report definition with ID $DefinitionID.",
                );
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'notice',
                    Message  => "Created resource permission for role 'Report User' on /reporting/reportdefinitions/$DefinitionID."
                );
            }
        }
    }

    if ( @DefinitionIDs ) {
        my @Permissions = (
            {
                Target => '/reporting/reports{Report.DefinitionID IN ['.(join(',', @DefinitionIDs)).']}',
                Value  => 3,        # CR--
            },
            {
                Target => '/reporting/reports/*{Report.DefinitionID IN ['.(join(',', @DefinitionIDs)).']}',
                Value  => 2,        # -R--
            },
        );

        foreach my $Permission ( @Permissions ) {
            # assign object permissions
            my $Result = $Kernel::OM->Get('Role')->PermissionAdd(
                RoleID     => $ReportUserRoleID,
                TypeID     => $PermissionTypeID{Object},
                Target     => $Permission->{Target},
                Value      => $Permission->{Value},
                IsRequired => 0,
                Comment    => "Permission for role 'Report User'.",
                UserID     => 1,
            );

            if ( !$Result ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message => "Could not create object permission for role 'Report User' on $Permission->{Target}.",
                );
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'notice',
                    Message  => "Created object permission for role 'Report User' on $Permission->{Target}."
                );
            }
        }
    }

    return 1;
}

exit 0;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
