# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::TicketFlag;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::TicketFlag - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        'TicketFlag.Seen' => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE']
        },
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # get requested flag
    my $Flag = $Param{Search}->{Field};
    $Flag =~ s/^TicketFlag\.//;

    # check for needed joins
    my $TableAlias = 'tf_left' . ( $Param{Flags}->{JoinMap}->{ 'TicketFlag_' . $Flag } // '' );
    my @SQLJoin = ();
    if ( !defined( $Param{Flags}->{JoinMap}->{ 'TicketFlag_' . $Flag } ) ) {
        my $Count = $Param{Flags}->{TicketFlagJoinCounter}++;
        $TableAlias .= $Count;
        push( @SQLJoin, "LEFT OUTER JOIN ticket_flag $TableAlias ON $TableAlias.ticket_id = st.id AND $TableAlias.ticket_key = \'$Flag\' AND tf_left0.create_by = $Param{UserID}" );

        $Param{Flags}->{JoinMap}->{ 'TicketFlag_' . $Flag } = $Count;
    }

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator   => $Param{Search}->{Operator},
        Column     => "$TableAlias.ticket_value",
        Value      => $Param{Search}->{Value},
        NULLValue  => 1,
        Silent     => $Param{Silent}
    );
    return if ( !$Condition );

    # return search def
    return {
        Join  => \@SQLJoin,
        Where => [ $Condition ]
    };
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
