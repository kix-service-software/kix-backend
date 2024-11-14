# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::Common;

use strict;
use warnings;

use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Common);

our @ObjectDependencies = (
    'Ticket',
    'Log',
);

=item _CheckParams()

Check if all required parameters are given.

Example:
    my $Result = $Object->_CheckParams(
        TicketID => 123,
        Config   => {
            ...
        }
    );

=cut

sub _CheckParams {
    my ( $Self, %Param ) = @_;

    return if !$Self->SUPER::_CheckParams(%Param);

    return 1 if ($Param{NoTicketIDCheckNeeded});

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "_CheckParams: Need TicketID!",
        );
        return;
    }

    my $TicketNumber = $Kernel::OM->Get('Ticket')->TicketNumberLookup(
        TicketID => $Param{TicketID},
        UserID   => 1,
        Silent   => 1
    );

    if (!$TicketNumber) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "_CheckParams: No ticket found with ID '$Param{TicketID}'!",
        );
        return;
    }

    return 1;
}

sub _ReplaceValuePlaceholder {
    my ( $Self, %Param ) = @_;

    %Param = $Self->_PrepareEventData(%Param);

    return $Self->SUPER::_ReplaceValuePlaceholder(%Param);
}

sub _PrepareEventData {
    my ( $Self, %Param ) = @_;

    $Param{EventData} ||= IsHashRefWithData($Self->{EventData}) ? $Self->{EventData} : {};
    if ( !$Param{EventData}->{TicketID} ) {
        $Param{EventData}->{TicketID}  = $Self->{RootObjectID} || $Param{TicketID};
    }
    if ( !$Param{EventData}->{ArticleID} ) {
        $Param{EventData}->{ArticleID} = $Param{AdditionalData}->{ArticleID} ? $Param{AdditionalData}->{ArticleID}->[0] : q{};
    }

    return %Param;
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
