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
use lib dirname($Bin).'/';
use lib dirname($Bin).'/Kernel/cpan-lib';

use Getopt::Std;
use File::Path qw(mkpath);

use Kernel::System::ObjectManager;

use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1143',
    },
);

use vars qw(%INC);

# adjust notifaction for new ticket
_ReconfigureNotificationCreateArticle();

exit 0;


sub _ReconfigureNotificationCreateArticle {

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    my %Notification = $Kernel::OM->Get('NotificationEvent')->NotificationGet(
        Name => 'Customer - New Ticket Receipt'
    );

    if( %Notification ) {

        # prevent article create for notification
        if ( IsArrayRefWithData( $Notification{Data}->{CreateArticle} ) ) {
            $Notification{Data}->{CreateArticle} = ['0'];
            $Kernel::OM->Get('NotificationEvent')->NotificationUpdate(
                ID => $Notification{ID},
                %Notification,
                UserID => 1
            )
        }
    }

    return 1;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
