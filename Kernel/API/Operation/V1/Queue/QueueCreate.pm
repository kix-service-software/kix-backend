# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Queue::QueueCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

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
        my $ParentQueueName = $Kernel::OM->Get('Queue')->QueueLookup(
            QueueID => $Queue->{ParentID},
            Silent  => 1
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
    my $Exists = $Kernel::OM->Get('Queue')->QueueLookup(
        Queue  => $Queue->{Name},
        Silent => 1,
    );

    if ( $Exists ) {
        return $Self->_Error(
            Code => 'Object.AlreadyExists',
        );
    }

    # create Queue
    my $QueueID = $Kernel::OM->Get('Queue')->QueueAdd(
        Name                => $Queue->{Name},
        Comment             => $Queue->{Comment} || '',
        ValidID             => $Queue->{ValidID} || 1,
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


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
