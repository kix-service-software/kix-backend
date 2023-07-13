# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Queue::QueueUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

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
    my $QueueFullName = $Kernel::OM->Get('Queue')->QueueLookup(
        QueueID => $Param{Data}->{QueueID},
    );

    if ( !$QueueFullName ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    if ( $Queue->{ParentID} && $Queue->{ParentID} == $Param{Data}->{QueueID}) {
        return $Self->_Error(
            Code    => 'Validator.Failed',
            Message => "Validation of attribute ParentID failed! It can not be its own parent.",
        );
    }

    my %QueueData = $Kernel::OM->Get('Queue')->QueueGet(
        ID => $Param{Data}->{QueueID},
    );

    # set name to support internal representation of hierarchy
    if ( $Queue->{Name} || exists $Queue->{ParentID} ) {
        if ( $Queue->{ParentID} ) {
            # ParentID given, create a new queue Name
            my $ParentQueueName = $Kernel::OM->Get('Queue')->QueueLookup(
                QueueID => $Queue->{ParentID},
            );
            if ( !$ParentQueueName ) {
                return $Self->_Error(
                    Code    => 'Object.NotFound',
                    Message => "Cannot update Queue. No Queue with ParentID '$Queue->{ParentID}' found.",
                );
            }
            my @NameParts = split(/::/, $QueueData{Name});
            my $QueueName = pop @NameParts;
            $Queue->{Name} = $ParentQueueName.'::'.($Queue->{Name} || $QueueName);
        }
        elsif ( exists $Queue->{ParentID} ) {
            # ParentID is set to NULL, so move queue to the top-level
            my @NameParts = split(/::/, $QueueFullName);
            my $QueueName = pop @NameParts;
            $Queue->{Name} = ($Queue->{Name} || $QueueName);
        }
        else {
            # no ParentID given but the Name should be updated
            my @NameParts = split(/::/, $QueueFullName);
            pop @NameParts;
            push(@NameParts, $Queue->{Name});
            $Queue->{Name} = join('::', @NameParts);
        }
    }

    # update Queue
    my $Success = $Kernel::OM->Get('Queue')->QueueUpdate(
        QueueID             => $Param{Data}->{QueueID},
        Name                => $Queue->{Name} || $QueueData{Name},
        Calendar            => $Queue->{Calendar} || $QueueData{Calendar},
        UnlockTimeout       => exists $Queue->{UnlockTimeout} ? $Queue->{UnlockTimeout} : $QueueData{UnlockTimeout},
        FollowUpID          => $Queue->{FollowUpID} || $QueueData{FollowUpID},
        FollowUpLock        =>
            $Queue->{FollowUpLock} != $QueueData{FollowUpLock} ? $Queue->{FollowUpLock} : $QueueData{FollowUpLock},
        DefaultSignKey      => $Queue->{DefaultSignKey} || $QueueData{DefaultSignKey},
        SystemAddressID     => $Queue->{SystemAddressID} || $QueueData{SystemAddressID},
        Signature           => exists $Queue->{Signature} ? $Queue->{Signature} : $QueueData{Signature},
        Comment             => exists $Queue->{Comment} ? $Queue->{Comment} : $QueueData{Comment},
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

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
