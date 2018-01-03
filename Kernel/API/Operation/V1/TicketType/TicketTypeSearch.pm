# --
# Kernel/API/Operation/TicketType/TicketTypeCreate.pm - API TicketType Create operation backend
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

package Kernel::API::Operation::V1::TicketType::TicketTypeSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::TicketType::TicketTypeGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TicketType::TicketTypeSearch - API TicketType Search Operation backend

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

perform TicketTypeSearch Operation. This will return a TicketType ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data    => {
            TypeID => [ 1, 2, 3, 4 ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # get tickettype list 
    my %TicketTypeList = $Kernel::OM->Get('Kernel::System::Type')->TypeList(
        Valid => 1,
    );

    # get already prepared tickettype data from TicketTypeGet operation
    if ( IsHashRefWithData(\%TicketTypeList) ) {
        my $TicketTypeGetResult = $Self->ExecOperation(
            OperationType => 'V1::TicketType::TicketTypeGet',
            Data      => {
                TypeID => join(',', sort keys %TicketTypeList),
            }
        );
 
        if ( !IsHashRefWithData($TicketTypeGetResult) || !$TicketTypeGetResult->{Success} ) {
            return $TicketTypeGetResult;
        }

        my @ResultList = IsArrayRefWithData($TicketTypeGetResult->{Data}->{TicketType}) ? @{$TicketTypeGetResult->{Data}->{TicketType}} : ( $TicketTypeGetResult->{Data}->{TicketType} );

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                TicketType => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        TicketType => [],
    );
}

1;
