# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::TicketUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::TicketUpdate - API Ticket TicketUpdate Operation backend

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
        'TicketID' => {
            Required => 1
        },
        'Ticket' => {
            Type     => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform TicketUpdate Operation. This will return the updated TicketID

    my $Result = $OperationObject->Run(
        Data => {
            TicketID          => 123,                                           # required
            Ticket            => {
                Title         => 'some ticket title',                           # optional
                QueueID       => 123,                                           # Optional
                Queue         => 'some queue name',                             # Optional
                LockID        => 123,                                           # optional
                Lock          => 'some lock name',                              # optional
                TypeID        => 123,                                           # optional
                Type          => 'some type name',                              # optional
                StateID       => 123,                                           # optional
                State         => 'some state name',                             # optional
                PriorityID    => 123,                                           # optional
                Priority      => 'some priority name',                          # optional
                OwnerID       => 123,                                           # optional
                Owner         => 'some user login',                             # optional
                ResponsibleID => 123,                                           # optional
                Responsible   => 'some user login',                             # optional
                ContactID      => 'some customer user login',                   # optional
                OrganisationID => 'some customer',                              # optional
                PendingTime   => '2011-12-03 23:05:00',                         # optional
                DynamicFields => [                                              # optional
                    {
                        Name   => 'some name',
                        Value  => $Value,                                       # value type depends on the dynamic field
                    },
                    # ...
                ],
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            TicketID    => 123,                     # ID of changed ticket
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Ticket parameter
    my $Ticket = $Self->_Trim(
        Data => $Param{Data}->{Ticket}
    );

    # get ticket
    my %TicketData = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID => $Param{Data}->{TicketID}
    );

    # Lock can only be set if OwnerID != 1
    if ( $Ticket->{LockID} && $Ticket->{LockID} == 2 && (($TicketData{OwnerID} == 1 && !$Ticket->{OwnerID}) || ($Ticket->{OwnerID} && $Ticket->{OwnerID} == 1)) ) {
        return $Self->_Error(
            Code    => 'Conflict',
            Message => "Ticket can't be locked if OwnerID is 1!",
        );
    }

    # check Ticket attribute values
    my $TicketCheck = $Self->_CheckTicket(
        Ticket => {
            %TicketData,
            %{$Ticket},
        }
    );

    if ( !$TicketCheck->{Success} ) {
        return $Self->_Error(
            %{$TicketCheck},
        );
    }

    # everything is ok, let's update the ticket
    # do not update if only MarkAsSeen is given
    if ( scalar(keys %{$Ticket}) > 1 || !$Ticket->{MarkAsSeen} ) {
        my $Result = $Self->_TicketUpdate(
            TicketID => $Param{Data}->{TicketID},
            Ticket   => {
                StateID => (!$Ticket->{State} && !$Ticket->{StateID}) ? $TicketData{StateID} : undef,
                %{$Ticket}
            },
            UserID => $Self->{Authorization}->{UserID},
        );

        # return on error
        return $Result if (!$Result->{Success});
    }

    if ( $Ticket->{MarkAsSeen} ) {
        my $TicketObject = $Kernel::OM->Get('Ticket');

        my @ArticleList = $TicketObject->ArticleIndex(
            TicketID => $Param{Data}->{TicketID}
        );

        # mark all article as seen
        for my $ArticleID (@ArticleList) {
            $TicketObject->ArticleFlagSet(
                ArticleID => $ArticleID,
                Key       => 'Seen',
                Value     => 1,
                UserID    => $Self->{Authorization}->{UserID},
                Silent    => 1
            );
        }

        # mark ticket as seen
        my $Success = $TicketObject->TicketFlagSet(
            TicketID => $Param{Data}->{TicketID},
            Key      => 'Seen',
            Value    => 1,
            UserID   => $Self->{Authorization}->{UserID},
        );

        if ( !$Success ) {
            my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
                Type => 'error',
                What => 'Message',
            );
            return $Self->_Error(
                Code    => 'InternalError',
                Message => "Could not mark ticket as seen ($LogMessage).",
            );
        }
    }

    return $Self->_Success(
        TicketID => "" . $Param{Data}->{TicketID}
    );
}

=begin Internal:

=item _TicketUpdate()

update a ticket with its dynamic fields

    my $Response = $OperationObject->_TicketUpdate(
        TicketID         => 123,
        Ticket           => { },                # all ticket parameters
        UserID           => 123,
    );

    returns:

    $Response = {
        Success => 1,                           # if everything is OK
        Data => {
            TicketID     => 123,
        }
    }

    $Response = {
        Success      => 0,                      # if unexpected error
        Code         => '...'
        Message      => '...',
    }

=cut

sub _TicketUpdate {
    my ( $Self, %Param ) = @_;

    my $Ticket = $Param{Ticket};

    # get database object
    my $UserObject = $Kernel::OM->Get('User');

    my $OwnerID;
    if ( $Ticket->{Owner} && !$Ticket->{OwnerID} ) {
        my %OwnerData = $UserObject->GetUserData(
            User => $Ticket->{Owner},
        );
        $OwnerID = $OwnerData{UserID};
    }
    elsif ( defined $Ticket->{OwnerID} ) {
        $OwnerID = $Ticket->{OwnerID};
    }

    my $ResponsibleID;
    if ( $Ticket->{Responsible} && !$Ticket->{ResponsibleID} ) {
        my %ResponsibleData = $UserObject->GetUserData(
            User => $Ticket->{Responsible},
        );
        $ResponsibleID = $ResponsibleData{UserID};
    }
    elsif ( defined $Ticket->{ResponsibleID} ) {
        $ResponsibleID = $Ticket->{ResponsibleID};
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # get current ticket data
    my %TicketData = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
        UserID        => $Param{UserID},
    );

    # update ticket parameters
    # update Ticket->Title
    if (
        defined $Ticket->{Title}
        && $Ticket->{Title} ne ''
        && $Ticket->{Title} ne $TicketData{Title}
        )
    {
        my $Success = $TicketObject->TicketTitleUpdate(
            Title    => $Ticket->{Title},
            TicketID => $Param{TicketID},
            UserID   => $Param{UserID},
        );
        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToUpdate',
                Message => 'Unable to update ticket, please contact system administrator!',
            );
        }
    }

    # update Ticket->Queue
    if ( $Ticket->{Queue} || $Ticket->{QueueID} ) {
        my $Success;
        if ( defined $Ticket->{Queue} && $Ticket->{Queue} ne $TicketData{Queue} ) {
            $Success = $TicketObject->TicketQueueSet(
                Queue    => $Ticket->{Queue},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
        elsif ( defined $Ticket->{QueueID} && $Ticket->{QueueID} ne $TicketData{QueueID} ) {
            $Success = $TicketObject->TicketQueueSet(
                QueueID  => $Ticket->{QueueID},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
        else {

            # data is the same as in ticket nothing to do
            $Success = 1;
        }

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToUpdate',
                Message => 'Unable to update ticket, please contact system administrator!',
            );
        }
    }

    # update Ticket->Type
    if ( $Ticket->{Type} || $Ticket->{TypeID} ) {
        my $Success;
        if ( defined $Ticket->{Type} && $Ticket->{Type} ne $TicketData{Type} ) {
            $Success = $TicketObject->TicketTypeSet(
                Type     => $Ticket->{Type},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
        elsif ( defined $Ticket->{TypeID} && $Ticket->{TypeID} ne $TicketData{TypeID} )
        {
            $Success = $TicketObject->TicketTypeSet(
                TypeID   => $Ticket->{TypeID},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
        else {

            # data is the same as in ticket nothing to do
            $Success = 1;
        }

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToUpdate',
                Message => 'Unable to update ticket, please contact system administrator!',
            );
        }
    }

    # update Ticket>State
    # depending on the state, might require to unlock ticket or enables pending time set
    if ( $Ticket->{State} || $Ticket->{StateID} ) {

        # get State Data
        my %StateData;
        my $StateID;

        # get state object
        my $StateObject = $Kernel::OM->Get('State');

        if ( $Ticket->{StateID} ) {
            $StateID = $Ticket->{StateID};
        }
        else {
            $StateID = $StateObject->StateLookup(
                State => $Ticket->{State},
            );
        }

        %StateData = $StateObject->StateGet(
            ID => $StateID,
        );

        # force unlock if state type is close
        if ( $StateData{TypeName} =~ /^close/i ) {

            # set lock
            $TicketObject->TicketLockSet(
                TicketID => $Param{TicketID},
                Lock     => 'unlock',
                UserID   => $Param{UserID},
            );
        }

        # set pending time
        elsif ($StateData{TypeName} =~ /^pending/i) {
            if (!$TicketData{PendingTime} && !defined $Ticket->{PendingTime}) {
                return $Self->_Error(
                    Code    => 'Object.UnableToUpdate',
                    Message => 'Unable to update pending state without pending time!',
                );
            }

            # set pending time
            if (defined $Ticket->{PendingTime}) {
                my $Success = $TicketObject->TicketPendingTimeSet(
                    UserID   => $Param{UserID},
                    TicketID => $Param{TicketID},
                    String   => $Ticket->{PendingTime},
                );
                if (!$Success) {
                    return $Self->_Error(
                        Code    => 'Object.UnableToUpdate',
                        Message => 'Unable to update ticket, please contact system administrator!',
                    );
                }
            }
        }

        my $Success;
        if ( defined $Ticket->{State} && $Ticket->{State} ne $TicketData{State} ) {
            $Success = $TicketObject->TicketStateSet(
                State    => $Ticket->{State},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
        elsif ( defined $Ticket->{StateID} && $Ticket->{StateID} ne $TicketData{StateID} )
        {
            $Success = $TicketObject->TicketStateSet(
                StateID  => $Ticket->{StateID},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
        else {

            # data is the same as in ticket nothing to do
            $Success = 1;
        }

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToUpdate',
                Message => 'Unable to update ticket, please contact system administrator!',
            );
        }
    }

    # update Ticket->ContactID && Ticket->OrganisationID
    if ( $Ticket->{ContactID} || $Ticket->{OrganisationID} ) {

        # set values to empty if they are not defined
        $TicketData{ContactID}      = $TicketData{ContactID} || '';
        $TicketData{OrganisationID} = $TicketData{OrganisationID} || '';
        $Ticket->{ContactID}        = $Ticket->{ContactID} || $TicketData{ContactID} ||'';
        $Ticket->{OrganisationID}   = $Ticket->{OrganisationID} || $TicketData{OrganisationID} || '';

        my $Success;
        if (
            $Ticket->{ContactID} ne $TicketData{ContactID}
            || $Ticket->{OrganisationID} ne $TicketData{OrganisationID}
            )
        {
            $Success = $TicketObject->TicketCustomerSet(
                OrganisationID => $Ticket->{OrganisationID},
                ContactID      => $Ticket->{ContactID},
                TicketID       => $Param{TicketID},
                UserID         => $Param{UserID},
            );
        }
        else {

            # data is the same as in ticket nothing to do
            $Success = 1;
        }

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToUpdate',
                Message => 'Unable to update ticket, please contact system administrator!',
            );
        }
    }

    # update Ticket->Priority
    if ( $Ticket->{Priority} || $Ticket->{PriorityID} ) {
        my $Success;
        if ( defined $Ticket->{Priority} && $Ticket->{Priority} ne $TicketData{Priority} ) {
            $Success = $TicketObject->TicketPrioritySet(
                Priority => $Ticket->{Priority},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
        elsif ( defined $Ticket->{PriorityID} && $Ticket->{PriorityID} ne $TicketData{PriorityID} )
        {
            $Success = $TicketObject->TicketPrioritySet(
                PriorityID => $Ticket->{PriorityID},
                TicketID   => $Param{TicketID},
                UserID     => $Param{UserID},
            );
        }
        else {

            # data is the same as in ticket nothing to do
            $Success = 1;
        }

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToUpdate',
                Message => 'Unable to update ticket, please contact system administrator!',
            );
        }
    }

    my $UnlockOnAway = 1;

    # update Ticket->Owner
    if ( $Ticket->{Owner} || $Ticket->{OwnerID} ) {
        my $Success;
        if ( defined $Ticket->{Owner} && $Ticket->{Owner} ne $TicketData{Owner} ) {
            $Success = $TicketObject->TicketOwnerSet(
                NewUser  => $Ticket->{Owner},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
            $UnlockOnAway = 0;
        }
        elsif ( defined $Ticket->{OwnerID} && $Ticket->{OwnerID} ne $TicketData{OwnerID} )
        {
            $Success = $TicketObject->TicketOwnerSet(
                NewUserID => $Ticket->{OwnerID},
                TicketID  => $Param{TicketID},
                UserID    => $Param{UserID},
            );
            $UnlockOnAway = 0;
        }
        else {

            # data is the same as in ticket nothing to do
            $Success = 1;
        }

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToUpdate',
                Message => 'Unable to update ticket, please contact system administrator!',
            );
        }
    }

    # update Ticket->Responsible
    if ( $Ticket->{Responsible} || $Ticket->{ResponsibleID} ) {
        my $Success;
        if (
            defined $Ticket->{Responsible}
            && $Ticket->{Responsible} ne $TicketData{Responsible}
            )
        {
            $Success = $TicketObject->TicketResponsibleSet(
                NewUser  => $Ticket->{Responsible},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
        elsif (
            defined $Ticket->{ResponsibleID}
            && $Ticket->{ResponsibleID} ne $TicketData{ResponsibleID}
            )
        {
            $Success = $TicketObject->TicketResponsibleSet(
                NewUserID => $Ticket->{ResponsibleID},
                TicketID  => $Param{TicketID},
                UserID    => $Param{UserID},
            );
        }
        else {

            # data is the same as in ticket nothing to do
            $Success = 1;
        }

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToUpdate',
                Message => 'Unable to update ticket, please contact system administrator!',
            );
        }
    }

    # update Ticket->Lock (lock has to be done after owner set)
    if ( $Ticket->{Lock} || $Ticket->{LockID} ) {
        my $Success;
        if ( defined $Ticket->{Lock} && $Ticket->{Lock} ne $TicketData{Lock} ) {
            $Success = $TicketObject->TicketLockSet(
                Lock     => $Ticket->{Lock},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
        elsif ( defined $Ticket->{LockID} && $Ticket->{LockID} ne $TicketData{LockID} ) {
            $Success = $TicketObject->TicketLockSet(
                LockID   => $Ticket->{LockID},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
        else {

            # data is the same as in ticket nothing to do
            $Success = 1;
        }

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToUpdate',
                Message => 'Unable to update ticket, please contact system administrator!',
            );
        }
    }

    # set dynamic fields
    if ( IsArrayRefWithData($Ticket->{DynamicFields}) ) {

        DYNAMICFIELD:
        foreach my $DynamicField ( @{$Ticket->{DynamicFields}} ) {
            my $Result = $Self->_SetDynamicFieldValue(
                %{$DynamicField},
                ObjectID   => $Param{TicketID},
                ObjectType => 'Ticket',
                UserID     => $Param{UserID},
            );

            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    Code         => 'Object.UnableToUpdate',
                    Message      => "Dynamic Field $DynamicField->{Name} could not be set ($Result->{Message})",
                );
            }
        }
    }

    #WORKAROUND KIX2018-3986
    return $Self->_Success(
        TicketID => "" . $Param{TicketID},
    );
}

1;

=end Internal:





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
