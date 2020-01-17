# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::AddressBook::AddressUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::AddressBook::AddressUpdate - API AddressBook Update Operation backend

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
        'AddressID' => {
            Required => 1
        },
        'Address' => {
            Type => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform AddressUpdate Operation. This will return the updated AddressID.

    my $Result = $OperationObject->Run(
        Data => {
            AddressID => 123,
        	Address => {
                EmailAddress => '...',
            }
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

    # isolate and trim Address parameter
    my $Address = $Self->_Trim(
        Data => $Param{Data}->{Address},
    );   

    # check if AddressBook entry exists
    my %AddressData = $Kernel::OM->Get('Kernel::System::AddressBook')->AddressGet(
        AddressID => $Param{Data}->{AddressID},
    );
  
    if ( !%AddressData ) {
        return $Self->_Error(
            Code => 'Object.NotFound'
        );
    }
    
    # check if Address exists
    my %AddressList = $Kernel::OM->Get('Kernel::System::AddressBook')->AddressList(
        Search => $Address->{EmailAddress},
    );

    if ( %AddressList && (scalar(keys %AddressList) > 1 || !$AddressList{$AddressData{AddressID}})) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not update address book entry. Another address with same email address already exists.",
        );
    }

    # update AddressBook
    my $Success = $Kernel::OM->Get('Kernel::System::AddressBook')->AddressUpdate(
        AddressID      => $Param{Data}->{AddressID},
        EmailAddress   => $Address->{EmailAddress} || $AddressData{EmailAddress},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update address book entry, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        AddressID => $Param{Data}->{AddressID},
    );    
}



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
