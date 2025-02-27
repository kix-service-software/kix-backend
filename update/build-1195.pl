#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
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
        LogPrefix => 'framework_update-to-build-1195',
    },
);

use vars qw(%INC);

sub _MigratePriorities {
    my ( $Self, %Param ) = @_;

    $Self->{PriorityObject} = $Kernel::OM->Get('Priority');

    $Self->{PriorityObject}->PriorityUpdate(
        PriorityID     => 1,
        Name           => '5 very low',
        ValidID        => 1,
        UserID         => 1,
    );

    $Self->{PriorityObject}->PriorityUpdate(
        PriorityID     => 2,
        Name           => '4 low',
        ValidID        => 1,
        UserID         => 1,
    );

    $Self->{PriorityObject}->PriorityUpdate(
        PriorityID     => 4,
        Name           => '2 high',
        ValidID        => 1,
        UserID         => 1,
    );

    $Self->{PriorityObject}->PriorityUpdate(
        PriorityID     => 5,
        Name           => '1 very high',
        ValidID        => 1,
        UserID         => 1,
    );

    return 1;
}

sub _AddRecipientSubjectToNotifications {
    my ( $Self, %Param ) = @_;

    $Self->{NotificationEventObject} = $Kernel::OM->Get('NotificationEvent');

    # get all current notifications
    my %NotificationList = $Self->{NotificationEventObject}->NotificationList(
        Type    => 'Ticket',
        Details => 1,
        All     => 1,
    );

    # update existing notifications (RecipientSubject)
    NOTIFICATION:
    for my $Key ( keys %NotificationList ) {
        next NOTIFICATION if !IsHashRefWithData( $NotificationList{$Key}->{Data} );
        next NOTIFICATION if !$NotificationList{$Key}->{Data}->{RecipientSubject} == 1;
        next NOTIFICATION if $Key > 11;

        # create new data hash
        my %NewDataHash = ();
        for my $DataKey ( keys %{$NotificationList{$Key}->{Data}} ) {
            $NotificationList{$Key}->{Data}->{'RecipientSubject'} = [ 1 ];
        }

        $Self->{NotificationEventObject}->NotificationUpdate(
            %{ $NotificationList{$Key} },
            UserID  => 1,
        );
    }

    return 1;
}
# change existing mobile processing dynamic fields
_MigratePriorities();
_AddRecipientSubjectToNotifications();

exit 0;

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
