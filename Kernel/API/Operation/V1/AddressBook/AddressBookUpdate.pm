# --
# Kernel/API/Operation/AddressBook/AddressBookUpdate.pm - API AddressBook Update operation backend
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

package Kernel::API::Operation::V1::AddressBook::AddressBookUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::AddressBook::AddressBookUpdate - API AddressBook Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::AddressBookUpdate');

    return $Self;
}

=item Run()

perform AddressBookUpdate Operation. This will return the updated AddressID.

    my $Result = $OperationObject->Run(
        Data => {
            AddressID => 123,
            EmailAddress  => '...',
	    },
	);
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            AddressID  => 123,                  # ID of the updated AddressBook 
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
        Data         => $Param{Data},
        Parameters   => {
            'AddressID' => {
                Required => 1
            },
            'EmailAddress' => {
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

    # trim 
    my $EmailAddress = $Self->_Trim(
        Data => $Param{Data}->{EmailAddress},
    );  

    # check if AddressBook entry exists
    my %AddressBookEntry = $Kernel::OM->Get('Kernel::System::AddressBook')->AddressGet(
        AddressID => $Param{Data}->{AddressID},
    );
  
    if ( !%AddressBookEntry ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update addressbook entry. No entry with AddressID $Param{Data}->{AddressID} found",
        );
    }
    
    # check if EmailAddress exists
    my $AddressBookListResult = $Kernel::OM->Get('Kernel::System::AddressBook')->AddressList(
        Search => $EmailAddress,
    );
  
    if ( IsHashRefWithData($AddressBookListResult) ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot update addressbook entry. Email address '$EmailAddress' already exists in addressbook.",
        );
    }

    # update AddressBook
    my $Success = $Kernel::OM->Get('Kernel::System::AddressBook')->AddressUpdate(
        AddressID      => $Param{Data}->{AddressID},
        EmailAddress   => $EmailAddress,
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update addressbook entry, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        AddressID => $Param{Data}->{AddressID},
    );    
}


