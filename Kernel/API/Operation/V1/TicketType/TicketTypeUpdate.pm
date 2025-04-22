# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::TicketType::TicketTypeUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

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
        }
    }
}

=item Run()

perform TicketTypeUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            ID      => '...',
        }
	    TicketType => {
            ...
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
    my %TicketTypeData = $Kernel::OM->Get('Type')->TypeGet(
        ID => $Param{Data}->{TypeID},
    );

    if ( !%TicketTypeData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # isolate and trim TicketType parameter
    my $TicketType = $Self->_Trim(
        Data => $Param{Data}->{TicketType},
    );

    # check if tickettype exists
    my $Exists = $Kernel::OM->Get('Type')->NameExistsCheck(
        Name => $TicketType->{Name},
        ID   => $Param{Data}->{TypeID},
    );

    if ( $Exists ) {
        return $Self->_Error(
            Code => 'Object.AlreadyExists',
        );
    }

    # update tickettype
    my $Success = $Kernel::OM->Get('Type')->TypeUpdate(
        ID      => $Param{Data}->{TypeID},
        Name    => $TicketType->{Name} || $TicketTypeData{Name},
        Comment => exists $TicketType->{Comment} ? $TicketType->{Comment} : $TicketTypeData{Comment},
        ValidID => $TicketType->{ValidID} || $TicketTypeData{ValidID},
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result
    return $Self->_Success(
        TypeID => $TicketTypeData{ID},
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
