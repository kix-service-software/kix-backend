# --
# Kernel/API/Operation/Customer/CustomerUpdate.pm - API Customer Create operation backend
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

package Kernel::API::Operation::V1::Customer::CustomerUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Customer::V1::CustomerUpdate - API Customer Update Operation backend

=head1 SYNOPSIS

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
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::Customer::CustomerUpdate');

    return $Self;
}

=item Run()

perform CustomerUpdate Operation. This will return the updated CustomerID.

    my $Result = $OperationObject->Run(
        Data => {
            CustomerID => '...'     # required
            Customer => {
                ...                 # attributes (required and optional) depend on Map config 
                ...
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            CustomerID  => '',                      # CustomerID 
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webservice
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
        Parameters => {
            'CustomerID' => {
                Required => 1
            },
            'Customer' => {
                Type     => 'HASH',
                Required => 1
            },
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # isolate and trim Customer parameter
    my $Customer = $Self->_Trim(
        Data => $Param{Data}->{Customer}
    );

    # check Customer exists
    my %CustomerData = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
        CustomerID => $Param{Data}->{CustomerID},
    );
    if ( !%CustomerData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Can not update Customer. No Customer with ID '$Param{Data}->{CustomerID}' found.",
        );
    }

    # check if backend (Source) is writeable
    my %SourceList = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanySourceList(
        ReadOnly => 0
    );    
    if ( !$SourceList{$CustomerData{Source}} ) {
        return $Self->_Error(
            Code    => 'Forbidden',
            Message => 'Can not update Customer. Corresponding backend is not writable or does not exist.',
        );        
    }

    # check if CustomerCompanyName already exists
    if ( IsStringWithData($Customer->{CustomerCompanyName}) ) {
        my %CustomerList = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyList(
            Search => $Customer->{CustomerCompanyName},
        );
        if ( %CustomerList && (scalar(keys %CustomerList) > 1 || !$CustomerList{$CustomerData{CustomerID}})) {        
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => 'Can not update Customer. Another Customer with same name already exists.',
            );
        }
    }
    
    # update Customer
    my $Success = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyUpdate(
        %CustomerData,
        %{$Customer},
        CustomerCompanyID => $Param{Data}->{CustomerID},
        UserID            => $Self->{Authorization}->{UserID},
    );    
    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update Customer, please contact the system administrator',
        );
    }
    
    return $Self->_Success(
        CustomerID => $Customer->{CustomerID} || $CustomerData{CustomerID},
    );   
}