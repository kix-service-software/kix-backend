# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::TicketCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::TicketCreate - API Operation backend

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
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::TicketCreate');

    return $Self;
}

=item Run()

perform TicketCreate Operation. This will return the created TicketID.

    my $Result = $OperationObject->Run(
        Data => {
            Ticket => {
                Title           => 'some ticket title',
                CustomerUser    => 'some customer user login',
                StateID         => 123,                                           # StateID or State is required
                State           => 'some state name',
                PriorityID      => 123,                                           # PriorityID or Priority is required
                Priority        => 'some priority name',
                QueueID         => 123,                                           # QueueID or Queue is required
                Queue           => 'some queue name',

                LockID          => 123,                                           # optional
                Lock            => 'some lock name',                              # optional
                TypeID          => 123,                                           # optional
                Type            => 'some type name',                              # optional
                ServiceID       => 123,                                           # optional
                Service         => 'some service name',                           # optional
                SLAID           => 123,                                           # optional
                SLA             => 'some SLA name',                               # optional
                OwnerID         => 123,                                           # optional
                Owner           => 'some user login',                             # optional
                ResponsibleID   => 123,                                           # optional
                Responsible     => 'some user login',                             # optional
                PendingTime     => '2011-12-03 23:05:00',                         # optional
                Articles        => [                                              # optional
                    {
                        Subject                         => 'some subject',
                        Body                            => 'some body'
                        ContentType                     => 'some content type',        # ContentType or MimeType and Charset is requieed
                        MimeType                        => 'some mime type',
                        Charset                         => 'some charset',

                        ArticleTypeID                   => 123,                        # optional
                        ArticleType                     => 'some article type name',   # optional
                        SenderTypeID                    => 123,                        # optional
                        SenderType                      => 'some sender type name',    # optional
                        AutoResponseType                => 'some auto response type',  # optional
                        From                            => 'some from string',         # optional
                        HistoryType                     => 'some history type',        # optional
                        HistoryComment                  => 'Some  history comment',    # optional
                        TimeUnit                        => 123,                        # optional
                        NoAgentNotify                   => 1,                          # optional
                        ForceNotificationToUserID       => [1, 2, 3]                   # optional
                        ExcludeNotificationToUserID     => [1, 2, 3]                   # optional
                        ExcludeMuteNotificationToUserID => [1, 2, 3]                   # optional
                        DynamicFields => [                                             # optional
                            {
                                Name   => 'some name',                                          
                                Value  => $Value,                                      # value type depends on the dynamic field
                            },
                            # ...
                        ],
                        Attachments => [
                            {
                                Content     => 'content'                               # base64 encoded
                                ContentType => 'some content type'
                                Filename    => 'some fine name'
                            },
                            # ...
                        ],                    
                    },
                    # ...
                ]
                DynamicFields => [                                                     # optional
                    {
                        Name   => 'some name',                                          
                        Value  => $Value,                                              # value type depends on the dynamic field
                    },
                    # ...
                ],
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        ErrorMessage    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            TicketID    => 123,                     # ID of new ticket
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
            'Ticket' => {
                Type     => 'HASH',
                Required => 1
            },
            'Ticket::Title' => {
                Required => 1
            },
            'Ticket::CustomerUser' => {
                Required => 1
            },
            'Ticket::State' => {
                RequiredIfNot => [ 'Ticket::StateID' ],
            },
            'Ticket::Priority' => {
                RequiredIfNot => [ 'Ticket::PriorityID' ],
            },
            'Ticket::Queue' => {
                RequiredIfNot => [ 'Ticket::QueueID' ],
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

    # check create permissions
    my $Permission = $Self->CheckCreatePermission(
        Ticket   => $Ticket,
        UserID   => $PermissionUserID,
        UserType => $Self->{Authorization}->{UserType},
    );

    if ( !$Permission ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to create tickets in given queue!",
        );
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

    # everything is ok, let's create the ticket
    return $Self->_TicketCreate(
        Ticket => $Ticket,
        UserID => $PermissionUserID,
    );
}

=begin Internal:

=item _TicketCreate()

creates a ticket with its articles and dynamic fields and attachments if specified.

    my $Response = $OperationObject->_TicketCreate(
        Ticket           => { },                # all ticket parameters
        UserID           => 123,
    );

    returns:

    $Response = {
        Success => 1,                               # if everething is OK
        Data => {
            TicketID     => 123,
        }
    }

    $Response = {
        Success      => 0,                         # if unexpected error
        Code         => '...'
        Message      => '...',
    }

=cut

sub _TicketCreate {
    my ( $Self, %Param ) = @_;

    my $Ticket           = $Param{Ticket};

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

    # create new ticket
    my $TicketID = $TicketObject->TicketCreate(
        Title        => $Ticket->{Title},
        QueueID      => $Ticket->{QueueID} || '',
        Queue        => $Ticket->{Queue} || '',
        Lock         => 'unlock',
        TypeID       => $Ticket->{TypeID} || '',
        Type         => $Ticket->{Type} || '',
        ServiceID    => $Ticket->{ServiceID} || '',
        Service      => $Ticket->{Service} || '',
        SLAID        => $Ticket->{SLAID} || '',
        SLA          => $Ticket->{SLA} || '',
        StateID      => $Ticket->{StateID} || '',
        State        => $Ticket->{State} || '',
        PriorityID   => $Ticket->{PriorityID} || '',
        Priority     => $Ticket->{Priority} || '',
        OwnerID      => 1,
        CustomerNo   => $CustomerID,
        CustomerUser => $CustomerUserData{UserLogin} || '',
        UserID       => $Param{UserID},
    );

    if ( !$TicketID ) {
        return $Self->_Error(
            Code         => 'Object.UnableToCreate',
            Message      => 'Ticket could not be created, please contact the system administrator',
        );
    }

    # set lock if specified
    if ( $Ticket->{Lock} || $Ticket->{LockID} ) {
        $TicketObject->TicketLockSet(
            TicketID => $TicketID,
            LockID   => $Ticket->{LockID} || '',
            Lock     => $Ticket->{Lock} || '',
            UserID   => $Param{UserID},
        );
    }

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
            TicketID => $TicketID,
            Lock     => 'unlock',
            UserID   => $Param{UserID},
        );
    }

    # set pending time
    elsif ( $StateData{TypeName} =~ /^pending/i ) {

        # set pending time
        if ( defined $Ticket->{PendingTime} ) {
            $TicketObject->TicketPendingTimeSet(
                UserID   => $Param{UserID},
                TicketID => $TicketID,
                String   => $Ticket->{PendingTime},
            );
        }
    }

    # set owner (if owner or owner id is given)
    if ($OwnerID) {
        $TicketObject->TicketOwnerSet(
            TicketID  => $TicketID,
            NewUserID => $OwnerID,
            UserID    => $Param{UserID},
        );

        # set lock if no lock was defined
        if ( !$Ticket->{Lock} && !$Ticket->{LockID} ) {
            $TicketObject->TicketLockSet(
                TicketID => $TicketID,
                Lock     => 'lock',
                UserID   => $Param{UserID},
            );
        }
    }

    # else set owner to current agent but do not lock it
    else {
        $TicketObject->TicketOwnerSet(
            TicketID           => $TicketID,
            NewUserID          => $Param{UserID},
            SendNoNotification => 1,
            UserID             => $Param{UserID},
        );
    }

    # set responsible
    if ($ResponsibleID) {
        $TicketObject->TicketResponsibleSet(
            TicketID  => $TicketID,
            NewUserID => $ResponsibleID,
            UserID    => $Param{UserID},
        );
    }

    # set dynamic fields
    if ( IsArrayRefWithData($Ticket->{DynamicFields}) ) {

        DYNAMICFIELD:
        foreach my $DynamicField ( @{$Ticket->{DynamicFields}} ) {
            next DYNAMICFIELD if !$Self->ValidateDynamicFieldObjectType( %{$DynamicField} );

            my $Result = $Self->SetDynamicFieldValue(
                %{$DynamicField},
                TicketID => $TicketID,
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

    # create articles
    if ( IsArrayRefWithData($Ticket->{Articles}) ) {

        foreach my $Article ( @{$Ticket->{Articles}} ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::Ticket::ArticleCreate',
                Data          => {
                    TicketID => $TicketID,
                    Article  => $Article,
                }
            );
            
            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    ${$Result},
                )
            }
        }
    }

    # create checklist
    if ( IsHashRefWithData($Ticket->{Checklist}) ) {

        foreach my $ChecklistItem ( @{$Ticket->{Checklist}} ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::Ticket::TicketChecklistCreate',
                Data          => {
                    TicketID      => $TicketID,
                    ChecklistItem => ChecklistItem,
                }
            );
            
            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    ${$Result},
                )
            }
        }
    }

    return $Self->_Success(
        Code     => 'Object.Created',
        TicketID => $TicketID,
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
