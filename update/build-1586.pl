#!/usr/bin/perl
# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
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
        LogPrefix => 'framework_update-to-build-1586',
    },
);

use vars qw(%INC);

_CreateChartReports();

sub _CreateChartReports {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Log');
    my $RoleObject = $Kernel::OM->Get('Role');
    my $ReportingObject = $Kernel::OM->Get('Reporting');

    my @RoleIDs = ();

    # get ID of relevant role
    my $ReportUserRoleID = $RoleObject->RoleLookup(
        Role => 'Report User',
    );
    if (!$ReportUserRoleID) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Cannot find 'Report User' role."
        );
    } else {
        push @RoleIDs, $ReportUserRoleID;
    }

    my $TicketAgentRoleID = $RoleObject->RoleLookup(
        Role => 'Ticket Agent',
    );
    if (!$TicketAgentRoleID) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Cannot find 'Ticket Agent' role."
        );
    } else {
        push @RoleIDs, $TicketAgentRoleID;
    }

    my $TicketReaderRoleID = $RoleObject->RoleLookup(
        Role => 'Ticket Reader',
    );
    if (!$TicketReaderRoleID) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Cannot find 'Ticket Reader' role."
        );
    }else {
        push @RoleIDs, $TicketReaderRoleID;
    }

    # get IDs of relevant permission types
    my %PermissionTypeID;
    foreach my $Type ( qw(Resource Object) ) {
        $PermissionTypeID{$Type} = $RoleObject->PermissionTypeLookup(
            Name => $Type
        );
        if (!$PermissionTypeID{$Type}) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Cannot find permission type '$Type'."
            );
        }
    }

    my @Definitions = (
        {
            Name       => Kernel::Language::Translatable('Number of tickets created within the last 7 days'),
            Comment    => Kernel::Language::Translatable('Lists tickets created within the last 7 days.'),
            DataSource => 'GenericSQL',
            IsPeriodic => 1,
            MaxReports => 1,
            Config     => {
                'DataSource' => {
                    'SQL' => {
                        'postgresql' => 'base64(U0VMRUNUIGRhdGUoY3JlYXRlX3RpbWUpIGFzIGRheSwgQ291bnQoKikgYXMgY291bnQgRlJPTSB0aWNrZXQKV0hFUkUgKGRhdGUoY3JlYXRlX3RpbWUpIEJFVFdFRU4gZGF0ZSgoTk9XKCkgLSBJTlRFUlZBTCAnNyBEQVknKSkgQU5EIGRhdGUoTk9XKCkpKQpHUk9VUCBCWSBkYXkKb3JkZXIgYnkgZGF5IEFTQzs=)',
                        'mysql'      => 'base64(U0VMRUNUIGRhdGUoY3JlYXRlX3RpbWUpIGFzIGRheSwgQ291bnQoKikgYXMgY291bnQgRlJPTSB0aWNrZXQKV0hFUkUgKGRhdGUoY3JlYXRlX3RpbWUpIEJFVFdFRU4gVElNRVNUQU1QKCBEQVRFX0ZPUk1BVChDVVJSRU5UX0RBVEUgLSBJTlRFUlZBTCA3IERBWSAsJyVZLSVtLTAxJykpIEFORCBjdXJyZW50X3RpbWUpCkdST1VQIEJZIGRheQpvcmRlciBieSBkYXkgQVNDOw==)'
                    }
                },
                "OutputFormats" => {
                    "CSV" => {
                        "IncludeColumnHeader"   => 1,
                        "Quote"                 => "\"",
                        "Separator"             => ",",
                        "TranslateColumnNames"  => 0
                    }
                }
            }
        },
        {
            Name       => Kernel::Language::Translatable('Number of open tickets by priority'),
            Comment    => Kernel::Language::Translatable('Lists open tickets by priority.'),
            DataSource => 'GenericSQL',
            IsPeriodic => 1,
            MaxReports => 1,
            Config     => {
                'DataSource' => {
                    'SQL' => {
                        'any' => 'base64(U0VMRUNUIHAubmFtZSwgQ291bnQoKikgYXMgY291bnQgRlJPTSB0aWNrZXQgdCAKSk9JTiB0aWNrZXRfcHJpb3JpdHkgcCBPTiB0LnRpY2tldF9wcmlvcml0eV9pZD1wLmlkCldIRVJFIHQudGlja2V0X3N0YXRlX2lkIElOICgKCVNFTEVDVCBpZCBGUk9NIHRpY2tldF9zdGF0ZSBzIAoJV0hFUkUgcy50eXBlX2lkIElOICgKCQlTRUxFQ1QgaWQgRlJPTSB0aWNrZXRfc3RhdGVfdHlwZSAKCQlXSEVSRSBuYW1lIElOKCduZXcnLCAnb3BlbicsJ3BlbmRpbmdfcmVtaW5kZXInLCAncGVuZGluZ19hdXRvJykKCSkKKQpHUk9VUCBCWSB0LnRpY2tldF9wcmlvcml0eV9pZCwgcC5pZApPUkRFUiBCWSBwLm5hbWU7)'
                    }
                },
                "OutputFormats" => {
                    "CSV" => {
                        "IncludeColumnHeader"   => 1,
                        "Quote"                 => "\"",
                        "Separator"             => ",",
                        "TranslateColumnNames"  => 0
                    }
                }
            }
        },
        {
            Name       => Kernel::Language::Translatable('Number of open tickets by state'),
            Comment    => Kernel::Language::Translatable('Lists open tickets by state.'),
            DataSource => 'GenericSQL',
            IsPeriodic => 1,
            MaxReports => 1,
            Config     => {
                'DataSource' => {
                    'SQL' => {
                        'any' => 'base64(U0VMRUNUIHMubmFtZSwgQ291bnQoKikgYXMgY291bnQgRlJPTSB0aWNrZXQgdCAKSk9JTiB0aWNrZXRfc3RhdGUgcyBPTiB0LnRpY2tldF9zdGF0ZV9pZD1zLmlkCldIRVJFIHQudGlja2V0X3N0YXRlX2lkIElOICgKCVNFTEVDVCBpZCBGUk9NIHRpY2tldF9zdGF0ZSB0cyAKCVdIRVJFIHRzLnR5cGVfaWQgSU4gKAoJCVNFTEVDVCBpZCBGUk9NIHRpY2tldF9zdGF0ZV90eXBlIAoJCVdIRVJFIG5hbWUgSU4oJ25ldycsICdvcGVuJywncGVuZGluZ19yZW1pbmRlcicsICdwZW5kaW5nX2F1dG8nKQoJKQopCkdST1VQIEJZIHQudGlja2V0X3N0YXRlX2lkLCBzLmlkOw==)'
                    }
                },
                "OutputFormats" => {
                    "CSV" => {
                        "IncludeColumnHeader"   => 1,
                        "Quote"                 => "\"",
                        "Separator"             => ",",
                        "TranslateColumnNames"  => 0
                    }
                }
            }
        },
        {
            Name       => Kernel::Language::Translatable('Number of open tickets in teams by priority'),
            Comment    => Kernel::Language::Translatable('Lists open tickets in teams by priority.'),
            DataSource => 'GenericSQL',
            IsPeriodic => 1,
            MaxReports => 1,
            Config     => {
                'DataSource' => {
                    'SQL' => {
                        'any' => 'base64(U0VMRUNUIHEubmFtZSBhcyBxdWV1ZV9uYW1lLCBwLm5hbWUgYXMgcHJpb3JpdHlfbmFtZSwgQ291bnQoKikgYXMgY291bnQgRlJPTSB0aWNrZXQgdCAKSk9JTiBxdWV1ZSBxIE9OIHQucXVldWVfaWQ9cS5pZApKT0lOIHRpY2tldF9wcmlvcml0eSBwIG9uIHQudGlja2V0X3ByaW9yaXR5X2lkPXAuaWQKV0hFUkUgdC50aWNrZXRfc3RhdGVfaWQgSU4gKAoJU0VMRUNUIGlkIEZST00gdGlja2V0X3N0YXRlIHRzIAoJV0hFUkUgdHMudHlwZV9pZCBJTiAoCgkJU0VMRUNUIGlkIEZST00gdGlja2V0X3N0YXRlX3R5cGUgCgkJV0hFUkUgbmFtZSBJTignbmV3JywgJ29wZW4nLCdwZW5kaW5nX3JlbWluZGVyJywgJ3BlbmRpbmdfYXV0bycpCgkpCikKR1JPVVAgQlkgcS5uYW1lLCBwLm5hbWUKT1JERVIgQlkgcS5uYW1lOwo=)'
                    }
                },
                "OutputFormats" => {
                    "CSV" => {
                        "IncludeColumnHeader"   => 1,
                        "Quote"                 => "\"",
                        "Separator"             => ",",
                        "TranslateColumnNames"  => 0
                    }
                }
            }
        },
        {
            Name       => Kernel::Language::Translatable('Number of open tickets by team'),
            Comment    => Kernel::Language::Translatable('Lists open tickets by team.'),
            DataSource => 'GenericSQL',
            IsPeriodic => 1,
            MaxReports => 1,
            Config     => {
                'DataSource' => {
                    'SQL' => {
                        'any' => 'base64(U0VMRUNUIHEubmFtZSBhcyBuYW1lLCBDb3VudCgqKSBhcyBjb3VudCBGUk9NIHRpY2tldCB0IApKT0lOIHF1ZXVlIHEgT04gdC5xdWV1ZV9pZD1xLmlkCldIRVJFIHQudGlja2V0X3N0YXRlX2lkIElOICgKCVNFTEVDVCBpZCBGUk9NIHRpY2tldF9zdGF0ZSB0cyAKCVdIRVJFIHRzLnR5cGVfaWQgSU4gKAoJCVNFTEVDVCBpZCBGUk9NIHRpY2tldF9zdGF0ZV90eXBlIAoJCVdIRVJFIG5hbWUgSU4oJ25ldycsICdvcGVuJywncGVuZGluZ19yZW1pbmRlcicsICdwZW5kaW5nX2F1dG8nKQoJKQopCkdST1VQIEJZIHEubmFtZQpPUkRFUiBCWSBxLm5hbWU7)'
                    }
                },
                "OutputFormats" => {
                    "CSV" => {
                        "IncludeColumnHeader"   => 1,
                        "Quote"                 => "\"",
                        "Separator"             => ",",
                        "TranslateColumnNames"  => 0
                    }
                }
            }
        },
        {
            Name       => Kernel::Language::Translatable('Number of tickets closed within the last 7 days'),
            Comment    => Kernel::Language::Translatable('Lists closed tickets within the last 7 days.'),
            DataSource => 'GenericSQL',
            IsPeriodic => 1,
            MaxReports => 1,
            Config     => {
                'DataSource' => {
                    'SQL' => {
                        'postgresql' => 'base64(U0VMRUNUIAogICAgZGF0ZSh0aC5jcmVhdGVfdGltZSkgYXMgZGF5LAogICAgQ291bnQoKikgYXMgY291bnQKRlJPTSB0aWNrZXQgdAogICAgCiAgICBMRUZUIEpPSU4gdGlja2V0X2hpc3RvcnkgdGggT04gCiAgICAgICAgdGgudGlja2V0X2lkPXQuaWQKICAgICAgICBBTkQgdGguaGlzdG9yeV90eXBlX2lkIElOICgKICAgICAgICAgICAgU0VMRUNUIGlkIEZST00gdGlja2V0X2hpc3RvcnlfdHlwZSB0aHQgV0hFUkUgKHRodC5uYW1lID0gJ1N0YXRlVXBkYXRlJyBPUiB0aHQubmFtZSA9ICdOZXdUaWNrZXQnKQogICAgICAgICkKICAgICAgICBBTkQgdGguc3RhdGVfaWQgSU4gKAogICAgICAgICAgICBTRUxFQ1QgaWQgZnJvbSB0aWNrZXRfc3RhdGUgdHMgV0hFUkUgdHMudHlwZV9pZCBJTiAoCiAgICAgICAgICAgICAgICBTRUxFQ1QgaWQgRlJPTSB0aWNrZXRfc3RhdGVfdHlwZSBXSEVSRSBuYW1lID0gJ2Nsb3NlZCcKICAgICAgICAgICAgKQogICAgICAgICkKICAgICAgICBBTkQgdGguY3JlYXRlX3RpbWUgQkVUV0VFTiAoTk9XKCkgLSBJTlRFUlZBTCAnNyBEQVknKSBBTkQgTk9XKCkKICAgICAgICAKV0hFUkUgdGguY3JlYXRlX3RpbWUgSVMgTk9UIE5VTEwKCkdST1VQIEJZIGRheQpPUkRFUiBCWSBkYXk7)',
                        'mysql'      => 'base64(U0VMRUNUIAogICAgZGF0ZSh0aC5jcmVhdGVfdGltZSkgYXMgZGF5LAogICAgQ291bnQoKikgYXMgY291bnQKRlJPTSB0aWNrZXQgdAogICAgCiAgICBMRUZUIEpPSU4gdGlja2V0X2hpc3RvcnkgdGggT04gCiAgICAgICAgdGgudGlja2V0X2lkPXQuaWQKICAgICAgICBBTkQgdGguaGlzdG9yeV90eXBlX2lkIElOICgKICAgICAgICAgICAgU0VMRUNUIGlkIEZST00gdGlja2V0X2hpc3RvcnlfdHlwZSB0aHQgV0hFUkUgKHRodC5uYW1lID0gJ1N0YXRlVXBkYXRlJyBPUiB0aHQubmFtZSA9ICdOZXdUaWNrZXQnKQogICAgICAgICkKICAgICAgICBBTkQgdGguc3RhdGVfaWQgSU4gKAogICAgICAgICAgICBTRUxFQ1QgaWQgZnJvbSB0aWNrZXRfc3RhdGUgdHMgV0hFUkUgdHMudHlwZV9pZCBJTiAoCiAgICAgICAgICAgICAgICBTRUxFQ1QgaWQgRlJPTSB0aWNrZXRfc3RhdGVfdHlwZSBXSEVSRSBuYW1lID0gJ2Nsb3NlZCcKICAgICAgICAgICAgKQogICAgICAgICkKICAgICAgICBBTkQgKGRhdGUodGguY3JlYXRlX3RpbWUpIEJFVFdFRU4gVElNRVNUQU1QKCBEQVRFX0ZPUk1BVChDVVJSRU5UX0RBVEUgLSBJTlRFUlZBTCA3IERBWSAsJyVZLSVtLTAxJykpIEFORCBjdXJyZW50X3RpbWUpCiAgICAgICAgICAgICAgCldIRVJFIHRoLmNyZWF0ZV90aW1lIElTIE5PVCBOVUxMCgpHUk9VUCBCWSBkYXkKT1JERVIgQlkgZGF5Ow==)'
                    }
                },
                "OutputFormats" => {
                    "CSV" => {
                        "IncludeColumnHeader"   => 1,
                        "Quote"                 => "\"",
                        "Separator"             => ",",
                        "TranslateColumnNames"  => 0
                    }
                }
            }
        }
    );

    my @DefinitionIDs;

    DEFINITION:
    foreach my $Definition ( @Definitions ) {
        my $DefinitionID = $ReportingObject->ReportDefinitionAdd(
            %{$Definition},
            UserID => 1,
        );
        if ( !$DefinitionID ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Cannot create report definition."
            );
            next DEFINITION;
        }
        else {
            $LogObject->Log(
                Priority => 'notice',
                Message  => "Created report definition $DefinitionID."
            );
        }
        push @DefinitionIDs, $DefinitionID;
    }

    if ( @DefinitionIDs ) {
        my @Permissions = (
            {
                Target => '/reporting',
                Value  => 2,
                TypeID => 1
            },
            {
                Target => '/reporting/reports',
                Value  => 2,
                TypeID => 1
            },
            {
                Target => '/reporting/reportdefinitions',
                Value  => 2,
                TypeID => 1
            },
            {
                Target => '/reporting/reportdefinitions/*',
                Value  => 0,
                TypeID => 1
            },
            {
                Target => '/reporting/reports{Report.DefinitionID !IN ['.(join(',', @DefinitionIDs)).']}',
                Value  => 0,
                TypeID => 2
            }
        );
        for my $DefinitionID (@DefinitionIDs) {
            push(
                @Permissions,
                {
                    Target => '/reporting/reportdefinitions/' . $DefinitionID,
                    Value  => 2,
                    TypeID => 1
                }
            );
        }

        foreach my $RoleID ( @RoleIDs ) {
            foreach my $Permission ( @Permissions ) {
                next if $RoleObject->PermissionLookup(
                    RoleID => $RoleID,
                    TypeID => $Permission->{TypeID},
                    Target => $Permission->{Target}
                );

                # assign object permissions
                my $Result = $RoleObject->PermissionAdd(
                    RoleID     => $RoleID,
                    TypeID     => $Permission->{TypeID},
                    Target     => $Permission->{Target},
                    Value      => $Permission->{Value},
                    IsRequired => 0,
                    Comment    => "Permission for role.",
                    UserID     => 1,
                );

                if ( !$Result ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message => "Could not create object permission for role '$RoleID' on $Permission->{Target}.",
                    );
                }
                else {
                    $LogObject->Log(
                        Priority => 'notice',
                        Message  => "Created object permission for role '$RoleID' on $Permission->{Target}."
                    );
                }
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
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
