# --
# Kernel/API/Operation/Customer/CustomerCreate.pm - API Customer Create operation backend
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
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Customer::V1::CustomerCreate - API Customer Create Operation backend

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

    return $Self;
}

=item Run()

perform CustomerCreate Operation. This will return the created CustomerLogin.

    my $Result = $OperationObject->Run(
        Data => {
            SourceID => '...'       # required (ID of backend to write to - backend must be writeable)
            Customer => {
                ...                 # attributes (required and optional) depend on Map config 
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            CustomerID  => '',                       # CustomerID 
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

    # prepare data (first check)
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'SourceID' => {
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

    # determine required attributes from Map config
    my $Config = $Kernel::OM->Get('Kernel::Config')->Get($Param{Data}->{SourceID});
    my %RequiredAttributes;
    foreach my $MapItem ( @{$Config->{Map}} ) {
        next if !$MapItem->{Required} || $MapItem->{Attribute} eq 'ValidID';

        $RequiredAttributes{'Customer::'.$MapItem->{Attribute}} = {
            Required => 1
        };
    }

    # prepare data (second check with more attributes)
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'Customer' => {
                Type     => 'HASH',
                Required => 1
            },          
            %RequiredAttributes,
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # check if backend (Source) is writeable
    my %SourceList = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanySourceList(
        ReadOnly => 0
    );    
    if ( !$SourceList{$Param{Data}->{SourceID}} ) {
        return $Self->_Error(
            Code    => 'Forbidden',
            Message => 'Can not create Customer. Backend with given SourceID is not writable or does not exist.',
        );        
    }
    
    # isolate and trim Customer parameter
    my $Customer = $Self->_Trim(
        Data => $Param{Data}->{Customer}
    );

    # check CustomerCompanyName exists
    my %CustomerList = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyList(
        Search => $Customer->{CustomerCompanyName},
    );
    if ( %CustomerList ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => 'Can not create Customer. Another Customer with same name already exists.',
        );
    }
    
    # create Customer
    my $CustomerID = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyAdd(
        %{$Customer},
        Source  => $Param{Data}->{SourceID},
        UserID  => $Self->{Authorization}->{UserID},
        ValidID => 1,
    );    
    if ( !$CustomerID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create Customer, please contact the system administrator',
        );
    }
    
    return $Self->_Success(
        Code   => 'Object.Created',
        CustomerID => $CustomerID,
    );    
}
