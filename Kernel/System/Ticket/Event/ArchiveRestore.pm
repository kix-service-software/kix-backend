# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::ArchiveRestore;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
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
    for (qw(Data Event Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # handle only events with given TicketID
    return 1 if ( !$Param{Data}->{TicketID} );

    # return if no archive feature is enabled
    return 1 if !$Kernel::OM->Get('Config')->Get('Ticket::ArchiveSystem');

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # get ticket
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{Data}->{TicketID},
        UserID        => 1,
        DynamicFields => 0,
    );
    return if !%Ticket;

    # do not restore until ticket is closed, removed or merged
    # (restore just open tickets)
    return 1 if $Ticket{StateType} eq 'closed';
    return 1 if $Ticket{StateType} eq 'removed';
    return 1 if $Ticket{StateType} eq 'merged';

    # restore ticket from archive
    return if !$TicketObject->TicketArchiveFlagSet(
        TicketID    => $Param{Data}->{TicketID},
        UserID      => 1,
        ArchiveFlag => 'n',
    );

    return 1;
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
