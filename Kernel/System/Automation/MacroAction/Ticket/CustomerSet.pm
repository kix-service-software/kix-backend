# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::CustomerSet;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::CustomerSet - A module to set a new ticket customer

=head1 SYNOPSIS

All CustomerSet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

    Run Data

    my $CustomerSetResult = $CustomerSetActionObject->Run(
        UserID                   => 123,
        Ticket                   => \%Ticket,   # required
        ProcessEntityID          => 'P123',
        ActivityEntityID         => 'A123',
        TransitionEntityID       => 'T123',
        TransitionActionEntityID => 'TA123',
        Config                   => {
            CustomerID     => 'client123',
            # or
            ContactID => 'client-user-123',

            #OR (Framework wording)
            No             => 'client123',
            # or
            User           => 'client-user-123',

            UserID => 123,                      # optional, to override the UserID from the logged user
        }
    );
    Ticket contains the result of TicketGet including DynamicFields
    Config is the Config Hash stored in a Process::TransitionAction's  Config key
    Returns:

    $CustomerSetResult = 1; # 0

    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # define a common message to output in case of any error
    my $CommonMessage = "Process: $Param{ProcessEntityID} Activity: $Param{ActivityEntityID}"
        . " Transition: $Param{TransitionEntityID}"
        . " TransitionAction: $Param{TransitionActionEntityID} - ";

    # check for missing or wrong params
    my $Success = $Self->_CheckParams(
        %Param,
        CommonMessage => $CommonMessage,
    );
    return if !$Success;

    # override UserID if specified as a parameter in the TA config
    $Param{UserID} = $Self->_OverrideUserID(%Param);

    # use ticket attributes if needed
    $Self->_ReplaceTicketAttributes(%Param);

    if (
        !$Param{Config}->{CustomerID}
        && !$Param{Config}->{No}
        && !$Param{Config}->{ContactID}
        && !$Param{Config}->{User}
        )
    {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => $CommonMessage . "No CustomerID/No or ContactID/User configured!",
        );
        return;
    }

    if ( !$Param{Config}->{CustomerID} && $Param{Config}->{No} ) {
        $Param{Config}->{CustomerID} = $Param{Config}->{No};
    }
    if ( !$Param{Config}->{ContactID} && $Param{Config}->{User} ) {
        $Param{Config}->{ContactID} = $Param{Config}->{User};
    }

    if (
        defined $Param{Config}->{CustomerID}
        &&
        (
            !defined $Param{Ticket}->{CustomerID}
            || $Param{Config}->{CustomerID} ne $Param{Ticket}->{CustomerID}
        )
        )
    {
        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        my $Success = $TicketObject->CustomerSet(
            TicketID => $Param{Ticket}->{TicketID},
            No       => $Param{Config}->{CustomerID},
            UserID   => $Param{UserID},
        );

        if ( !$Success ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => $CommonMessage
                    . 'Ticket CustomerID: '
                    . $Param{Config}->{CustomerID}
                    . ' could not be updated for Ticket: '
                    . $Param{Ticket}->{TicketID} . '!',
            );
            return;
        }
    }

    if (
        defined $Param{Config}->{ContactID}
        &&
        (
            !defined $Param{Ticket}->{ContactID}
            || $Param{Config}->{ContactID} ne $Param{Ticket}->{ContactID}
        )
        )
    {
        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        my $Success = $TicketObject->CustomerSet(
            TicketID => $Param{Ticket}->{TicketID},
            User     => $Param{Config}->{ContactID},
            UserID   => $Param{UserID},
        );

        if ( !$Success ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => $CommonMessage
                    . 'Ticket ContactID: '
                    . $Param{Config}->{ContactID}
                    . ' could not be updated for Ticket: '
                    . $Param{Ticket}->{TicketID} . '!',
            );
            return;
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
