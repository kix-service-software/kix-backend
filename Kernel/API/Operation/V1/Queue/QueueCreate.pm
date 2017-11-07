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

=item Run()

perform QueueCreate Operation. This will return the created QueueID.

    my $Result = $OperationObject->Run(
        Data => {
	    	Queue  => {
	        	Name                => '...',
	        	Comment             => '...',     # (optional)
	        	ValidID             => '...',     # (optional)	        	
		        GroupID             => '...',
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
		        SalutationID        => '...',
		        SignatureID         => '...', 		               	        	
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
        Data       => $Param{Data},
        Parameters => {
            'Queue' => {
                Type     => 'HASH',
                Required => 1
            },
            'Queue::Name' => {
                Required => 1
            },
            'Queue::GroupID' => {
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

    # isolate Queue parameter
    my $Queue = $Param{Data}->{Queue};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$Queue} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $Queue->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $Queue->{$Attribute} =~ s{\s+\z}{};
        }
    }   
      	
    # check if Queue exists
    my $Exists = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
        Queue => $Queue->{Name},
    );
    
    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create Queue. Queue with same name '$Queue->{Name}' already exists.",
        );
    }

    # create Queue
    my $QueueID = $Kernel::OM->Get('Kernel::System::Queue')->QueueAdd(
        Name                => $Queue->{Name},
        Comment             => $Queue->{Comment} || '',
        ValidID             => $Queue->{ValidID} || 1,
        GroupID             => $Queue->{GroupID},
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
        SalutationID        => $Queue->{SalutationID} || 1,
        SignatureID         => $Queue->{SignatureID} || 1, 
        UserID              => $Self->{Authorization}->{UserID},
    );

    if ( !$QueueID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create Queue, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        QueueID => $QueueID,
    );    
}


1;
