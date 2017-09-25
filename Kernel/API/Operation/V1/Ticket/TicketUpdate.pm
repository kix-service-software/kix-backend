# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::TicketUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

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

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!"
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::TicketUpdate');

    return $Self;
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
                ServiceID     => 123,                                           # optional
                Service       => 'some service name',                           # optional
                SLAID         => 123,                                           # optional
                SLA           => 'some SLA name',                               # optional
                StateID       => 123,                                           # optional
                State         => 'some state name',                             # optional
                PriorityID    => 123,                                           # optional
                Priority      => 'some priority name',                          # optional
                OwnerID       => 123,                                           # optional
                Owner         => 'some user login',                             # optional
                ResponsibleID => 123,                                           # optional
                Responsible   => 'some user login',                             # optional
                CustomerUser  => 'some customer user login',                    # optional
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
        ErrorMessage    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            TicketID    => 123,                     # ID of changed ticket
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
            'TicketID' => {
                Required => 1
            },
            'Ticket' => {
                Type     => 'HASH',
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

    my $PermissionUserID = $Self->{Authorization}->{UserID};
    if ( $Self->{Authorization}->{UserType} eq 'Customer' ) {
        $PermissionUserID = $Kernel::OM->Get('Kernel::Config')->Get('CustomerPanelUserID')
    }

    # isolate ticket hash
    my $Ticket = $Param{Data}->{Ticket};

    # check update permission
    my $Permission = $Self->CheckUpdatePermission(
        TicketID => $Param{Data}->{TicketID},
        Ticket   => $Ticket,
        UserID   => $PermissionUserID,
        UserType => $Self->{Authorization}->{UserType},
    );

    if ( !$Permission->{Success} ) {
        return $Permission;
    }

    # check Ticket attribute values
    my $TicketCheck = $Self->_CheckTicket( 
        Ticket => $Ticket 
    );

    if ( !$TicketCheck->{Success} ) {
        return $Self->_Error(
            %{$TicketCheck},
        );
    }

    # everything is ok, let's update the ticket
    return $Self->_TicketUpdate(
        TicketID => $Param{Data}->{TicketID},
        Ticket   => $Ticket,
        UserID   => $PermissionUserID,
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
        Success => 1,                           # if everething is OK
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

    # get customer information
    # with information will be used to create the ticket if customer is not defined in the
    # database, customer ticket information need to be empty strings
    my %CustomerUserData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
        User => $Ticket->{CustomerUser},
    );

    my $CustomerID = $CustomerUserData{UserCustomerID} || '';

    # use user defined CustomerID if defined
    if ( defined $Ticket->{CustomerID} && $Ticket->{CustomerID} ne '' ) {
        $CustomerID = $Ticket->{CustomerID};
    }

    # get database object
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

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
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

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

    # update Ticket->Lock
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
        my $StateObject = $Kernel::OM->Get('Kernel::System::State');

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
        elsif ( $StateData{TypeName} =~ /^pending/i ) {

            # set pending time
            if ( defined $Ticket->{PendingTime} ) {
                my $Success = $TicketObject->TicketPendingTimeSet(
                    UserID   => $Param{UserID},
                    TicketID => $Param{TicketID},
                    %{ $Ticket->{PendingTime} },
                );

                if ( !$Success ) {
                    return $Self->_Error(
                        Code    => 'Object.UnableToUpdate',
                        Message => 'Unable to update ticket, please contact system administrator!',
                    );
                }
            }
            else {
                return $Self->_Error(
                    Code    => 'Object.UnableToUpdate',
                    Message => 'Unable to update pending state without pending time!',
                );
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

    # update Ticket->Service
    # this might reset SLA if current SLA is not available for the new service
    if ( $Ticket->{Service} || $Ticket->{ServiceID} ) {

        # check if ticket has a SLA assigned
        if ( $TicketData{SLAID} ) {

            # check if old SLA is still valid
            if (
                !$Self->ValidateSLA(
                    SLAID     => $TicketData{SLAID},
                    Service   => $Ticket->{Service} || '',
                    ServiceID => $Ticket->{ServiceID} || '',
                )
                )
            {

                # remove current SLA if is not compatible with new service
                my $Success = $TicketObject->TicketSLASet(
                    SLAID    => '',
                    TicketID => $Param{TicketID},
                    UserID   => $Param{UserID},
                );
            }
        }

        my $Success;

        # prevent comparison errors on undefined values
        if ( !defined $TicketData{Service} ) {
            $TicketData{Service} = '';
        }
        if ( !defined $TicketData{ServiceID} ) {
            $TicketData{ServiceID} = '';
        }

        if ( defined $Ticket->{Service} && $Ticket->{Service} ne $TicketData{Service} ) {
            $Success = $TicketObject->TicketServiceSet(
                Service  => $Ticket->{Service},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
        elsif ( defined $Ticket->{ServiceID} && $Ticket->{ServiceID} ne $TicketData{ServiceID} )
        {
            $Success = $TicketObject->TicketServiceSet(
                ServiceID => $Ticket->{ServiceID},
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

    # update Ticket->SLA
    if ( $Ticket->{SLA} || $Ticket->{SLAID} ) {
        my $Success;

        # prevent comparison errors on undefined values
        if ( !defined $TicketData{SLA} ) {
            $TicketData{SLA} = '';
        }
        if ( !defined $TicketData{SLAID} ) {
            $TicketData{SLAID} = '';
        }

        if ( defined $Ticket->{SLA} && $Ticket->{SLA} ne $TicketData{SLA} ) {
            $Success = $TicketObject->TicketSLASet(
                SLA      => $Ticket->{SLA},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
        elsif ( defined $Ticket->{SLAID} && $Ticket->{SLAID} ne $TicketData{SLAID} )
        {
            $Success = $TicketObject->TicketSLASet(
                SLAID    => $Ticket->{SLAID},
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

    # update Ticket->CustomerUser && Ticket->CustomerID
    if ( $Ticket->{CustomerUser} || $Ticket->{CustomerID} ) {

        # set values to empty if they are not defined
        $TicketData{CustomerUserID} = $TicketData{CustomerUserID} || '';
        $TicketData{CustomerID}     = $TicketData{CustomerID}     || '';
        $Ticket->{CustomerUser}     = $Ticket->{CustomerUser}     || '';
        $Ticket->{CustomerID}       = $Ticket->{CustomerID}       || '';

        my $Success;
        if (
            $Ticket->{CustomerUser} ne $TicketData{CustomerUserID}
            || $Ticket->{CustomerID} ne $TicketData{CustomerID}
            )
        {
            my $CustomerID = $CustomerUserData{UserCustomerID} || '';

            # use user defined CustomerID if defined
            if ( defined $Ticket->{CustomerID} && $Ticket->{CustomerID} ne '' ) {
                $CustomerID = $Ticket->{CustomerID};
            }

            $Success = $TicketObject->TicketCustomerSet(
                No       => $CustomerID,
                User     => $Ticket->{CustomerUser},
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

    # set dynamic fields
    if ( IsArrayRefWithData($Ticket->{DynamicFields}) ) {

        DYNAMICFIELD:
        foreach my $DynamicField ( @{$Ticket->{DynamicFields}} ) {
            next DYNAMICFIELD if !$Self->ValidateDynamicFieldObjectType( %{$DynamicField} );

            my $Result = $Self->SetDynamicFieldValue(
                %{$DynamicField},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );

            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    Code         => 'Operation.InternalError',
                    Message      => "Dynamic Field $DynamicField->{Name} could not be set ($Result->{Message})",
                );
            }
        }
    }

    return $Self->_Success(
        TicketID => $Param{TicketID},
    );
}

1;

=end Internal:




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
