# --
# Kernel/API/Operation/Priority/PriorityCreate.pm - API Priority Create operation backend
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

package Kernel::API::Operation::V1::Priority::PriorityCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Priority::PriorityCreate - API Priority PriorityCreate Operation backend

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
        'Priority' => {
            Type     => 'HASH',
            Required => 1
        },
        'Priority::Name' => {
            Required => 1
        },
    }
}

=item Run()

perform PriorityCreate Operation. This will return the created PriorityID.

    my $Result = $OperationObject->Run(
        Data => {
            Priority => (
                Name    => '...',
                ValidID => 1,                   # optional
            },
        },	
    );

    $Result = {
        Success      => 1,                       # 0 or 1
        Code         => '',                      # 
        Message      => '',                      # in case of error
        Data         => {                        # result data payload after Operation
            PriorityID  => '',                   # PriorityID 
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Priority parameter
    my $Priority = $Self->_Trim(
        Data => $Param{Data}->{Priority}
    );

    # get relevant function	
    my $PriorityID;
     	
    # check if Priority exists
    my $Exists = $Kernel::OM->Get('Kernel::System::Priority')->PriorityLookup(
        Priority => $Priority->{Name},
    );
    
    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create Priority. Priority with same name '$Priority->{Name}' already exists.",
        );
    }

    # create Priority
    $PriorityID = $Kernel::OM->Get('Kernel::System::Priority')->PriorityAdd(
        Name    => $Priority->{Name},
        ValidID => $Priority->{ValidID} || 1,
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$PriorityID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create priority, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        PriorityID => $PriorityID,
    );    
}

1;
