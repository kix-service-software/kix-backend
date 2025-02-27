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
        LogPrefix => 'framework_update-to-build-1231',
    },
);

use vars qw(%INC);

# fix wrong recipient name in existing notifications
_FixRecipientInExistingNotifications();

sub _FixRecipientInExistingNotifications {
    my ( $Self, %Param ) = @_;

    $Self->{NotificationEventObject} = $Kernel::OM->Get('NotificationEvent');

    # get all current notifications
    my %NotificationList = $Self->{NotificationEventObject}->NotificationList(
        Type    => 'Ticket',
        Details => 1,
        All     => 1,
    );

    # update existing notifications (missing s on some recipients)
    NOTIFICATION:
    for my $Key ( keys %NotificationList ) {
        next NOTIFICATION if !IsHashRefWithData( $NotificationList{$Key}->{Data} );
        next NOTIFICATION if !IsArrayRefWithData( $NotificationList{$Key}->{Data}->{Recipients} );

        # collect fixed recipient
        my @FixedRecipients = ();
        my $UpdateNeeded = 0;
        for my $Recipient ( @{ $NotificationList{$Key}->{Data}->{Recipients} } ) {
            if ( $Recipient =~ m/^Agent(Write|Read)Permission$/ ) {
                $UpdateNeeded = 1;
                $Recipient .= 's';
            }
            push(@FixedRecipients, $Recipient);
        }

        if ($UpdateNeeded) {
            $NotificationList{$Key}->{Data}->{Recipients} = \@FixedRecipients;

            my $Ok = $Self->{NotificationEventObject}->NotificationUpdate(
                %{ $NotificationList{$Key} },
                UserID  => 1,
            );
        }
    }

    return 1;
}

exit 0;

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
