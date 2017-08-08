# --
# Kernel/GenericInterface/Operation/Customer/CustomerCreate.pm - GenericInterface Customer Create operation backend
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

package Kernel::API::Operation::V1::Customer::CustomerCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
    Kernel::API::Operation::V1::Customer::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Customer::CustomerCreate - GenericInterface Customer Create Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!"
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::CustomerCreate');

    return $Self;
}

=item Run()

perform CustomerCreate Operation. This will return the created CompanyID.

    my $Result = $OperationObject->Run(
        Data => {
            UserLogin         => 'some agent login',                            # UserLogin or CustomerLogin or SessionID is
                                                                                #   required
            CustomerLogin => 'some customer login',
            SessionID         => 123,

            Password  => 'some password',                                       # if UserLogin or CustomerLogin is sent then
                                                                                #   Password is required

            Customer => {
                CustomerID             => '...'                                 # required                
                CustomerName    => '...'                                 # required
                CustomerStreet  => '...'                                 # optional
                CustomerZIP     => '...'                                 # optional
                CustomerCity    => '...'                                 # optional
                CustomerCountry => '...'                                 # optional
                CustomerComment => '...'                                 # optional
                CustomerURL     => '...'                                 # optional
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        ErrorMessage    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            CustomerID  => '',                     # CustomerID 
            Error => {                              # should not return errors
                    ErrorCode    => 'Customer.Create.ErrorCode'
                    ErrorMessage => 'Error Description'
            },
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->ReturnError(
            ErrorCode    => 'Webservice.InvalidConfiguration',
            ErrorMessage => $Result->{ErrorMessage},
        );
    }

    # check needed stuff
    if (
        !$Param{Data}->{UserLogin}
        && !$Param{Data}->{CustomerLogin}
        && !$Param{Data}->{SessionID}
        )
    {
        return $Self->ReturnError(
            ErrorCode    => 'CustomerCreate.MissingParameter',
            ErrorMessage => "CustomerCreate: UserLogin, CustomerLogin or SessionID is required!",
        );
    }

    if ( $Param{Data}->{UserLogin} || $Param{Data}->{CustomerLogin} ) {

        if ( !$Param{Data}->{Password} )
        {
            return $Self->ReturnError(
                ErrorCode    => 'CustomerCreate.MissingParameter',
                ErrorMessage => "CustomerCreate: Password or SessionID is required!",
            );
        }
    }

    # authenticate user
    my ( $UserID, $UserType ) = $Self->Auth(
        %Param,
    );

    if ( !$UserID ) {
        return $Self->ReturnError(
            ErrorCode    => 'CustomerCreate.AuthFail',
            ErrorMessage => "CustomerCreate: User could not be authenticated!",
        );
    }

    my $PermissionUserID = $UserID;
    if ( $UserType eq 'Customer' ) {
        $UserID = $Kernel::OM->Get('Kernel::Config')->Get('CustomerPanelUserID')
    }

    # check needed hashes
    for my $Needed (qw(Customer)) {
        if ( !IsHashRefWithData( $Param{Data}->{$Needed} ) ) {
            return $Self->ReturnError(
                ErrorCode    => 'CustomerCreate.MissingParameter',
                ErrorMessage => "CustomerCreate: $Needed parameter is missing or not valid!",
            );
        }
    }

    # isolate Customer parameter
    my $Customer = $Param{Data}->{Customer};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$Customer} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $Customer->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $Customer->{$Attribute} =~ s{\s+\z}{};
        }
    }

    # check Customer attribute values
    for my $Needed (qw(CustomerID CustomerName)) {
        if ( !$Customer->{$Needed} ) {
            return $Self->ReturnError(
                ErrorCode    => 'CustomerCreate.MissingParameter',
                ErrorMessage => "CustomerCreate: Customer->$Needed parameter is missing!",
            );
        }
    }
    
    # check CustomerID exists
    my $CompanyExists = $Kernel::OM->Get('Kernel::System::Customer')->CustomerGet(
        CustomerID => $Customer->{CustomerID},
    );
    if ( $CompanyExists ) {
        return {
            Success      => 0,
            ErrorMessage => "Can not create customer company. Customer company '$Customer->{CustomerID}' already exists.",
        }
    }
    
    # create Customer
    my $CompanyID = $Kernel::OM->Get('Kernel::System::Customer')->CustomerAdd(
        %{$Customer},
        Source  => $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::Module')->{'Customer::CustomerCreate'}->{DefaultSource},
        UserID  => $UserID,
        ValidID => 1,
    );    
    if ( !$CompanyID ) {
        return {
            Success      => 0,
            ErrorMessage => 'Could not create customer company, please contact the system administrator',
        }
    }
    
    return {
        Success => 1,
        Data    => {
            CustomerID => $CompanyID,
        },
    };
    
}
