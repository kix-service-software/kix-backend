# --
# Kernel/API/Operation/TicketState/TicketStateCreate.pm - API TicketState Create operation backend
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::TicketState::TicketStateSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::TicketState::TicketStateGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::TicketState::TicketStateSearch - API TicketState Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item Run()

perform TicketStateSearch Operation. This will return a TicketState ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data    => {
            StateID => [ 1, 2, 3, 4 ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform TicketState search
    my %TicketStateList = $Kernel::OM->Get('Kernel::System::State')->StateList(
        UserID => $Self->{Authorization}->{UserID},
        Valid => 1,
    );

	# get already prepared ticketstate data from TicketStateGet operation
    if ( IsHashRefWithData(\%TicketStateList) ) {  	
        my $TicketStateGetResult = $Self->ExecOperation(
            OperationType => 'V1::TicketState::TicketStateGet',
            Data      => {
                StateID => join(',', sort keys %TicketStateList),
            }
        );    

        if ( !IsHashRefWithData($TicketStateGetResult) || !$TicketStateGetResult->{Success} ) {
            return $TicketStateGetResult;
        }

        my @TicketStateDataList = IsArrayRefWithData($TicketStateGetResult->{Data}->{TicketState}) ? @{$TicketStateGetResult->{Data}->{TicketState}} : ( $TicketStateGetResult->{Data}->{TicketState} );

        if ( IsArrayRefWithData(\@TicketStateDataList) ) {
            return $Self->_Success(
                TicketState => \@TicketStateDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        TicketState => [],
    );
}

1;