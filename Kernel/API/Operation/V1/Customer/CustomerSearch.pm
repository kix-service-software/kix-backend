# --
# Kernel/API/Operation/Customer/CustomerSearch.pm - API Customer Search operation backend
# based upon Kernel/API/Operation/Ticket/TicketSearch.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Customer::CustomerSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Customer::CustomerSearch - API Customer Search Operation backend

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

perform CustomerSearch Operation. This will return a Customer list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            Customer => [
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

    # perform Customer search
    my %CustomerList = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyList(
        Valid  => 0,
    );

    if (IsHashRefWithData(\%CustomerList)) {
        
        # get already prepared Customer data from CustomerGet operation
        my $CustomerGetResult = $Self->ExecOperation(
            OperationType => 'V1::Customer::CustomerGet',
            Data          => {
                CustomerID => join(',', sort keys %CustomerList),
            }
        );
        if ( !IsHashRefWithData($CustomerGetResult) || !$CustomerGetResult->{Success} ) {
            return $CustomerGetResult;
        }

        my @ResultList = IsArrayRefWithData($CustomerGetResult->{Data}->{Customer}) ? @{$CustomerGetResult->{Data}->{Customer}} : ( $CustomerGetResult->{Data}->{Customer} );
        
        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Customer => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Customer => [],
    );
}

1;
