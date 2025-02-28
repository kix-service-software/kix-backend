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
        LogPrefix => 'framework_update-to-build-1283',
    },
);

use vars qw(%INC);

# remove some unnecessary recipients from "Agent - Ticket Move Notification"
_RemoveSomeRecipientsForAgentMoveNotification();

# add an event to "Agent - Responsible Assignment" notification
_AddEventToAgentResponsibleNotification();

sub _RemoveSomeRecipientsForAgentMoveNotification {
    my ( $Self, %Param ) = @_;

    $Self->{NotificationEventObject} = $Kernel::OM->Get('NotificationEvent');

    # get notification
    my %Notification = $Self->{NotificationEventObject}->NotificationGet(
        Name => 'Agent - Ticket Move Notification',
    );

    # update existing notification
    if (
        IsHashRefWithData( \%Notification ) &&
        IsHashRefWithData( $Notification{Data} ) &&
        IsArrayRefWithData( $Notification{Data}->{Recipients} )
    ) {

        # collect filtered recipient
        my @NewRecipients = ();
        my $UpdateNeeded = 0;
        for my $Recipient ( @{ $Notification{Data}->{Recipients} } ) {
            if ( $Recipient =~ m/^Agent(Write|Read)Permissions$/ ) {
                $UpdateNeeded = 1;
            } else {
                push(@NewRecipients, $Recipient);
            }
        }

        if ($UpdateNeeded) {
            $Notification{Data}->{Recipients} = \@NewRecipients;

            my $Ok = $Self->{NotificationEventObject}->NotificationUpdate(
                %Notification,
                UserID  => 1,
            );
        }
    }

    return 1;
}

sub _AddEventToAgentResponsibleNotification {
    my ( $Self, %Param ) = @_;

    $Self->{NotificationEventObject} = $Kernel::OM->Get('NotificationEvent');

    # get notification
    my %Notification = $Self->{NotificationEventObject}->NotificationGet(
        Name => 'Agent - Responsible Assignment',
    );

    # update existing notification
    if (
        IsHashRefWithData( \%Notification ) &&
        IsHashRefWithData( $Notification{Data} ) &&
        IsArrayRefWithData( $Notification{Data}->{Events} )
    ) {

        # add event
        if ( !grep( /^TicketResponsibleUpdate$/, @{ $Notification{Data}->{Events} } ) ) {
            push( @{ $Notification{Data}->{Events} }, 'TicketResponsibleUpdate' );
            my $Ok = $Self->{NotificationEventObject}->NotificationUpdate(
                %Notification,
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
