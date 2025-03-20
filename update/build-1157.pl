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

use Getopt::Std;
use File::Path qw(mkpath);
use Data::UUID;

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);
use Kernel::System::EmailParser;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1157',
    },
);
my $LogObject = $Kernel::OM->Get('Log');

use vars qw(%INC);

sub _AddPrefixToNotificationFilterData {
    my ( $Self, %Param ) = @_;

    $Self->{NotificationEventObject} = $Kernel::OM->Get('NotificationEvent');

    # get all current notifications
    my %NotificationList = $Self->{NotificationEventObject}->NotificationList(
        Type    => 'Ticket',
        Details => 1,
        All     => 1,
    );

    # update existing notifications (LockID)
    NOTIFICATION:
    for my $Key ( keys %NotificationList ) {
        next NOTIFICATION if !IsHashRefWithData( $NotificationList{$Key}->{Data} );
        next NOTIFICATION if !defined $NotificationList{$Key}->{Data}->{LockID};

        # create new data hash
        my %NewDataHash = ();
        for my $DataKey ( keys %{$NotificationList{$Key}->{Data}} ) {
            if ( $DataKey ne 'LockID' ) {
                $NewDataHash{$DataKey} = $NotificationList{$Key}->{Data}->{$DataKey};
            }
            else {
                $NewDataHash{'Ticket::LockID'} = $NotificationList{$Key}->{Data}->{$DataKey};
            }
        }

        $NotificationList{$Key}->{Data} = \%NewDataHash;

        my $Ok = $Self->{NotificationEventObject}->NotificationUpdate(
            %{ $NotificationList{$Key} },
            UserID  => 1,
        );
    }

    return 1;
}

# add prefix to notification filter data
_AddPrefixToNotificationFilterData();

exit 0;

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
