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

=item Run()

perform QueueUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            QueueID => 123,
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
        Data         => $Param{Data},
        Parameters   => {
            'QueueID' => {
                Required => 1
            },
            'Queue' => {
                Type => 'HASH',
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
            Code    => 'Object.NotFound',
            Message => "Cannot update Queue. No Queue with ID '$Param{Data}->{QueueID}' found.",
        );
    } 
        
    my %QueueData = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet(
        ID => $Param{Data}->{QueueID},
    );
  
    # update Queue
    my $Success = $Kernel::OM->Get('Kernel::System::Queue')->QueueUpdate(    
        QueueID             => $Param{Data}->{QueueID},
        Name                => $Queue->{Name} || $QueueData{Name},
        GroupID             => $Queue->{GroupID} || $QueueData{GroupID},
        Calendar            => $Queue->{Calendar} || $QueueData{Calendar},
        FirstResponseTime   => $Queue->{FirstResponseTime} || $QueueData{FirstResponseTime},
        FirstResponseNotify => $Queue->{FirstResponseNotify} || $QueueData{FirstResponseNotify},
        UpdateTime          => $Queue->{UpdateTime} || $QueueData{UpdateTime},
        UpdateNotify        => $Queue->{UpdateNotify} || $QueueData{UpdateNotify},
        SolutionTime        => $Queue->{SolutionTime} || $QueueData{SolutionTime},
        SolutionNotify      => $Queue->{SolutionNotify} || $QueueData{SolutionNotify},
        UnlockTimeout       => $Queue->{UnlockTimeout} || $QueueData{UnlockTimeout},
        FollowUpID          => $Queue->{FollowUpID} || $QueueData{FollowUpID},
        FollowUpLock        => $Queue->{FollowUpLock} || $QueueData{FollowUpLock},
        DefaultSignKey      => $Queue->{DefaultSignKey} || $QueueData{DefaultSignKey},
        SystemAddressID     => $Queue->{SystemAddressID} || $QueueData{SystemAddressID},
        SalutationID        => $Queue->{SalutationID} || $QueueData{SalutationID},
        SignatureID         => $Queue->{SignatureID} || $QueueData{SignatureID},            
        Comment             => $Queue->{Comment} || $QueueData{Comment},
        ValidID             => $Queue->{ValidID}  || $QueueData{ValidID},
        UserID              => $Self->{Authorization}->{UserID},
    ); 
    
    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update Queue, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        QueueID => $Param{Data}->{QueueID},
    );    
}


