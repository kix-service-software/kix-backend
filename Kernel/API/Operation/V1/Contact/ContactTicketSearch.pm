# --
# Kernel/API/Operation/Contact/ContactSearch.pm - API Contact Search operation backend
# based upon Kernel/API/Operation/Ticket/TicketSearch.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Contact::ContactTicketSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Contact::ContactTicketSearch - API Contact Ticket Search Operation backend

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

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'ContactID' => {
            Required => 1
        }                
    }
}

=item Run()

perform ContactTicketSearch Operation. This will return a Contact list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            Ticket => [
                {
                },
                {                    
                }
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform ticket search
    my @TicketList = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
        Search => {
            AND => [
                {
                    Field    => 'ContactID',
                    Operator => 'EQ',
                    Value    => $Param{Data}->{ContactID},
                }
            ]
        },
        UserID => $Self->{Authorization}->{UserID},
        Result => 'ARRAY',
    );

    if (IsArrayRefWithData(\@TicketList)) {
        
        # get already prepared Ticket data from TicketGet operation
        my $TicketGetResult = $Self->ExecOperation(
            OperationType => 'V1::Ticket::TicketGet',
            Data          => {
                TicketID => [ sort @TicketList ],
            }
        );
        if ( !IsHashRefWithData($TicketGetResult) || !$TicketGetResult->{Success} ) {
            return $TicketGetResult;
        }

        my @ResultList = IsArrayRefWithData($TicketGetResult->{Data}->{Ticket}) ? @{$TicketGetResult->{Data}->{Ticket}} : ( $TicketGetResult->{Data}->{Ticket} );
        
        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Ticket => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Ticket => [],
    );
}

1;
