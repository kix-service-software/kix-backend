# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::ResponsibleAutoSetPerTickettype;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Log',
    'Ticket',
    'User',
);

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create needed objects
    $Self->{ConfigObject}        = $Kernel::OM->Get('Config');
    $Self->{LogObject}           = $Kernel::OM->Get('Log');
    $Self->{TicketObject}        = $Kernel::OM->Get('Ticket');
    $Self->{UserObject}          = $Kernel::OM->Get('User');

    return $Self;
}

=item Run()

Run - contains the actions performed by this event handler.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Event Config UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    if ( !$Param{Data}->{TicketID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Need TicketID!"
        );
        return;
    }

    my $SetMode = $Self->{ConfigObject}->Get('Ticket::ResponsibleAutoSetPerTickettype');

    if ( $Self->{ConfigObject}->Get('Ticket::Responsible') && $SetMode ) {

        my %Ticket = $Self->{TicketObject}->TicketGet(
            TicketID => $Param{Data}->{TicketID},
            UserID   => $Param{UserID},
        );

        my $UserLogin     = $Param{Config}->{ 'TicketType:::' . $Ticket{Type} } || "";
        my $UserID        = 0;
        my @ResultUserIDs = qw{};

        if ($UserLogin) {
            my %List = $Self->{UserObject}->UserSearch(
                UserLogin => $UserLogin,
                Limit     => 1,
                Valid     => 1,
            );
            @ResultUserIDs = keys(%List);
        }

        if ( $SetMode eq 'ForceTTResponsible' ) {
            $UserID = $ResultUserIDs[0];
        }
        elsif ( ( $Ticket{ResponsibleID} == 1 ) && $SetMode eq 'TTResponsible' ) {
            $UserID = $ResultUserIDs[0];
        }
        elsif ( ( $Ticket{ResponsibleID} == 1 ) && $SetMode eq 'Owner' ) {
            $UserID = $Param{UserID};
        }

        if ($UserID) {
            $Self->{TicketObject}->TicketResponsibleSet(
                TicketID           => $Param{Data}->{TicketID},
                NewUserID          => $UserID,
                SendNoNotification => 1,
                UserID             => $Param{UserID} || 1,
            );
        }

    }

    return 1;
}

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
