# --
# Kernel/API/Operation/TicketType/TicketTypeUpdate.pm - API TicketType Update operation backend
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

package Kernel::API::Operation::V1::TicketType::TicketTypeUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TicketType::TicketTypeUpdate - API TicketType Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::TicketTypeUpdate');

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
        'TypeID' => {
            DataType => 'NUMERIC',
            Required => 1
        },                
        'TicketType' => {
            Type     => 'HASH',
            Required => 1
        },
        'TicketType::Name' => {
            Required => 1
        },
    }
}

=item Run()

perform TicketTypeUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            ID      => '...',
        }
	    TicketType => {
	        Name    => '...',
            Comment => '...',
	        ValidID => '...',
	    },
	);
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            TypeID  => '',                      # TypeID 
            Error   => {                        # should not return errors
                    Code    => 'TicketType.Update.ErrorCode'
                    Message => 'Error Description'
            },
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # check if tickettype exists 
    my %TicketTypeData = $Kernel::OM->Get('Kernel::System::Type')->TypeGet(
        ID => $Param{Data}->{TypeID},
    );
    
    if ( !%TicketTypeData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Can not update TicketType. No TicketType with ID '$Param{Data}->{TypeID}' found.",
        );
    }

    # isolate and trim TicketType parameter
    my $TicketType = $Self->_Trim(
        Data => $Param{Data}->{TicketType},
    );

    # check if tickettype exists
    my $Exists = $Kernel::OM->Get('Kernel::System::Type')->NameExistsCheck(
        Name => $TicketType->{Name},
        ID   => $Param{Data}->{TypeID},
    );
    
    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not update ticket type. A ticket type with the same name '$TicketType->{Name}' already exists.",
        );
    }

    # update tickettype
    my $Success = $Kernel::OM->Get('Kernel::System::Type')->TypeUpdate(
        ID      => $Param{Data}->{TypeID},
        Name    => $TicketType->{Name} || $TicketTypeData{Name},
        Comment => exists $TicketType->{Comment} ? $TicketType->{Comment} : $TicketTypeData{Comment},
        ValidID => $TicketType->{ValidID} || $TicketTypeData{ValidID},
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update TicketType, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        TypeID => $TicketTypeData{ID},
    );    
}


