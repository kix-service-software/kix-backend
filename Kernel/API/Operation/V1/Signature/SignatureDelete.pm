# --
# Kernel/API/Operation/Signature/SignatureDelete.pm - API Signature Delete operation backend
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

package Kernel::API::Operation::V1::Signature::SignatureDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Signature::SignatureDelete - API Signature SignatureDelete Operation backend

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
        'SignatureID' => {
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform SignatureDelete Operation. This will return {}.

    my $Result = $OperationObject->Run(
        Data => {
            SignatureID  => '...',
        },		
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my %Queues = $Kernel::OM->Get('Kernel::System::Queue')->QueueList();

    my %AssignedSignatures;
    foreach my $ID ( keys %Queues ) {                   
        my %Queue = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet(
            ID    => $ID,
        );
        next if !%Queue;
        $AssignedSignatures{$Queue{SignatureID}} = 1;
    }
         
    # start loop
    foreach my $SignatureID ( @{$Param{Data}->{SignatureID}} ) {

        if ( $AssignedSignatures{$SignatureID} ) {
            return $Self->_Error(
                Code    => 'Object.DependingObjectExists',
                Message => 'Can not delete Signature. A Queue with this SignatureID already exists.',
            );
        }

        # delete Signature	    
        my $Success = $Kernel::OM->Get('Kernel::System::Signature')->SignatureDelete(
            ID  => $SignatureID,
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete Signature, please contact the system administrator',
            );
        }
    }

    # return result
    return $Self->_Success();
}

1;
