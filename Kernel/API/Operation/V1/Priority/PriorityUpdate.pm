# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Priority::PriorityUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Priority::PriorityUpdate - API Priority Update Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to update an instance of this
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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::PriorityUpdate');

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
        'PriorityID' => {
            DataType => 'NUMERIC',
            Required => 1,
        },
        'Priority' => {
            Type => 'HASH',
            Required => 1
        }
    }
}

=item Run()

perform PriorityUpdate Operation. This will return the updated Priority.

    my $Result = $OperationObject->Run(
        Data => {
            PriorityID => 123,
    	    Priority   => {
                ...
    	    },
        }
    );
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            PriorityID  => '',                  # PriorityID 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Priority parameter
    my $Priority = $Self->_Trim(
        Data => $Param{Data}->{Priority}
    );

    # check if Priority exists 
    my %PriorityData = $Kernel::OM->Get('Kernel::System::Priority')->PriorityGet(
        PriorityID => $Param{Data}->{PriorityID},
        UserID  => $Self->{Authorization}->{UserID},
    );
    
    if ( !%PriorityData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # update Priority
    my $Success = $Kernel::OM->Get('Kernel::System::Priority')->PriorityUpdate(
        PriorityID     => $Param{Data}->{PriorityID},
        Name           => $Priority->{Name} || $PriorityData{Name},
        Comment        => exists $Priority->{Comment} ? $Priority->{Comment} : $PriorityData{Comment},
        ValidID        => $Priority->{ValidID} || $PriorityData{ValidID} || 1,
        UserID         => $Self->{Authorization}->{UserID},
        CheckSysConfig => 0,
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result    
    return $Self->_Success(
        PriorityID => 0 + $Param{Data}->{PriorityID},
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
