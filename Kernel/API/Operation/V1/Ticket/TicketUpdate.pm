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
    Kernel::System::PerfLog
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
                CustomerUserID => 'some customer user login',                   # optional
                CustomerID    => 'some customer',                               # optional
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

use Data::Dumper;
print STDERR "API::TicketUpdate: ".Dumper(\%Param);

$Self->PerfLogStart('API::TicketUpdate');

    my $PermissionUserID = $Self->{Authorization}->{UserID};
    if ( $Self->{Authorization}->{UserType} eq 'Customer' ) {
        $PermissionUserID = $Kernel::OM->Get('Kernel::Config')->Get('CustomerPanelUserID')
    }

    # isolate ticket hash
    my $Ticket = $Param{Data}->{Ticket};

$Self->PerfLogStart('API::TicketUpdate: check permission');

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

$Self->PerfLogStop('API::TicketUpdate: check permission');

$Self->PerfLogStart('API::TicketUpdate: get ticket');

    # get ticket
    my %TicketData = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID => $Param{Data}->{TicketID}
    );
$Self->PerfLogStop('API::TicketUpdate: get ticket');

$Self->PerfLogStart('API::TicketUpdate: check ticket');

    # check Ticket attribute values
    my $TicketCheck = $Self->_CheckTicket( 
        Ticket => {
            %TicketData,
            %{$Ticket},
        } 
    );

$Self->PerfLogStop('API::TicketUpdate: check ticket');

    if ( !$TicketCheck->{Success} ) {
        return $Self->_Error(
            %{$TicketCheck},
        );
    }

    # everything is ok, let's update the ticket
    my $Result = $Self->_TicketUpdate(
        TicketID => $Param{Data}->{TicketID},
        Ticket   => $Ticket,
        UserID   => $PermissionUserID,
    );

$Self->PerfLogStop('API::TicketUpdate');
$Self->PerfLogOutput();

    return $Result;
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

$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate');

    my $Ticket = $Param{Ticket};

$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: get customer user');

    # get customer information
    # with information will be used to create the ticket if customer is not defined in the
    # database, customer ticket information need to be empty strings
    my %CustomerUserData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
        User => $Ticket->{CustomerUserID},
    );
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: get customer user');

    my $CustomerID = $CustomerUserData{UserCustomerID} || '';

    # use user defined CustomerID if defined
    if ( defined $Ticket->{CustomerID} && $Ticket->{CustomerID} ne '' ) {
        $CustomerID = $Ticket->{CustomerID};
    }

    # get database object
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    my $OwnerID;
    if ( $Ticket->{Owner} && !$Ticket->{OwnerID} ) {
$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: get user (Owner)');
        my %OwnerData = $UserObject->GetUserData(
            User => $Ticket->{Owner},
        );
        $OwnerID = $OwnerData{UserID};
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: get user (Owner)');
    }
    elsif ( defined $Ticket->{OwnerID} ) {
        $OwnerID = $Ticket->{OwnerID};
    }

    my $ResponsibleID;
    if ( $Ticket->{Responsible} && !$Ticket->{ResponsibleID} ) {
$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: get user (Responsible)');
        my %ResponsibleData = $UserObject->GetUserData(
            User => $Ticket->{Responsible},
        );
        $ResponsibleID = $ResponsibleData{UserID};
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: get user (Responsible)');
    }
    elsif ( defined $Ticket->{ResponsibleID} ) {
        $ResponsibleID = $Ticket->{ResponsibleID};
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: get ticket (again)');

    # get current ticket data
    my %TicketData = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
        UserID        => $Param{UserID},
    );
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: get ticket (again)');

    # update ticket parameters
    # update Ticket->Title
    if (
        defined $Ticket->{Title}
        && $Ticket->{Title} ne ''
        && $Ticket->{Title} ne $TicketData{Title}
        )
    {
$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: update title');
        my $Success = $TicketObject->TicketTitleUpdate(
            Title    => $Ticket->{Title},
            TicketID => $Param{TicketID},
            UserID   => $Param{UserID},
        );
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: update title');
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
$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: update queue');
            $Success = $TicketObject->TicketQueueSet(
                QueueID  => $Ticket->{QueueID},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: update queue');
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
$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: update lock');
            $Success = $TicketObject->TicketLockSet(
                LockID   => $Ticket->{LockID},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: update lock');
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
$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: update type');
            $Success = $TicketObject->TicketTypeSet(
                TypeID   => $Ticket->{TypeID},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: update type');
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

$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: get state');
        %StateData = $StateObject->StateGet(
            ID => $StateID,
        );
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: get state');

        # force unlock if state type is close
        if ( $StateData{TypeName} =~ /^close/i ) {

$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: unlock ticket');

            # set lock
            $TicketObject->TicketLockSet(
                TicketID => $Param{TicketID},
                Lock     => 'unlock',
                UserID   => $Param{UserID},
            );
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: unlock ticket');
        }

        # set pending time
        elsif ( $StateData{TypeName} =~ /^pending/i ) {

            # set pending time
            if ( defined $Ticket->{PendingTime} ) {
$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: set pending time');
                my $Success = $TicketObject->TicketPendingTimeSet(
                    UserID   => $Param{UserID},
                    TicketID => $Param{TicketID},
                    String   => $Ticket->{PendingTime},
                );
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: set pending time');

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
$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: update state');
            $Success = $TicketObject->TicketStateSet(
                StateID  => $Ticket->{StateID},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: update state');
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

    # update Ticket->Service (allow removal)
    my $Success;

    # prevent comparison errors on undefined values
    if ( !defined $TicketData{ServiceID} ) {
        $TicketData{ServiceID} = '';
    }
    if ( !defined $Ticket->{ServiceID} ) {
        $Ticket->{ServiceID} = '';
    }

    if ( $Ticket->{ServiceID} ne $TicketData{ServiceID} )
    {
$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: update service');
        $Success = $TicketObject->TicketServiceSet(
            ServiceID => $Ticket->{ServiceID},
            TicketID  => $Param{TicketID},
            UserID    => $Param{UserID},
        );
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: update state');
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

    # prevent comparison errors on undefined values
    if ( !defined $TicketData{SLAID} ) {
        $TicketData{SLAID} = '';
    }
    if ( !defined $Ticket->{SLAID} ) {
        $Ticket->{SLAID} = '';
    }

    if ( $Ticket->{SLAID} ne $TicketData{SLAID} )
    {
$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: update SLA');
        $Success = $TicketObject->TicketSLASet(
            SLAID    => $Ticket->{SLAID},
            TicketID => $Param{TicketID},
            UserID   => $Param{UserID},
        );
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: update SLA');
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

    # update Ticket->CustomerUserID && Ticket->CustomerID
    if ( $Ticket->{CustomerUserID} || $Ticket->{CustomerID} ) {

        # set values to empty if they are not defined
        $TicketData{CustomerUserID} = $TicketData{CustomerUserID} || '';
        $TicketData{CustomerID}     = $TicketData{CustomerID}     || '';
        $Ticket->{CustomerUserID}   = $Ticket->{CustomerUserID}   || '';
        $Ticket->{CustomerID}       = $Ticket->{CustomerID}       || '';

        my $Success;
        if (
            $Ticket->{CustomerUserID} ne $TicketData{CustomerUserID}
            || $Ticket->{CustomerID} ne $TicketData{CustomerID}
            )
        {
            my $CustomerID = $CustomerUserData{UserCustomerID} || '';

            # use user defined CustomerID if defined
            if ( defined $Ticket->{CustomerID} && $Ticket->{CustomerID} ne '' ) {
                $CustomerID = $Ticket->{CustomerID};
            }

$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: update customer');
            $Success = $TicketObject->TicketCustomerSet(
                No       => $CustomerID,
                User     => $Ticket->{CustomerUserID},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: update customer');
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
$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: update priority');
            $Success = $TicketObject->TicketPrioritySet(
                PriorityID => $Ticket->{PriorityID},
                TicketID   => $Param{TicketID},
                UserID     => $Param{UserID},
            );
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: update priority');
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
$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: update owner');
            $Success = $TicketObject->TicketOwnerSet(
                NewUserID => $Ticket->{OwnerID},
                TicketID  => $Param{TicketID},
                UserID    => $Param{UserID},
            );
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: update owner');
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
$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: update responsible');
            $Success = $TicketObject->TicketResponsibleSet(
                NewUserID => $Ticket->{ResponsibleID},
                TicketID  => $Param{TicketID},
                UserID    => $Param{UserID},
            );
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: update responsible');
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

$Self->PerfLogStart('API::TicketUpdate::_TicketUpdate: update dynamic fields');

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
                    Code         => 'Object.UnableToUpdate',
                    Message      => "Dynamic Field $DynamicField->{Name} could not be set ($Result->{Message})",
                );
            }
        }
$Self->PerfLogStop('API::TicketUpdate::_TicketUpdate: update dynamic fields');
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
