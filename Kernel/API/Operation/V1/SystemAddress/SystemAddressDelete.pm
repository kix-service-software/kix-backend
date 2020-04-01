# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SystemAddress::SystemAddressDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SystemAddress::SystemAddressDelete - API SystemAddress SystemAddressDelete Operation backend

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
        'SystemAddressID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform SystemAddressDelete Operation. This will return the deleted SystemAddressID.

    my $Result = $OperationObject->Run(
        Data => {
            SystemAddressID  => '...',
        },		
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
  
    # start loop
    foreach my $SystemAddressID ( @{$Param{Data}->{SystemAddressID}} ) {
    	
	    my %QueueIDs = $Kernel::OM->Get('Queue')->GetQueuesForEmailAddress(
	        AddressID  => $SystemAddressID,
	    );
    		    	
        if ( %QueueIDs ) {
            return $Self->_Error(
                Code    => 'Object.DependingObjectExists',
                Message => 'Can not delete SystemAddress. A Queue with this SystemAddress already exists.',
            );
        }	    
	    
        # delete SystemAddress	    
        my $Success = $Kernel::OM->Get('SystemAddress')->SystemAddressDelete(
            SystemAddressID  => $SystemAddressID,
            UserID  => $Self->{Authorization}->{UserID},
        );
  
        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete SystemAddress, please contact the system administrator',
            );
        }
    }

    # return result
    return $Self->_Success();
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
