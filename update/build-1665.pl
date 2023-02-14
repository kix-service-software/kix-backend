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
use Kernel::System::Role::Permission;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1665',
    },
);

use vars qw(%INC);

_UpdateReports();
_MigrateCheckboxDFValues();
_AddNewPermissions();

# correct states in inital reports (e.g. "pending_reminder" => "pending reminder")
sub _UpdateReports {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Log');
    my $ReportingObject = $Kernel::OM->Get('Reporting');

    my @UpdateReports = (
        {
            Name   => 'Number of open tickets by priority',
            OldSQL => 'base64(U0VMRUNUIHAubmFtZSwgQ291bnQoKikgYXMgY291bnQgRlJPTSB0aWNrZXQgdCAKSk9JTiB0aWNrZXRfcHJpb3JpdHkgcCBPTiB0LnRpY2tldF9wcmlvcml0eV9pZD1wLmlkCldIRVJFIHQudGlja2V0X3N0YXRlX2lkIElOICgKCVNFTEVDVCBpZCBGUk9NIHRpY2tldF9zdGF0ZSBzIAoJV0hFUkUgcy50eXBlX2lkIElOICgKCQlTRUxFQ1QgaWQgRlJPTSB0aWNrZXRfc3RhdGVfdHlwZSAKCQlXSEVSRSBuYW1lIElOKCduZXcnLCAnb3BlbicsJ3BlbmRpbmdfcmVtaW5kZXInLCAncGVuZGluZ19hdXRvJykKCSkKKQpHUk9VUCBCWSB0LnRpY2tldF9wcmlvcml0eV9pZCwgcC5pZApPUkRFUiBCWSBwLm5hbWU7)',
            NewSQL => 'base64(U0VMRUNUIHAubmFtZSwgQ291bnQoKikgYXMgY291bnQgRlJPTSB0aWNrZXQgdCAKSk9JTiB0aWNrZXRfcHJpb3JpdHkgcCBPTiB0LnRpY2tldF9wcmlvcml0eV9pZD1wLmlkCldIRVJFIHQudGlja2V0X3N0YXRlX2lkIElOICgKCVNFTEVDVCBpZCBGUk9NIHRpY2tldF9zdGF0ZSBzIAoJV0hFUkUgcy50eXBlX2lkIElOICgKCQlTRUxFQ1QgaWQgRlJPTSB0aWNrZXRfc3RhdGVfdHlwZSAKCQlXSEVSRSBuYW1lIElOKCduZXcnLCAnb3BlbicsJ3BlbmRpbmcgcmVtaW5kZXInLCAncGVuZGluZyBhdXRvJykKCSkKKQpHUk9VUCBCWSB0LnRpY2tldF9wcmlvcml0eV9pZCwgcC5pZApPUkRFUiBCWSBwLm5hbWU7)'
        },
        {
            Name   => 'Number of open tickets by state',
            OldSQL => 'base64(U0VMRUNUIHMubmFtZSwgQ291bnQoKikgYXMgY291bnQgRlJPTSB0aWNrZXQgdCAKSk9JTiB0aWNrZXRfc3RhdGUgcyBPTiB0LnRpY2tldF9zdGF0ZV9pZD1zLmlkCldIRVJFIHQudGlja2V0X3N0YXRlX2lkIElOICgKCVNFTEVDVCBpZCBGUk9NIHRpY2tldF9zdGF0ZSB0cyAKCVdIRVJFIHRzLnR5cGVfaWQgSU4gKAoJCVNFTEVDVCBpZCBGUk9NIHRpY2tldF9zdGF0ZV90eXBlIAoJCVdIRVJFIG5hbWUgSU4oJ25ldycsICdvcGVuJywncGVuZGluZ19yZW1pbmRlcicsICdwZW5kaW5nX2F1dG8nKQoJKQopCkdST1VQIEJZIHQudGlja2V0X3N0YXRlX2lkLCBzLmlkOw==)',
            NewSQL => 'base64(U0VMRUNUIHMubmFtZSwgQ291bnQoKikgYXMgY291bnQgRlJPTSB0aWNrZXQgdCAKSk9JTiB0aWNrZXRfc3RhdGUgcyBPTiB0LnRpY2tldF9zdGF0ZV9pZD1zLmlkCldIRVJFIHQudGlja2V0X3N0YXRlX2lkIElOICgKCVNFTEVDVCBpZCBGUk9NIHRpY2tldF9zdGF0ZSB0cyAKCVdIRVJFIHRzLnR5cGVfaWQgSU4gKAoJCVNFTEVDVCBpZCBGUk9NIHRpY2tldF9zdGF0ZV90eXBlIAoJCVdIRVJFIG5hbWUgSU4oJ25ldycsICdvcGVuJywncGVuZGluZyByZW1pbmRlcicsICdwZW5kaW5nIGF1dG8nKQoJKQopCkdST1VQIEJZIHQudGlja2V0X3N0YXRlX2lkLCBzLmlkOw==)'
        },
        {
            Name   => 'Number of open tickets in teams by priority',
            OldSQL => 'base64(U0VMRUNUIHEubmFtZSBhcyBxdWV1ZV9uYW1lLCBwLm5hbWUgYXMgcHJpb3JpdHlfbmFtZSwgQ291bnQoKikgYXMgY291bnQgRlJPTSB0aWNrZXQgdCAKSk9JTiBxdWV1ZSBxIE9OIHQucXVldWVfaWQ9cS5pZApKT0lOIHRpY2tldF9wcmlvcml0eSBwIG9uIHQudGlja2V0X3ByaW9yaXR5X2lkPXAuaWQKV0hFUkUgdC50aWNrZXRfc3RhdGVfaWQgSU4gKAoJU0VMRUNUIGlkIEZST00gdGlja2V0X3N0YXRlIHRzIAoJV0hFUkUgdHMudHlwZV9pZCBJTiAoCgkJU0VMRUNUIGlkIEZST00gdGlja2V0X3N0YXRlX3R5cGUgCgkJV0hFUkUgbmFtZSBJTignbmV3JywgJ29wZW4nLCdwZW5kaW5nX3JlbWluZGVyJywgJ3BlbmRpbmdfYXV0bycpCgkpCikKR1JPVVAgQlkgcS5uYW1lLCBwLm5hbWUKT1JERVIgQlkgcS5uYW1lOwo=)',
            NewSQL => 'base64(U0VMRUNUIHEubmFtZSBhcyBxdWV1ZV9uYW1lLCBwLm5hbWUgYXMgcHJpb3JpdHlfbmFtZSwgQ291bnQoKikgYXMgY291bnQgRlJPTSB0aWNrZXQgdCAKSk9JTiBxdWV1ZSBxIE9OIHQucXVldWVfaWQ9cS5pZApKT0lOIHRpY2tldF9wcmlvcml0eSBwIG9uIHQudGlja2V0X3ByaW9yaXR5X2lkPXAuaWQKV0hFUkUgdC50aWNrZXRfc3RhdGVfaWQgSU4gKAoJU0VMRUNUIGlkIEZST00gdGlja2V0X3N0YXRlIHRzIAoJV0hFUkUgdHMudHlwZV9pZCBJTiAoCgkJU0VMRUNUIGlkIEZST00gdGlja2V0X3N0YXRlX3R5cGUgCgkJV0hFUkUgbmFtZSBJTignbmV3JywgJ29wZW4nLCdwZW5kaW5nIHJlbWluZGVyJywgJ3BlbmRpbmcgYXV0bycpCgkpCikKR1JPVVAgQlkgcS5uYW1lLCBwLm5hbWUKT1JERVIgQlkgcS5uYW1lOwo=)'
        },
        {
            Name   => 'Number of open tickets by team',
            OldSQL => 'base64(U0VMRUNUIHEubmFtZSBhcyBuYW1lLCBDb3VudCgqKSBhcyBjb3VudCBGUk9NIHRpY2tldCB0IApKT0lOIHF1ZXVlIHEgT04gdC5xdWV1ZV9pZD1xLmlkCldIRVJFIHQudGlja2V0X3N0YXRlX2lkIElOICgKCVNFTEVDVCBpZCBGUk9NIHRpY2tldF9zdGF0ZSB0cyAKCVdIRVJFIHRzLnR5cGVfaWQgSU4gKAoJCVNFTEVDVCBpZCBGUk9NIHRpY2tldF9zdGF0ZV90eXBlIAoJCVdIRVJFIG5hbWUgSU4oJ25ldycsICdvcGVuJywncGVuZGluZ19yZW1pbmRlcicsICdwZW5kaW5nX2F1dG8nKQoJKQopCkdST1VQIEJZIHEubmFtZQpPUkRFUiBCWSBxLm5hbWU7)',
            NewSQL => 'base64(U0VMRUNUIHEubmFtZSBhcyBuYW1lLCBDb3VudCgqKSBhcyBjb3VudCBGUk9NIHRpY2tldCB0IApKT0lOIHF1ZXVlIHEgT04gdC5xdWV1ZV9pZD1xLmlkCldIRVJFIHQudGlja2V0X3N0YXRlX2lkIElOICgKCVNFTEVDVCBpZCBGUk9NIHRpY2tldF9zdGF0ZSB0cyAKCVdIRVJFIHRzLnR5cGVfaWQgSU4gKAoJCVNFTEVDVCBpZCBGUk9NIHRpY2tldF9zdGF0ZV90eXBlIAoJCVdIRVJFIG5hbWUgSU4oJ25ldycsICdvcGVuJywncGVuZGluZyByZW1pbmRlcicsICdwZW5kaW5nIGF1dG8nKQoJKQopCkdST1VQIEJZIHEubmFtZQpPUkRFUiBCWSBxLm5hbWU7)'
        }
    );

    for my $UpdateReport (@UpdateReports) {

        my $ReportDefinitionID = $ReportingObject->ReportDefinitionLookup(
            Name => $UpdateReport->{Name}
        );

        if ($ReportDefinitionID) {
            my %ReportDefinitionData = $ReportingObject->ReportDefinitionGet(
                ID => $ReportDefinitionID
            );

            # only update if sql is not changed yet (sql from update script 1586)
            if (
                IsHashRefWithData($ReportDefinitionData{Config}) &&
                IsHashRefWithData($ReportDefinitionData{Config}->{DataSource}) &&
                IsHashRefWithData($ReportDefinitionData{Config}->{DataSource}->{SQL}) &&
                $ReportDefinitionData{Config}->{DataSource}->{SQL}->{any} &&
                $ReportDefinitionData{Config}->{DataSource}->{SQL}->{any} eq $UpdateReport->{OldSQL}
            ) {
                $ReportDefinitionData{Config}->{DataSource}->{SQL}->{any} = $UpdateReport->{NewSQL};
                my $Success = $ReportingObject->ReportDefinitionUpdate(
                    %ReportDefinitionData,
                    ID     => $ReportDefinitionID,
                    UserID => 1
                );

                if ( !$Success ) {
                    $LogObject->Log(
                        Priority => 'error',
                        Message  => "Could not update sql of report definition of '$UpdateReport->{Name}'."
                    );
                }
                else {
                    $LogObject->Log(
                        Priority => 'info',
                        Message  => "Updated successfully sql of report definition '$UpdateReport->{Name}'."
                    );
                }
            }
        }
    }

    return 1;
}

sub _MigrateCheckboxDFValues {
    my ( $Self, %Param ) = @_;

    my $DBObject = $Kernel::OM->Get('DB');

    my $Success = $DBObject->Do(
        SQL => "UPDATE dynamic_field_value SET value_text = value_int, value_int = NULL WHERE field_id IN (SELECT id FROM dynamic_field WHERE field_type = 'Multiselect') AND value_text is NULL AND value_int IS NOT NULL"
    );
    if ( !$Success ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to update values of migrated \"Checkbox\" dynamic fields!"
        );
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'info',
            Message  => "Update values of migrated \"Checkbox\" dynamic fields."
        );
    }

    return 1;
}

sub _AddNewPermissions {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Log');
    my $DBObject = $Kernel::OM->Get('DB');
    my $RoleObject = $Kernel::OM->Get('Role');

    my %RoleList           = reverse $RoleObject->RoleList();
    my %PermissionTypeList = reverse $RoleObject->PermissionTypeList();

    # add new permissions
    my @NewPermissions = (
        {
            Role   => 'Customer',
            Type   => 'Resource',
            Target => '/system/config/definitions',
            Value  => Kernel::System::Role::Permission::PERMISSION->{DENY}
        },
    );

    my $PermissionID;
    my $AllPermsOK = 1;
    foreach my $Permission (@NewPermissions) {
        my $RoleID = $RoleList{$Permission->{Role}};
        if (!$RoleID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find role "'.$Permission->{Role}.'"!'
            );
            next;
        }
        my $PermissionTypeID = $PermissionTypeList{$Permission->{Type}};
        if (!$PermissionTypeID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Unable to find permission type "'.$Permission->{Type}.'"!'
            );
            next;
        }

        $PermissionID = $RoleObject->PermissionAdd(
            RoleID     => $RoleID,
            TypeID     => $PermissionTypeID,
            Target     => $Permission->{Target},
            Value      => $Permission->{Value},
            IsRequired => 0,
            Comment    => '',
            UserID     => 1,
        );

        if (!$PermissionID) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Unable to add permission (role=$Permission->{Role}, type=$Permission->{Type}, target=$Permission->{Target}!"
            );
            $AllPermsOK = 0;
        }
    }


    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

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
