#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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
use lib dirname($Bin) . '/plugins';
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-2240',
    },
);

use vars qw(%INC);

# migrate OutOfOffice prefs to users table
_MigrateOOOPrefs();

# update chart report definition for mysql
_UpdateChartReports();

sub _MigrateOOOPrefs {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Log');
    my $DBObject = $Kernel::OM->Get('DB');

    $DBObject->Prepare(
        SQL => "SELECT user_id, preferences_key, preferences_value FROM user_preferences WHERE "
             . "preferences_key IN ('OutOfOfficeStart', 'OutOfOfficeEnd', 'OutOfOfficeSubstitute') AND "
             . "preferences_value IS NOT NULL OR preferences_value != ''",
    );

    my $Data = $DBObject->FetchAllArrayRef(
        Columns => [ 'UserID', 'Key', 'Value' ]
    );

    ROW:
    foreach my $Row ( @{$Data || []} ) {
        next if !$Row->{Value};

        my $Success = $Kernel::OM->Get('User')->SetPreferences(
            Key    => $Row->{Key},
            Value  => $Row->{Value},
            UserID => $Row->{UserID},
        );
        if ( !$Success ) {
            $Kernel::OM->Get('Log')->Log(
                Priority  => 'error',
                Message   => "Could not set preference \"$Row->{Key}\" ($Row->{Value}) for user $Row->{UserID}!",
            );
        }
    }

    $DBObject->Prepare(
        SQL => "DELETE FROM user_preferences WHERE preferences_key IN ('OutOfOfficeStart', 'OutOfOfficeEnd', 'OutOfOfficeSubstitute')",
    );

    return 1;
}

sub _UpdateChartReports {
    my ( $Self, %Param ) = @_;

    my @Definitions = (
        {
            Name      => Kernel::Language::Translatable('Number of tickets created within the last 7 days'),
            OldConfig => {
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
            },
            NewConfig => {
                'DataSource' => {
                    'SQL' => {
                        'postgresql' => 'base64(U0VMRUNUIGRhdGUoY3JlYXRlX3RpbWUpIGFzIGRheSwgQ291bnQoKikgYXMgY291bnQgRlJPTSB0aWNrZXQKV0hFUkUgKGRhdGUoY3JlYXRlX3RpbWUpIEJFVFdFRU4gZGF0ZSgoTk9XKCkgLSBJTlRFUlZBTCAnNyBEQVknKSkgQU5EIGRhdGUoTk9XKCkpKQpHUk9VUCBCWSBkYXkKb3JkZXIgYnkgZGF5IEFTQzs=)',
                        'mysql'      => 'base64(U0VMRUNUIGRhdGUoY3JlYXRlX3RpbWUpIGFzIGRheSwgQ291bnQoKikgYXMgY291bnQgRlJPTSB0aWNrZXQKV0hFUkUgKGRhdGUoY3JlYXRlX3RpbWUpIEJFVFdFRU4gVElNRVNUQU1QKCBEQVRFX0ZPUk1BVChDVVJSRU5UX0RBVEUgLSBJTlRFUlZBTCA3IERBWSAsJyVZLSVtLSVkJykpIEFORCBjdXJyZW50X3RpbWUpCkdST1VQIEJZIGRheQpvcmRlciBieSBkYXkgQVNDOw==)'
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

    for my $Definition ( @Definitions ) {
        my $ReportDefinitionID = $Kernel::OM->Get('Reporting')->ReportDefinitionLookup(
            Name => $Definition->{Name},
        );

        if ( $ReportDefinitionID ) {
             my %ReportDefinitionData = $Kernel::OM->Get('Reporting')->ReportDefinitionGet(
                ID => $ReportDefinitionID,
            );

            if (
                !DataIsDifferent(
                    Data1 => $ReportDefinitionData{Config},
                    Data2 => $Definition->{OldConfig},
                )
            ) {

                my $Success = $Kernel::OM->Get('Reporting')->ReportDefinitionUpdate(
                    %ReportDefinitionData,
                    ID     => $ReportDefinitionID,
                    Config => $Definition->{NewConfig},
                    UserID => 1,
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
