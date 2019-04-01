# --
# Kernel/API/Operation/Queue/QueueCreate.pm - API Queue Create operation backend
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

package Kernel::API::Operation::V1::Queue::QueueCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Queue::QueueCreate - API Queue QueueCreate Operation backend

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
        'Queue' => {
            Type     => 'HASH',
            Required => 1
        },
        'Queue::Name' => {
            Required => 1
        }
    }
}

=item Run()

perform QueueCreate Operation. This will return the created QueueID.

    my $Result = $OperationObject->Run(
        Data => {
	    	Queue  => {
	        	Name                => '...',
	        	Comment             => '...',     # (optional)
	        	ValidID             => '...',     # (optional)	        	
		        Calendar            => '...',     # (optional)
		        FirstResponseTime   => '...',     # (optional)
		        FirstResponseNotify => '...',     # (optional, notify agent if first response escalation is 60% reached)
		        UpdateTime          => '...',     # (optional)
		        UpdateNotify        => '...',     # (optional, notify agent if update escalation is 80% reached)
		        SolutionTime        => '...',     # (optional)
		        SolutionNotify      => '...',     # (optional, notify agent if solution escalation is 80% reached)
		        UnlockTimeout       => '...',,    # (optional)
		        FollowUpID          => '...',     # possible (1), reject (2) or new ticket (3) (optional, default 0)
		        FollowUpLock        => '...',     # yes (1) or no (0) (optional, default 0)
		        DefaultSignKey      => '...',     # (optional)
		        SystemAddressID     => '...',
		        Signature           => '...', 		               	        	
	    	},
	    },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            QueueID  => '',                         # ID of the created Queue
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Queue parameter
    my $Queue = $Self->_Trim(
        Data => $Param{Data}->{Queue}
    );

    # set name to support internal representation of hierarchy
    if ( $Queue->{ParentID} ) {
        my $ParentQueueName = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
            QueueID => $Queue->{ParentID},
        );
        if ( !$ParentQueueName ) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "Cannot create Queue. No Queue with ParentID '$Queue->{ParentID}' found.",
            );
        }
        $Queue->{Name} = $ParentQueueName.'::'.$Queue->{Name};
    }

    # check if Queue exists
    my $Exists = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
        Queue => $Queue->{Name},
    );
    
    if ( $Exists ) {
        return $Self->_Error(
            Code => 'Object.AlreadyExists',
        );
    }

    # create Queue
    my $QueueID = $Kernel::OM->Get('Kernel::System::Queue')->QueueAdd(
        Name                => $Queue->{Name},
        Comment             => $Queue->{Comment} || '',
        ValidID             => $Queue->{ValidID} || 1,
        Calendar            => $Queue->{Calendar} || '',
        FirstResponseTime   => $Queue->{FirstResponseTime} || '',
        FirstResponseNotify => $Queue->{FirstResponseNotify} || '',
        UpdateTime          => $Queue->{UpdateTime} || '',
        UpdateNotify        => $Queue->{UpdateNotify} || '',
        SolutionTime        => $Queue->{SolutionTime} || '',
        SolutionNotify      => $Queue->{SolutionNotify} || '',
        UnlockTimeout       => $Queue->{UnlockTimeout} || '',
        FollowUpID          => $Queue->{FollowUpID} || '',
        FollowUpLock        => $Queue->{FollowUpLock} || '',
        DefaultSignKey      => $Queue->{DefaultSignKey} || '',
        SystemAddressID     => $Queue->{SystemAddressID} || 1,
        Signature           => $Queue->{Signature} || '', 
        UserID              => $Self->{Authorization}->{UserID},
    );

    if ( !$QueueID ) {
        return $Self->_Error(
            Code => 'Object.UnableToCreate',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        QueueID => $QueueID,
    );    
}


1;
