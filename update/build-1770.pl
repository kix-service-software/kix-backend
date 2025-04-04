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
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1770',
    },
);

use vars qw(%INC);

# fix subject placeholder in existing notification (Agent - New Note Notification)
_FixSubjectInExistingNotification();

sub _FixSubjectInExistingNotification {
    my ( $Self, %Param ) = @_;

    # get notification
    my %Notification = $Kernel::OM->Get('NotificationEvent')->NotificationGet(
        Name => 'Agent - New Note Notification'
    );

    # check that notification exists and subject is not changed
    if(
        %Notification
        && IsHashRefWithData( $Notification{Message} )
        && IsHashRefWithData( $Notification{Message}->{de} )
        && IsHashRefWithData( $Notification{Message}->{en} )
        && $Notification{Message}->{de}->{Subject} eq 'Aktualisierung: <KIX_CUSTOMER_Subject_64>'
        && $Notification{Message}->{en}->{Subject} eq 'Update: <KIX_AGENT_Subject[64]>'
    ) {
        # fix subjects
        $Notification{Message}->{de}->{Subject} = 'Aktualisierung: <KIX_LAST_Subject_64>';
        $Notification{Message}->{en}->{Subject} = 'Update: <KIX_LAST_Subject_64>';

        # update notification
        $Kernel::OM->Get('NotificationEvent')->NotificationUpdate(
            %Notification,
            UserID => 1,
        );
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
