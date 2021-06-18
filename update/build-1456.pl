#!/usr/bin/perl
# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
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
        LogPrefix => 'framework_update-to-build-1456',
    },
);

use vars qw(%INC);

_UpdateMyQueuePreference();

exit 0;

sub _UpdateMyQueuePreference {

    # get objects
    my $DBObject   = $Kernel::OM->Get('DB');
    my $UserObject = $Kernel::OM->Get('User');

    return if !$DBObject->Prepare(
        SQL => "SELECT user_id, preferences_value FROM user_preferences WHERE preferences_key = 'MyQueues'",
    );
    my $Rows = $DBObject->FetchAllArrayRef(
        Columns => [ 'UserID', 'Value' ]
    );

    my $UpdateCount = 0;
    foreach my $Row ( @{$Rows || []} ) {
        next if !IsHashRefWithData($Row);
        next if $Row->{Value} !~ /,/;

        my @Value = split(/,/, $Row->{Value});

        # update preference
        my $Success = $UserObject->SetPreferences(
            Key    => 'MyQueues',
            Value  => \@Value,
            UserID => $Row->{UserID}
        );
        if ( !$Success ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to update 'MyQueues' preference for user $Row->{UserID}!"
            );
            next;
        }
        $UpdateCount++;
    }

    $Kernel::OM->Get('Log')->Log(
        Priority => 'info',
        Message  => "Updated $UpdateCount 'MyQueues' user preferences!"
    );

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
