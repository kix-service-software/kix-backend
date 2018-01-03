# --
# Kernel/API/Operation/AddressBook/AddressBookCreate.pm - API AddressBook Create operation backend
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

package Kernel::API::Operation::V1::AddressBook::AddressCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::AddressBook::AddressCreate - API AddressBook AddressCreate Operation backend

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

perform AddressCreate Operation. This will return the created AddressID.

    my $Result = $OperationObject->Run(
        Data => {
        	Address => {
                EmailAddress => '...',
            }
	    },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            AddressID  => '',                       # ID of the created AddressBook
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webservice
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    # trim 
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
            'Address' => {
                Type => 'HASH',
                Required => 1
            },
            'Address::EmailAddress' => {
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

     # isolate and trim Address parameter
    my $Address = $Self->_Trim(
        Data => $Param{Data}->{Address},
    );        
   
    # check if Address exists
    my %AddressList = $Kernel::OM->Get('Kernel::System::AddressBook')->AddressList(
        Search => $Address->{EmailAddress},
    );

    if ( IsHashRefWithData(\%AddressList) ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create address book entry. Another address with same email address already exists.",
        );
    }

    # create AddressBook
    my $AddressID = $Kernel::OM->Get('Kernel::System::AddressBook')->AddressAdd(
        EmailAddress => $Address->{EmailAddress},
    );

    if ( !$AddressID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create address book entry, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        AddressID => $AddressID,
    );    
}

1;
