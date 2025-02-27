#!/usr/bin/perl
# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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
        LogPrefix => 'framework_update-to-build-1415',
    },
);

use vars qw(%INC);

_AddReportingRoles();
_CreateReports();

exit 0;

sub _AddReportingRoles {
    my ( $Self, %Param ) = @_;

    my $RoleObject = $Kernel::OM->Get('Role');

    my %RoleList = reverse $RoleObject->RoleList();
    my %PermissionTypeList = reverse $RoleObject->PermissionTypeList();

    my @NewRoles = (
        {
            Name => 'Report User',
            Comment => Kernel::Language::Translatable('allows to view report definitions and reports'),
            UsageContext => 1
        },
        {
            Name => 'Report Manager',
            Comment => Kernel::Language::Translatable('allows to create and edit report definitions'),
            UsageContext => 1
        },
    );

    foreach my $Role ( @NewRoles ) {
        my $RoleID = $RoleObject->RoleAdd(
            %{$Role},
            ValidID => 1,
            UserID  => 1,
        );
        if ( !$RoleID ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create role \"$Role->{Name}\"!",
            );
            next;
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Created role \"$Role->{Name}\"",
            );
        }
    }

    # reload role list
    %RoleList = reverse $RoleObject->RoleList();

    my @NewPermissions = (
        {
            Role   => 'Report User',
            Type   => 'Resource',
            Target => '/reporting',
            Value  => 3
        },
        {
            Role   => 'Report User',
            Type   => 'Resource',
            Target => '/reporting/*',
            Value  => 0
        },
        {
            Role   => 'Report User',
            Type   => 'Resource',
            Target => '/reporting/outputformats',
            Value  => 2
        },
        {
            Role   => 'Report User',
            Type   => 'Resource',
            Target => '/reporting/reports',
            Value  => 3
        },
        {
            Role   => 'Report User',
            Type   => 'Resource',
            Target => '/reporting/reportdefinitions',
            Value  => 2
        },
        {
            Role   => 'Report User',
            Type   => 'Resource',
            Target => '/reporting/reportdefinitions/*',
            Value  => 0
        },
        {
            Role   => 'Report User',
            Type   => 'Object',
            Target => '/reporting/reports{}',
            Value  => 0
        },
        {
            Role   => 'Report User',
            Type   => 'Object',
            Target => '/reporting/reports/*{}',
            Value  => 0
        },
        {
            Role   => 'Report Manager',
            Type   => 'Resource',
            Target => '/reporting',
            Value  => 15
        },
        {
            Role   => 'Report Manager',
            Type   => 'Resource',
            Target => '/system/roles',
            Value  => 6
        },
    );

    foreach my $Permission (@NewPermissions) {
        my $RoleID = $RoleList{$Permission->{Role}};
        if (!$RoleID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find role "' . $Permission->{Role} . '"!'
            );
            next;
        }
        my $PermissionTypeID = $PermissionTypeList{$Permission->{Type}};
        if (!$PermissionTypeID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find permission type "' . $Permission->{Type} . '"!'
            );
            next;
        }

        my $PermissionID = $RoleObject->PermissionLookup(
            RoleID => $RoleID,
            TypeID => $PermissionTypeID,
            Target => $Permission->{Target}
        );
        # nothing to do if this permission already exists
        next if $PermissionID;

        $PermissionID = $RoleObject->PermissionAdd(
            UserID => 1,
            RoleID => $RoleID,
            TypeID => $PermissionTypeID,
            %{$Permission},
        );

        if (!$PermissionID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create permission (role=$Permission->{Role}, type=$Permission->{Type}, target=$Permission->{Target})!"
            );
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Created permission ID $PermissionID!"
            );
        }
    }

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    return 1;
}

sub _CreateReports {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Log');
    my $RoleObject = $Kernel::OM->Get('Role');
    my $ReportingObject = $Kernel::OM->Get('Reporting');

    # get ID of relevant role
    my $ReportUserRoleID = $RoleObject->RoleLookup(
        Role => 'Report User',
    );
    if (!$ReportUserRoleID) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Cannot find 'Report User' role."
        );
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
            Name       => Kernel::Language::Translatable('Tickets Created In Date Range'),
            Comment    => Kernel::Language::Translatable('Lists tickets created in a specific date range. Organization may be selected before report creation.'),
            DataSource => 'GenericSQL',
            Config     => {
                'DataSource' => {
                    'SQL' => {
                        'any' => 'base64(U0VMRUNUIHR0Lm5hbWUgQVMgIlR5cGUiLCAKICAgICAgIHQudG4gQVMgIlROUiIsIAogICAgICAgdC50aXRsZSBBUyAiVGl0bGUiLCAKICAgICAgIHRzLm5hbWUgQVMgIlN0YXRlIiwKICAgICAgIG8ubmFtZSBBUyAiT3JnYW5pc2F0aW9uIiwgCiAgICAgICBjLmVtYWlsIEFTICJDb250YWN0IiwgCiAgICAgICB0LmFjY291bnRlZF90aW1lIEFTICJBY2NvdW50ZWQgVGltZSIKJHtGdW5jdGlvbnMuaWZfcGx1Z2luX2F2YWlsYWJsZSgnS0lYUHJvJywnLAogICAgIGRmdi52YWx1ZV90ZXh0IEFTICJDbG9zZSBDb2RlIiwKICAgICBzbGFfcmVzcG9uc2UubmFtZSBBUyAiU0xBIFJlc3BvbnNlIE5hbWUiLAogICAgIHRzY19yZXNwb25zZS50YXJnZXRfdGltZSBBUyAiU0xBIFJlc3BvbnNlIFRhcmdldCBUaW1lIiwgCiAgICAgdHNjX3Jlc3BvbnNlLmZ1bGZpbGxtZW50X3RpbWUgQVMgIlNMQSBSZXNwb25zZSBGdWxmaWxsbWVudCBUaW1lIiwgCiAgICAgdHNjX3Jlc3BvbnNlLnRpbWVfZGV2aWF0aW9uX2J1c2luZXNzIEFTICJTTEEgUmVzcG9uc2UgQnVzaW5lc3MgVGltZSBEZXZpYXRpb24iLAogICAgIHNsYV9zb2x1dGlvbi5uYW1lIEFTICJTTEEgU29sdXRpb24gTmFtZSIsCiAgICAgdHNjX3NvbHV0aW9uLnRhcmdldF90aW1lIEFTICJTTEEgU29sdXRpb24gVGFyZ2V0IFRpbWUiLCAKICAgICB0c2Nfc29sdXRpb24uZnVsZmlsbG1lbnRfdGltZSBBUyAiU0xBIFNvbHV0aW9uIEZ1bGZpbGxtZW50IFRpbWUiLCAKICAgICB0c2Nfc29sdXRpb24udGltZV9kZXZpYXRpb25fYnVzaW5lc3MgQVMgIlNMQSBTb2x1dGlvbiBCdXNpbmVzcyBUaW1lIERldmlhdGlvbiIKJyl9CiAgRlJPTSBvcmdhbmlzYXRpb24gbywgCiAgICAgICBjb250YWN0IGMsIAogICAgICAgdGlja2V0X3N0YXRlIHRzLAogICAgICAgdGlja2V0X3R5cGUgdHQsIAogICAgICAgdGlja2V0IHQKJHtGdW5jdGlvbnMuaWZfcGx1Z2luX2F2YWlsYWJsZSgnS0lYUHJvJywnCiAgTEVGVCBPVVRFUiBKT0lOIGR5bmFtaWNfZmllbGQgZGYgT04gKGRmLm5hbWUgPSAnQ2xvc2VDb2RlJykKICBMRUZUIE9VVEVSIEpPSU4gZHluYW1pY19maWVsZF92YWx1ZSBkZnYgT04gKGRmdi5vYmplY3RfaWQgPSB0LmlkIEFORCBkZnYuZmllbGRfaWQgPSBkZi5pZCkKICBMRUZUIE9VVEVSIEpPSU4gdGlja2V0X3NsYV9jcml0ZXJpb24gdHNjX3Jlc3BvbnNlIE9OICh0c2NfcmVzcG9uc2UudGlja2V0X2lkID0gdC5pZCBBTkQgdHNjX3Jlc3BvbnNlLm5hbWUgPSAnUmVzcG9uc2UnKQogIExFRlQgT1VURVIgSk9JTiBzbGEgQVMgc2xhX3Jlc3BvbnNlIE9OICh0c2NfcmVzcG9uc2Uuc2xhX2lkID0gc2xhX3Jlc3BvbnNlLmlkKQogIExFRlQgT1VURVIgSk9JTiB0aWNrZXRfc2xhX2NyaXRlcmlvbiB0c2Nfc29sdXRpb24gT04gKHRzY19zb2x1dGlvbi50aWNrZXRfaWQgPSB0LmlkIEFORCB0c2Nfc29sdXRpb24ubmFtZSA9ICdTb2x1dGlvbicpCiAgTEVGVCBPVVRFUiBKT0lOIHNsYSBBUyBzbGFfc29sdXRpb24gT04gKHRzY19zb2x1dGlvbi5zbGFfaWQgPSBzbGFfc29sdXRpb24uaWQpCicpfQogV0hFUkUgdC50eXBlX2lkID0gdHQuaWQKICAgQU5EIHQudGlja2V0X3N0YXRlX2lkID0gdHMuaWQKICAgQU5EIHQub3JnYW5pc2F0aW9uX2lkID0gby5pZAogICBBTkQgdC5jb250YWN0X2lkID0gYy5pZAogICBBTkQgby5pZCBJTiAoJHtQYXJhbWV0ZXJzLk9yZ2FuaXNhdGlvbklETGlzdH0pCiAgIEFORCB0LmNyZWF0ZV90aW1lIEJFVFdFRU4gJyR7UGFyYW1ldGVycy5TdGFydERhdGV9IDAwOjAwOjAwJyBBTkQgJyR7UGFyYW1ldGVycy5FbmREYXRlfSAyMzo1OTo1OScKIE9SREVSIEJZIHR0Lm5hbWUsIHQudG4)'
                    },
                    'OutputHandler' => [
                        {
                            'Name' => 'ResolveDynamicFieldValue',
                            'Columns' => ['Close Code'],
                            'FieldNames' => ['CloseCode']
                        },
                        {
                            'Name' => 'Translate',
                            'Columns' => ['Close Code','State','Type']
                        }
                    ]
                },
                'Parameters' => [
                    {
                        'Name' => 'StartDate',
                        'Label' => 'Start',
                        'DataType' => 'DATE',
                        'Required' => 1
                    },
                    {
                        'Name' => 'EndDate',
                        'Label' => 'End',
                        'DataType' => 'DATE',
                        'Required' => 1
                    },
                    {
                        'Name' => 'OrganisationIDList',
                        'Label' => 'Organisation',
                        'DataType' => 'NUMERIC',
                        'Multiple' => 1,
                        'References' => 'Organisation.ID',
                        'Required' => 1
                    }
                ]
            }
        },
        {
            Name       => Kernel::Language::Translatable('Tickets Closed In Date Range'),
            Comment    => Kernel::Language::Translatable('Lists tickets closed in a specific date range. Organization may be selected before report creation.'),
            DataSource => 'GenericSQL',
            Config     => {
                'DataSource' => {
                    'SQL' => {
                        'any' => 'base64(U0VMRUNUIHR0Lm5hbWUgQVMgIlR5cGUiLCAKICAgICAgIHQudG4gQVMgIlROUiIsIAogICAgICAgdC50aXRsZSBBUyAiVGl0bGUiLCAKICAgICAgIHRzLm5hbWUgQVMgIlN0YXRlIiwKICAgICAgIG8ubmFtZSBBUyAiT3JnYW5pc2F0aW9uIiwgCiAgICAgICBjLmVtYWlsIEFTICJDb250YWN0IiwgCiAgICAgICB0LmFjY291bnRlZF90aW1lIEFTICJBY2NvdW50ZWQgVGltZSIKJHtGdW5jdGlvbnMuaWZfcGx1Z2luX2F2YWlsYWJsZSgnS0lYUHJvJywnLAogICAgIGRmdi52YWx1ZV90ZXh0IEFTICJDbG9zZSBDb2RlIiwKICAgICBzbGFfcmVzcG9uc2UubmFtZSBBUyAiU0xBIFJlc3BvbnNlIE5hbWUiLAogICAgIHRzY19yZXNwb25zZS50YXJnZXRfdGltZSBBUyAiU0xBIFJlc3BvbnNlIFRhcmdldCBUaW1lIiwgCiAgICAgdHNjX3Jlc3BvbnNlLmZ1bGZpbGxtZW50X3RpbWUgQVMgIlNMQSBSZXNwb25zZSBGdWxmaWxsbWVudCBUaW1lIiwgCiAgICAgdHNjX3Jlc3BvbnNlLnRpbWVfZGV2aWF0aW9uX2J1c2luZXNzIEFTICJTTEEgUmVzcG9uc2UgQnVzaW5lc3MgVGltZSBEZXZpYXRpb24iLAogICAgIHNsYV9zb2x1dGlvbi5uYW1lIEFTICJTTEEgU29sdXRpb24gTmFtZSIsCiAgICAgdHNjX3NvbHV0aW9uLnRhcmdldF90aW1lIEFTICJTTEEgU29sdXRpb24gVGFyZ2V0IFRpbWUiICwgCiAgICAgdHNjX3NvbHV0aW9uLmZ1bGZpbGxtZW50X3RpbWUgQVMgIlNMQSBTb2x1dGlvbiBGdWxmaWxsbWVudCBUaW1lIiwgCiAgICAgdHNjX3NvbHV0aW9uLnRpbWVfZGV2aWF0aW9uX2J1c2luZXNzIEFTICJTTEEgU29sdXRpb24gQnVzaW5lc3MgVGltZSBEZXZpYXRpb24iCicpfQogIEZST00gb3JnYW5pc2F0aW9uIG8sIAogICAgICAgY29udGFjdCBjLCAKICAgICAgIHRpY2tldF90eXBlIHR0LAogICAgICAgdGlja2V0X3N0YXRlIHRzLAogICAgICAgdGlja2V0IHQKJHtGdW5jdGlvbnMuaWZfcGx1Z2luX2F2YWlsYWJsZSgnS0lYUHJvJywnCiAgTEVGVCBPVVRFUiBKT0lOIGR5bmFtaWNfZmllbGQgZGYgT04gKGRmLm5hbWUgPSAnQ2xvc2VDb2RlJykKICBMRUZUIE9VVEVSIEpPSU4gZHluYW1pY19maWVsZF92YWx1ZSBkZnYgT04gKGRmdi5vYmplY3RfaWQgPSB0LmlkIEFORCBkZnYuZmllbGRfaWQgPSBkZi5pZCkKICBMRUZUIE9VVEVSIEpPSU4gdGlja2V0X3NsYV9jcml0ZXJpb24gdHNjX3Jlc3BvbnNlIE9OICh0c2NfcmVzcG9uc2UudGlja2V0X2lkID0gdC5pZCBBTkQgdHNjX3Jlc3BvbnNlLm5hbWUgPSAnUmVzcG9uc2UnKQogIExFRlQgT1VURVIgSk9JTiBzbGEgQVMgc2xhX3Jlc3BvbnNlIE9OICh0c2NfcmVzcG9uc2Uuc2xhX2lkID0gc2xhX3Jlc3BvbnNlLmlkKQogIExFRlQgT1VURVIgSk9JTiB0aWNrZXRfc2xhX2NyaXRlcmlvbiB0c2Nfc29sdXRpb24gT04gKHRzY19zb2x1dGlvbi50aWNrZXRfaWQgPSB0LmlkIEFORCB0c2Nfc29sdXRpb24ubmFtZSA9ICdTb2x1dGlvbicpCiAgTEVGVCBPVVRFUiBKT0lOIHNsYSBBUyBzbGFfc29sdXRpb24gT04gKHRzY19zb2x1dGlvbi5zbGFfaWQgPSBzbGFfc29sdXRpb24uaWQpCicpfQogV0hFUkUgdC50eXBlX2lkID0gdHQuaWQKICAgQU5EIHQudGlja2V0X3N0YXRlX2lkID0gdHMuaWQKICAgQU5EIHQub3JnYW5pc2F0aW9uX2lkID0gby5pZAogICBBTkQgdC5jb250YWN0X2lkID0gYy5pZAogICBBTkQgby5pZCBJTiAoJHtQYXJhbWV0ZXJzLk9yZ2FuaXNhdGlvbklETGlzdH0pCiAgIEFORCBFWElTVFMgKAogICAgIFNFTEVDVCB0aC5pZCAKICAgICAgIEZST00gdGlja2V0X3N0YXRlIHRzLAogICAgICAgICAgICB0aWNrZXRfaGlzdG9yeSB0aCwKICAgICAgICAgICAgdGlja2V0X2hpc3RvcnlfdHlwZSB0aHQsCiAgICAgICAgICAgIHRpY2tldF9zdGF0ZV90eXBlIHRzdAogICAgICBXSEVSRSB0aC50aWNrZXRfaWQgPSB0LmlkCiAgICAgICAgQU5EIHRoLmhpc3RvcnlfdHlwZV9pZCA9IHRodC5pZAogICAgICAgIEFORCB0aHQubmFtZSA9ICdTdGF0ZVVwZGF0ZScKICAgICAgICBBTkQgdGguc3RhdGVfaWQgPSB0cy5pZAogICAgICAgIEFORCB0cy50eXBlX2lkID0gdHN0LmlkCiAgICAgICAgQU5EIHRzdC5uYW1lID0gJ2Nsb3NlZCcKICAgICAgICBBTkQgdGguY3JlYXRlX3RpbWUgQkVUV0VFTiAnJHtQYXJhbWV0ZXJzLlN0YXJ0RGF0ZX0gMDA6MDA6MDAnIEFORCAnJHtQYXJhbWV0ZXJzLkVuZERhdGV9IDIzOjU5OjU5JwogICApCiBPUkRFUiBCWSB0dC5uYW1lLCB0LnRu)'
                    },
                    'OutputHandler' => [
                        {
                            'Name' => 'ResolveDynamicFieldValue',
                            'Columns' => ['Close Code'],
                            'FieldNames' => ['CloseCode']
                        },
                        {
                            'Name' => 'Translate',
                            'Columns' => ['Close Code','State','Type']
                        }
                    ]
                },
                'Parameters' => [
                    {
                        'Name' => 'StartDate',
                        'Label' => 'Start',
                        'DataType' => 'DATE',
                        'Required' => 1
                    },
                    {
                        'Name' => 'EndDate',
                        'Label' => 'End',
                        'DataType' => 'DATE',
                        'Required' => 1
                    },
                    {
                        'Name' => 'OrganisationIDList',
                        'Label' => 'Organisation',
                        'DataType' => 'NUMERIC',
                        'Multiple' => 1,
                        'References' => 'Organisation.ID',
                        'Required' => 1
                    }
                ]
            }
        },
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

        if ( $ReportUserRoleID && scalar(keys %PermissionTypeID) == 2 && $DefinitionID ) {
            # assign resource permission
            my $Result = $RoleObject->PermissionAdd(
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
                $LogObject->Log(
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
            my $Result = $RoleObject->PermissionAdd(
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
                $LogObject->Log(
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
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
