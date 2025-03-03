# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::TicketAttachmentCountUpdate;

use strict;
use warnings;

our @ObjectDependencies = (
    'Log',
    'Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Data Event Config)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    for my $Needed (qw(TicketID)) {
        if ( !$Param{Data}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in Data!"
            );
            return;
        }
    }

    if ($Param{Event} eq 'ArticleMove') {
        if ( !$Param{Data}->{OldTicketID} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need OldTicketID in Data!"
            );
            return;
        }

        # update old ticket
        my $Success = $Kernel::OM->Get('Ticket')->TicketAttachmentCountUpdate(
            TicketID => $Param{Data}->{OldTicketID}
        );
        if (!$Success) {
            return;
        }
    }

    return $Kernel::OM->Get('Ticket')->TicketAttachmentCountUpdate(
        TicketID => $Param{Data}->{TicketID}
    );
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
