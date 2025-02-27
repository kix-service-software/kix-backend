# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::TicketCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use  Kernel::System::EmailParser;

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
        'Ticket' => {
            Type     => 'HASH',
            Required => 1
        },
        'Ticket::Title' => {
            Required => 1
        }
    }
}

=item Run()

perform TicketCreate Operation. This will return the created TicketID.

    my $Result = $OperationObject->Run(
        Data => {
            Ticket => {
                Title           => 'some ticket title',
                ContactID       => '123 or some email',                           # ContactID or some email
                StateID         => 123,                                           # optional
                State           => 'some state name',                             # optional
                PriorityID      => 123,                                           # optional
                Priority        => 'some priority name',                          # optional
                QueueID         => 123,                                           # optional
                Queue           => 'some queue name',                             # optional
                LockID          => 123,                                           # optional
                Lock            => 'some lock name',                              # optional
                TypeID          => 123,                                           # optional
                Type            => 'some type name',                              # optional
                OwnerID         => 123,                                           # optional
                Owner           => 'some user login',                             # optional
                OrganisationID  => 123,                                           # optional
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

                        ChannelID                       => 123,                        # optional
                        Channel                         => 'some channel name',        # optional
                        SenderTypeID                    => 123,                        # optional
                        SenderType                      => 'some sender type name',    # optional
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

    # isolate and trim Ticket parameter
    my $Ticket = $Self->_Trim(
        Data => $Param{Data}->{Ticket}
    );

    # Lock can only be set if OwnerID != 1
    if ( $Ticket->{LockID} && $Ticket->{LockID} == 2 && $Ticket->{OwnerID} && $Ticket->{OwnerID} == 1 ) {
        return $Self->_Error(
            Code    => 'Conflict',
            Message => "Ticket can't be locked if OwnerID is 1!",
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
        Ticket                 => $Ticket,
        UserID                 => $Self->{Authorization}->{UserID},
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

    my $Ticket = $Param{Ticket};

    # fallback for ContactID
    if ( !$Ticket->{ContactID} ) {
        # check if the current user has an assigned contact
        my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
            UserID => $Self->{Authorization}->{UserID}
        );
        if ( !%Contact ) {
            return $Self->_Error(
                Code    => 'Object.UnableToCreate',
                Message => 'No Contact ID or valid Email provided.',
            );
        } else {
            $Ticket->{ContactID} = $Contact{ID};
            $Ticket->{OrganisationID} = $Contact{PrimaryOrganisationID};
        }
    }

    # force owner / responsible if executing user is in customer context
    my $OwnerID;
    my $ResponsibleID;
    if ( $Self->{Authorization}->{UserType} eq 'Agent' ) {
        # get database object
        my $UserObject = $Kernel::OM->Get('User');

        if ( $Ticket->{Owner} && !$Ticket->{OwnerID} ) {
            my %OwnerData = $UserObject->GetUserData(
                User => $Ticket->{Owner},
            );
            $OwnerID = $OwnerData{UserID};
        }
        elsif ( defined $Ticket->{OwnerID} ) {
            $OwnerID = $Ticket->{OwnerID};
        }

        if ( $Ticket->{Responsible} && !$Ticket->{ResponsibleID} ) {
            my %ResponsibleData = $UserObject->GetUserData(
                User => $Ticket->{Responsible},
            );
            $ResponsibleID = $ResponsibleData{UserID};
        }
        elsif ( defined $Ticket->{ResponsibleID} ) {
            $ResponsibleID = $Ticket->{ResponsibleID};
        }
    }
    elsif ( $Self->{Authorization}->{UserType} eq 'Customer' ) {
        $OwnerID = 1;
        $ResponsibleID = 1;
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # create new ticket
    my $TicketID = $TicketObject->TicketCreate(
        %{ $Ticket },
        Title          => $Ticket->{Title},
        QueueID        => $Ticket->{QueueID} || '',
        Queue          => $Ticket->{Queue} || '',
        Lock           => 'unlock',
        TypeID         => $Ticket->{TypeID} || '',
        Type           => $Ticket->{Type} || '',
        StateID        => $Ticket->{StateID} || '',
        State          => $Ticket->{State} || '',
        PriorityID     => $Ticket->{PriorityID} || '',
        Priority       => $Ticket->{Priority} || '',
        OwnerID        => 1,
        OrganisationID => $Ticket->{OrganisationID},
        ContactID      => $Ticket->{ContactID},
        UserID         => $Param{UserID},
    );

    if ( !$TicketID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Ticket could not be created, please contact the system administrator',
        );
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
    my $StateObject = $Kernel::OM->Get('State');

    if ( $Ticket->{StateID} ) {
        $StateID = $Ticket->{StateID};
    }
    else {
        $StateID = $StateObject->StateLookup(
            State => $Ticket->{State},
        );
    }

    if ( !$StateID ) {
        # get default ticket state
        my $DefaultTicketState = $Kernel::OM->Get('Config')->Get('Ticket::State::Default');

        # check if default ticket state exists
        my %AllTicketStates = reverse $StateObject->StateList( UserID => 1);

        if ( $AllTicketStates{$DefaultTicketState} ) {
            $StateID = $AllTicketStates{$DefaultTicketState};
        }
        else {
            if ( $DefaultTicketState ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown default state \"$DefaultTicketState\" in config setting Ticket::State::Default!",
                );
            }
            $StateID = 1;
        }
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

    # set dynamic fields
    if ( IsArrayRefWithData( $Ticket->{DynamicFields} ) ) {

        DYNAMICFIELD:
        foreach my $DynamicField ( @{ $Ticket->{DynamicFields} } ) {
            my $Result = $Self->_SetDynamicFieldValue(
                %{$DynamicField},
                ObjectID   => $TicketID,
                ObjectType => 'Ticket',
                UserID     => $Param{UserID},
            );

            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    Code    => 'Operation.InternalError',
                    Message => "Dynamic Field $DynamicField->{Name} could not be set ($Result->{Message})",
                );
            }
        }
    }

    # create articles
    if ( IsArrayRefWithData( $Ticket->{Articles} ) ) {

        foreach my $Article ( @{ $Ticket->{Articles} } ) {

            my $Result = $Self->ExecOperation(
                OperationType           => 'V1::Ticket::ArticleCreate',
                IgnoreParentPermissions => 1,
                Data                    => {
                    TicketID               => $TicketID,
                    Article                => $Article
                }
            );

            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    %{$Result},
                    )
            }
        }
    }

    return $Self->_Success(
        Code     => 'Object.Created',
        TicketID => 0 + $TicketID,
    );
}

1;

=end Internal:






=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
