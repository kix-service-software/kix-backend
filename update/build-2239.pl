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
        LogPrefix => 'framework_update-to-build-2239',
    },
);

use vars qw(%INC);

# migrate OutOfOffice prefs to users table
_MigrateOOOPrefs();

sub _MigrateOOOPrefs {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Log');
    my $DBObject = $Kernel::OM->Get('DB');

    $DBObject->Prepare(
        SQL => "SELECT user_id, preferences_key, preferences_value FROM user_preferences WHERE preferences_key IN ('OutOfOfficeStart', 'OutOfOfficeEnd', 'OutOfOfficeSubstitute')",
    );

    my $Data = $DBObject->FetchAllArrayRef(
        Columns => [ 'UserID', 'Key', 'Value' ]
    );

    foreach my $Row ( @{$Data || []} ) {
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

exit 0;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
