# --
# Kernel/API/Operation/Queue/QueueUpdate.pm - API Queue Update operation backend
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

package Kernel::API::Operation::V1::Queue::QueueUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Queue::QueueUpdate - API Queue Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::QueueUpdate');

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
        'QueueID' => {
            Required => 1
        },
        'Queue' => {
            Type => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform QueueUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            QueueID => 123,
            Queue  => {
                Name                => '...',
                ParentID            => 123,
                Comment             => '...',     # (optional)
                ValidID             => '...',     # (optional)              
                Calendar            => '...',     # (optional)
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
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            QueueID  => 123,                     # ID of the updated Queue 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;
    
    # isolate and trim Queue parameter
    my $Queue = $Self->_Trim(
        Data => $Param{Data}->{Queue}
    );

    # check if Queue exists
    my $QueueName = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
        QueueID => $Param{Data}->{QueueID},
    );
        
    if ( !$QueueName ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    } 

    my %QueueData = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet(
        ID => $Param{Data}->{QueueID},
    );

    # set name to support internal representation of hierarchy
    if ( $Queue->{Name} ) {
        if ( $Queue->{ParentID} ) {
            # ParentID given
            my $ParentQueueName = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
                QueueID => $Queue->{ParentID},
            );
            if ( !$ParentQueueName ) {
                return $Self->_Error(
                    Code    => 'Object.NotFound',
                    Message => "Cannot update Queue. No Queue with ParentID '$Queue->{ParentID}' found.",
                );
            }
            $Queue->{Name} = $ParentQueueName.'::'.$Queue->{Name};
        }
        else {
            # no ParentID given
            my @NameParts = split(/::/, $QueueData{Name});
            pop @NameParts;
            push(@NameParts, $Queue->{Name});
            $Queue->{Name} = join('::', @NameParts);
        }
    }
      
    # update Queue
    my $Success = $Kernel::OM->Get('Kernel::System::Queue')->QueueUpdate(    
        QueueID             => $Param{Data}->{QueueID},
        Name                => $Queue->{Name} || $QueueData{Name},
        Calendar            => $Queue->{Calendar} || $QueueData{Calendar},
        UnlockTimeout       => $Queue->{UnlockTimeout} || $QueueData{UnlockTimeout},
        FollowUpID          => $Queue->{FollowUpID} || $QueueData{FollowUpID},
        FollowUpLock        => $Queue->{FollowUpLock} || $QueueData{FollowUpLock},
        DefaultSignKey      => $Queue->{DefaultSignKey} || $QueueData{DefaultSignKey},
        SystemAddressID     => $Queue->{SystemAddressID} || $QueueData{SystemAddressID},
        Signature           => $Queue->{Signature} || $QueueData{Signature},            
        Comment             => $Queue->{Comment} || $QueueData{Comment},
        ValidID             => $Queue->{ValidID}  || $QueueData{ValidID},
        UserID              => $Self->{Authorization}->{UserID},
    ); 
    
    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result    
    return $Self->_Success(
        QueueID => $Param{Data}->{QueueID},
    );    
}


