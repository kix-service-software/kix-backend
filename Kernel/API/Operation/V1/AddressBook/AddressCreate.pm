# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::AddressBook::AddressCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

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
        'Address' => {
            Type => 'HASH',
            Required => 1
        },
        'Address::EmailAddress' => {
            Required => 1
        },            
    }
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

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
