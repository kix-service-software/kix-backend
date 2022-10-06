# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::NotificationEvent;

use strict;
use warnings;

use List::Util qw(first);
use Time::HiRes qw(time);

use base qw(Kernel::System::AsynchronousExecutor);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Contact',
    'DB',
    'DynamicField',
    'DynamicField::Backend',
    'Email',
    'HTMLUtils',
    'JSON',
    'Log',
    'NotificationEvent',
    'Role',
    'Queue',
    'SystemAddress',
    'TemplateGenerator',
    'Ticket',
    'Time',
    'User',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

my $StartTime = Time::HiRes::time();

    # check needed stuff
    for my $Needed (qw(Event Data Config UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    if ( !$Param{Data}->{TicketID} && !IsArrayRefWithData($Param{Data}->{TicketList}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need TicketID or TicketList in Data!',
        );
        return;
    }

    # get objects
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # return if no notification is active
    return 1 if $TicketObject->{SendNoNotification};

    if ( $Param{Data}->{TicketID} ) {
        # return if no ticket exists (e. g. it got deleted)
        my $TicketNumber = $TicketObject->TicketNumberLookup(
            TicketID => $Param{Data}->{TicketID},
            UserID   => $Param{UserID},
        );

        return 1 if !$TicketNumber;
    }

    my $Result;

    if ( !$ENV{IsDaemon} && $Kernel::OM->Get('Config')->Get('TicketNotification::SendAsynchronously') ) {
        my $MaximumParallelInstances = $Kernel::OM->Get('Config')->Get('TicketNotification::SendAsynchronously::MaximumParallelInstances') || 0;
        my $Result = $Self->AsyncCall(
            FunctionName             => '_Run',
            FunctionParams           => \%Param,
            MaximumParallelInstances => $MaximumParallelInstances
        );
        if ( !$Result ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Could not schedule asynchronous NotificationEvent execution!",
            );
        }
    }
    else {
        $Result = $Self->_Run(
            %Param
        );
    }

    return $Result;
}

sub _Run {
    my ( $Self, %Param ) = @_;

my $StartTime = Time::HiRes::time();

    my @TicketList = IsArrayRef($Param{Data}->{TicketList}) ? @{$Param{Data}->{TicketList}} : ( { %Param } );

    TICKET:
    foreach my $Ticket ( @TicketList ) {
        $Self->_HandleTicket(
            Event  => $Param{Event}, 
            Data   => $Ticket,
            UserID => $Param{UserID},
        );
    }

    $Kernel::OM->Get('Log')->Log(
        Priority => 'info',
        Message  => sprintf "NotificationEvent::_Run (%i tickets): %i ms\n", (scalar @TicketList), (Time::HiRes::time() - $StartTime) * 1000,
    );

    return 1;
}

sub _HandleTicket {
    my ( $Self, %Param ) = @_;

my $StartTime = Time::HiRes::time();
    # get notification event object
    my $NotificationEventObject = $Kernel::OM->Get('NotificationEvent');

    # get objects
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # check if event is affected
    my @IDs;
    if ( IsArrayRef($Self->{Cache}->{NotificationIDs}->{$Param{Event}}) ) {
        @IDs = @{$Self->{Cache}->{NotificationIDs}->{$Param{Event}}};
    }
    else {
        @IDs = $NotificationEventObject->NotificationEventCheck(
            Event => $Param{Event},
        );
        $Self->{Cache}->{NotificationIDs}->{$Param{Event}} = \@IDs;
    }

    # return if no notification for event exists
    return 1 if !@IDs;

    # get ticket attribute matches
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{Data}->{TicketID},
        UserID        => $Param{UserID},
        DynamicFields => 1,
    );

    $Kernel::OM->Get('Log')->Log(
        Priority => 'info',
        Message  => sprintf "NotificationEvent::_HandleTicket (TicketID: $Param{Data}->{TicketID}) (Preparation): %i ms\n", (Time::HiRes::time() - $StartTime) * 1000,
    );

    NOTIFICATION:
    for my $ID (@IDs) {

my $StartTime = Time::HiRes::time();
        my %Notification = $NotificationEventObject->NotificationGet(
            ID => $ID,
        );

        # verify ticket and article conditions
        my $PassFilter = $Self->_NotificationFilter(
            %Param,
            Ticket       => \%Ticket,
            Notification => \%Notification,
        );
        $Kernel::OM->Get('Log')->Log(
            Priority => 'info',
            Message  => sprintf "   NotificationEvent::_HandleTicket (TicketID: $Param{Data}->{TicketID}) (_NotificationFilter \"$Notification{Name}\"): Result:=$PassFilter\n",
        );
        next NOTIFICATION if !$PassFilter;

        # add attachments only on ArticleCreate or ArticleSend event
        my @Attachments;
        if (
            ( ( $Param{Event} eq 'ArticleCreate' ) || ( $Param{Event} eq 'ArticleSend' ) )
            && $Param{Data}->{ArticleID}
            )
        {

            # add attachments to notification
            if ( $Notification{Data}->{ArticleAttachmentInclude}->[0] ) {

                # get article, it is needed for the correct behavior of the
                # StripPlainBodyAsAttachment flag into the ArticleAttachmentIndex function
                my %Article = $Kernel::OM->Get('Ticket')->ArticleGet(
                    ArticleID     => $Param{Data}->{ArticleID},
                    UserID        => $Param{UserID},
                    DynamicFields => 0,
                );

                my %Index = $TicketObject->ArticleAttachmentIndex(
                    ArticleID                  => $Param{Data}->{ArticleID},
                    Article                    => \%Article,
                    UserID                     => $Param{UserID},
                    StripPlainBodyAsAttachment => 3,
                );
                if (%Index) {
                    FILE_ID:
                    for my $FileID ( sort keys %Index ) {
                        my %Attachment = $TicketObject->ArticleAttachment(
                            ArticleID => $Param{Data}->{ArticleID},
                            FileID    => $FileID,
                            UserID    => $Param{UserID},
                        );
                        next FILE_ID if !%Attachment;

                        # KIX4OTRS-capeIT
                        # remove HTML-Attachments (HTML-Emails)
                        next
                            if (
                            $Index{$FileID}->{Filename} =~ /^file-[12]$/
                            && $Index{$FileID}->{ContentType} =~ /text\/html/i
                            );

                        # EO KIX4OTRS-capeIT

                        push @Attachments, \%Attachment;
                    }
                }
            }
        }

        # get recipients
        my @RecipientUsers = $Self->_RecipientsGet(
            %Param,
            Ticket       => \%Ticket,
            Notification => \%Notification,
        );

        my @NotificationBundle;

        # parse all notification tags for each user
        for my $Recipient (@RecipientUsers) {

            my $UserNotificationTransport = $Kernel::OM->Get('JSON')->Decode(
                Data => $Recipient->{Preferences}->{NotificationTransport},
            );

            push @NotificationBundle, {
                Recipient                      => $Recipient,
                Notification                   => \%Notification,
                RecipientNotificationTransport => $UserNotificationTransport,
            };
        }

        # get config object
        my $ConfigObject = $Kernel::OM->Get('Config');

        # get notification transport config
        my %TransportConfig = %{ $ConfigObject->Get('Notification::Transport') || {} };

        # remember already sent agent notifications
        my %AlreadySent;

        # loop over transports for each notification
        TRANSPORT:
        for my $Transport ( sort keys %TransportConfig ) {

            # only configured transports for this notification
            if ( !grep { $_ eq $Transport } @{ $Notification{Data}->{Transports} } ) {
                next TRANSPORT;
            }

            next TRANSPORT if !IsHashRefWithData( $TransportConfig{$Transport} );
            next TRANSPORT if !$TransportConfig{$Transport}->{Module};

            # get transport object
            my $TransportObject;
            eval {
                $TransportObject = $Kernel::OM->Get( $TransportConfig{$Transport}->{Module} );
            };

            if ( !$TransportObject ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Could not create a new $TransportConfig{$Transport}->{Module} object!",
                );

                next TRANSPORT;
            }

            if ( ref $TransportObject ne $TransportConfig{$Transport}->{Module} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "$TransportConfig{$Transport}->{Module} object is invalid",
                );

                next TRANSPORT;
            }

            # check if transport is usable
            next TRANSPORT if !$TransportObject->IsUsable();

            BUNDLE:
            for my $Bundle (@NotificationBundle) {

                my $UserPreference = "Notification-$Notification{ID}-$Transport";

                # check if agent should get the notification
                my $AgentSendNotification = 0;
                if ( defined $Bundle->{RecipientNotificationTransport}->{$UserPreference} ) {
                    $AgentSendNotification = $Bundle->{RecipientNotificationTransport}->{$UserPreference};
                }
                elsif ( grep { $_ eq $Transport } @{ $Notification{Data}->{AgentEnabledByDefault} } ) {
                    $AgentSendNotification = 1;
                }
                elsif (
                    !IsArrayRefWithData( $Notification{Data}->{VisibleForAgent} )
                    || (
                        defined $Notification{Data}->{VisibleForAgent}->[0]
                        && !$Notification{Data}->{VisibleForAgent}->[0]
                    )
                    )
                {
                    $AgentSendNotification = 1;
                }

                # skip sending the notification if the agent has disabled it in its preferences
                if (
                    IsArrayRefWithData( $Notification{Data}->{VisibleForAgent} )
                    && $Notification{Data}->{VisibleForAgent}->[0]
                    && $Bundle->{Recipient}->{Type} eq 'Agent'
                    && !$AgentSendNotification
                    )
                {
                    next BUNDLE;
                }

                # Check if notification should not be send to the customer.
                if (
                    $Bundle->{Recipient}->{Type} eq 'Customer'
                    && $ConfigObject->Get('CustomerNotifyJustToRealCustomer')
                    )
                {
                    # No UserID means it's not a mapped customer.
                    next BUNDLE if !$Bundle->{Recipient}->{UserID};
                }

                my $Success = $Self->_SendRecipientNotification(
                    TicketID              => $Param{Data}->{TicketID},
                    Notification          => $Bundle->{Notification},
                    CustomerMessageParams => $Param{Data}->{CustomerMessageParams} || {},
                    Recipient             => $Bundle->{Recipient},
                    Event                 => $Param{Event},
                    Attachments           => \@Attachments,
                    Transport             => $Transport,
                    TransportObject       => $TransportObject,
                    UserID                => $Param{UserID},
                );

                # remember to have sent
                if ( $Bundle->{Recipient}->{UserID} ) {
                    $AlreadySent{ $Bundle->{Recipient}->{UserID} } = 1;
                }
            }

            # get special recipients specific for each transport
            my @TransportRecipients = $TransportObject->GetTransportRecipients(
                Notification => \%Notification,
                TicketID     => $Param{Data}->{TicketID},
            );

            next TRANSPORT if !@TransportRecipients;

            RECIPIENT:
            for my $Recipient (@TransportRecipients) {

                my $Success = $Self->_SendRecipientNotification(
                    TicketID              => $Param{Data}->{TicketID},
                    Notification          => \%Notification,
                    CustomerMessageParams => $Param{Data}->{CustomerMessageParams} || {},
                    Recipient             => $Recipient,
                    Event                 => $Param{Event},
                    Attachments           => \@Attachments,
                    Transport             => $Transport,
                    TransportObject       => $TransportObject,
                    UserID                => $Param{UserID},
                );
            }
        }

        $Kernel::OM->Get('Log')->Log(
            Priority => 'info',
            Message  => sprintf "NotificationEvent::_HandleTicket (TicketID: $Param{Data}->{TicketID}) (Notification \"$Notification{Name}\"): %i ms\n", (Time::HiRes::time() - $StartTime) * 1000,
        );
    }

    $Kernel::OM->Get('Log')->Log(
        Priority => 'info',
        Message  => sprintf "NotificationEvent::_HandleTicket (TicketID: $Param{Data}->{TicketID}): %i ms\n", (Time::HiRes::time() - $StartTime) * 1000,
    );

    return 1;
}

sub _NotificationFilter {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Data Notification)) {
        return if !$Param{$Needed};
    }

    my $Filter = $Param{Notification}->{Filter};

    # create or extend the filter with the ArticleID or TicketID
    if ( $Param{Data}->{ArticleID} ) {
        # add ArticleID to filter
        $Filter //= {};
        $Filter->{AND} //= [];
        push @{$Filter->{AND}}, {
            Field    => 'ArticleID',
            Operator => 'EQ',
            Value    => $Param{Data}->{ArticleID}
        };
    }
    elsif ( $Param{Ticket}->{TicketID} ) {
        # add TicketID to filter
        $Filter //= {};
        $Filter->{AND} //= [];
        push @{$Filter->{AND}}, {
            Field    => 'TicketID',
            Operator => 'EQ',
            Value    => $Param{Data}->{TicketID}
        };
    }

    # do the search
    my @TicketIDs = $Kernel::OM->Get('Ticket')->TicketSearch(
        Result => 'ARRAY',
        Search => $Filter,
        Limit  => 1,
    );

    return @TicketIDs && $TicketIDs[0] == $Param{Data}->{TicketID};
}

sub _RecipientsGet {
    my ( $Self, %Param ) = @_;

my $StartTime = Time::HiRes::time();
    # check needed params
    for my $Needed (qw(Ticket Notification)) {
        return if !$Param{$Needed};
    }

    # set local values
    my %Notification = %{ $Param{Notification} };
    my %Ticket       = %{ $Param{Ticket} };

    # get needed objects
    my $TicketObject = $Kernel::OM->Get('Ticket');
    my $ConfigObject = $Kernel::OM->Get('Config');

    my @RecipientUserIDs;
    my @RecipientUsers;

    # add pre-calculated recipient
    if ( IsArrayRefWithData( $Param{Data}->{Recipients} ) ) {
        push @RecipientUserIDs, @{ $Param{Data}->{Recipients} };
    }

    # remember pre-calculated user recipients for later comparisons
    my %PrecalculatedUserIDs = map { $_ => 1 } @RecipientUserIDs;

    # get recipients by Recipients
    if ( $Notification{Data}->{Recipients} ) {

        # get needed objects
        my $QueueObject        = $Kernel::OM->Get('Queue');
        my $ContactObject = $Kernel::OM->Get('Contact');

        RECIPIENT:
        for my $Recipient ( @{ $Notification{Data}->{Recipients} } ) {

            if (
                $Recipient
                # KIX4OTRS-capeIT
                =~ /^Agent(Owner|Responsible|Watcher|ReadPermissions|WritePermissions|MyQueues|MyServices|MyQueuesMyServices|)$/
                # EO KIX4OTRS-capeIT
                )
            {

                if ( $Recipient eq 'AgentOwner' ) {
                    push @{ $Notification{Data}->{RecipientAgents} }, $Ticket{OwnerID};
                }
                elsif ( $Recipient eq 'AgentResponsible' ) {

                    # add the responsible agent to the notification list
                    if ( $ConfigObject->Get('Ticket::Responsible') && $Ticket{ResponsibleID} ) {

                        push @{ $Notification{Data}->{RecipientAgents} },
                            $Ticket{ResponsibleID};
                    }
                }
                elsif ( $Recipient eq 'AgentWatcher' ) {

                    # its checked on WatcherList function
                    push @{ $Notification{Data}->{RecipientAgents} }, map { $_->{UserID} } $Kernel::OM->Get('Watcher')->WatcherList(
                        Object   => 'Ticket',
                        ObjectID => $Param{Data}->{TicketID},
                    );
                }
                elsif ( $Recipient eq 'AgentReadPermissions' ) {

                    # check each valid user if he has READ permission on /tickets
                    my @UserIDs;
                    my %UserList;
                    if ( IsHashRef($Self->{Cache}->{UserList}) ) {
                        %UserList = %{$Self->{Cache}->{UserList}};
                    }
                    else {
                        %UserList = $Kernel::OM->Get('User')->UserList(
                            Valid => 1,
                            Short => 1,
                        );
                        $Self->{Cache}->{UserList} = \%UserList;
                    }
                    my $Resource = '/tickets/' . $Ticket{TicketID};
                    foreach my $UserID ( sort keys %UserList ) {
                        my $Granted;
                        if ( exists $Self->{Cache}->{UserPermission}->{$UserID}->{$Resource}->{READ} ) {
                            $Granted = $Self->{Cache}->{UserPermission}->{$UserID}->{$Resource}->{READ};
                        }
                        else {
                            $Granted = $Kernel::OM->Get('User')->CheckResourcePermission(
                                UserID              => $UserID,
                                Target              => $Resource,
                                UsageContext        => 'Agent',
                                RequestedPermission => 'READ'
                            );
                            $Self->{Cache}->{UserPermission}->{$UserID}->{$Resource}->{READ} = $Granted;
                        }
                        if ( $Granted ) {
                            push @UserIDs, $UserID;
                        }
                    }

                    push @{ $Notification{Data}->{RecipientAgents} }, @UserIDs;
                }
                elsif ( $Recipient eq 'AgentWritePermissions' ) {

                    # check each valid user if he has UPDATE permission on /tickets
                    my @UserIDs;
                    my %UserList;
                    if ( IsHashRef($Self->{Cache}->{UserList}) ) {
                        %UserList = %{$Self->{Cache}->{UserList}};
                    }
                    else {
                        %UserList = $Kernel::OM->Get('User')->UserList(
                            Valid => 1,
                            Short => 1,
                        );
                        $Self->{Cache}->{UserList} = \%UserList;
                    }
                    my $Resource = '/tickets/' . $Ticket{TicketID};
                    foreach my $UserID ( sort keys %UserList ) {
                        my $Granted;
                        if ( exists $Self->{Cache}->{UserPermission}->{$UserID}->{$Resource}->{UPDATE} ) {
                            $Granted = $Self->{Cache}->{UserPermission}->{$UserID}->{$Resource}->{UPDATE};
                        }
                        else {
                            $Granted = $Kernel::OM->Get('User')->CheckResourcePermission(
                                UserID              => $UserID,
                                Target              => $Resource,
                                UsageContext        => 'Agent',
                                RequestedPermission => 'UPDATE'
                            );
                            $Self->{Cache}->{UserPermission}->{$UserID}->{$Resource}->{UPDATE} = $Granted;
                        }
                        if ( $Granted ) {
                            push @UserIDs, $UserID;
                        }
                    }
                    foreach my $UserID ( sort keys %UserList ) {
                        my ($Granted) = $Kernel::OM->Get('User')->CheckResourcePermission(
                            UserID              => $UserID,
                            Target              => '/tickets/' . $Ticket{TicketID},
                            UsageContext        => 'Agent',
                            RequestedPermission => 'UPDATE'
                        );
                        if ( $Granted ) {
                            push @UserIDs, $UserID;
                        }
                    }

                    push @{ $Notification{Data}->{RecipientAgents} }, @UserIDs;
                }
                elsif ( $Recipient eq 'AgentMyQueues' ) {

                    my @UserIDs = $Self->_GetSubscribedUserIDsByQueueID(
                        QueueID => $Ticket{QueueID}
                    );
                    push @{ $Notification{Data}->{RecipientAgents} }, @UserIDs;
                }
                elsif ( $Recipient eq 'AgentMyServices' ) {

                    my @UserIDs = $Self->_GetSubscribedUserIDsByServiceID(
                        ServiceID => $Ticket{ServiceID}
                    );
                    push @{ $Notification{Data}->{RecipientAgents} }, @UserIDs;
                }
                elsif ( $Recipient eq 'AgentMyQueuesMyServices' ) {

                    # get subscribed users
                    my @UserIDs = $Self->_GetSubscribedUserIDsByQueueID(
                        QueueID => $Ticket{QueueID}
                    );
                    my %MyQueuesUserIDs = map { $_ => 1 } @UserIDs;

                    @UserIDs = $Self->_GetSubscribedUserIDsByServiceID(
                        ServiceID => $Ticket{ServiceID}
                    );
                    my %MyServicesUserIDs = map { $_ => 1 } @UserIDs;

                    # combine both subscribed users list (this will also remove duplicates)
                    my %SubscribedUserIDs = ( %MyQueuesUserIDs, %MyServicesUserIDs );

                    for my $UserID ( sort keys %SubscribedUserIDs ) {
                        if ( !$MyQueuesUserIDs{$UserID} || !$MyServicesUserIDs{$UserID} ) {
                            delete $SubscribedUserIDs{$UserID};
                        }
                    }

                    @UserIDs = sort keys %SubscribedUserIDs;

                    push @{ $Notification{Data}->{RecipientAgents} }, @UserIDs;
                }
            }

            elsif ( $Recipient eq 'Customer' ) {

                # get old article for quoting
                my %Article = $TicketObject->ArticleLastCustomerArticle(
                    TicketID      => $Param{Data}->{TicketID},
                    DynamicFields => 0,
                );

                # get the raw ticket data
                my %Ticket = $TicketObject->TicketGet(
                    TicketID      => $Param{Data}->{TicketID},
                    DynamicFields => 0,
                );

                my %Recipient;

                # Check if we actually do have an article
                if ( defined $Article{SenderType} ) {
                    if ( $Article{SenderType} eq 'external' ) {
                        $Recipient{Email} = $Article{From};
                    }
                    else {
                        $Recipient{Email} = $Article{To};
                    }
                }
                $Recipient{Type} = 'Customer';

                # check if customer notifications should be send
                if (
                    $ConfigObject->Get('CustomerNotifyJustToRealCustomer')
                    && !$Ticket{ContactID}
                    )
                {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'info',
                        Message  => 'Send no customer notification because no customer is set!',
                    );
                    next RECIPIENT;
                }

                # get language and send recipient
                $Recipient{Language} = $ConfigObject->Get('DefaultLanguage') || 'en';

                if ( $Ticket{ContactID} ) {

                    my %Contact = $ContactObject->ContactGet(
                        ID => $Ticket{ContactID},
                    );

                    # join Recipient data with Contact data
                    %Recipient = ( %Recipient, %Contact );

                    # get user language
                    if ( $Contact{Language} ) {
                        $Recipient{Language} = $Contact{Language};
                    }

                    $Recipient{Realname} = $Contact{Firstname}.' '.$Contact{Lastname};
                }

                if ( !$Recipient{Realname} ) {
                    $Recipient{Realname} = $Article{From} || '';
                    $Recipient{Realname} =~ s/<.*>|\(.*\)|\"|;|,//g;
                    $Recipient{Realname} =~ s/( $)|(  $)//g;
                }

                push @RecipientUsers, \%Recipient;
            }
        }
    }

    # add recipient agents
    if ( IsArrayRefWithData( $Notification{Data}->{RecipientAgents} ) ) {
        push @RecipientUserIDs, @{ $Notification{Data}->{RecipientAgents} };
    }

    # hash to keep track which agents are already receiving this notification
    my %AgentUsed = map { $_ => 1 } @RecipientUserIDs;

    # get recipients by RecipientRoles
    if ( $Notification{Data}->{RecipientRoles} ) {

        RECIPIENT:
        for my $RoleID ( @{ $Notification{Data}->{RecipientRoles} } ) {

            my @RoleMemberList = $Kernel::OM->Get('Role')->RoleUserList(
                RoleID => $RoleID,
            );

            ROLEMEMBER:
            for my $UserID ( sort @RoleMemberList ) {

                next ROLEMEMBER if $UserID == 1;
                next ROLEMEMBER if $AgentUsed{$UserID};

                $AgentUsed{$UserID} = 1;

                push @RecipientUserIDs, $UserID;
            }
        }
    }

    # get needed objects
    my $UserObject = $Kernel::OM->Get('User');

    my %SkipRecipients;
    if ( IsArrayRefWithData( $Param{Data}->{SkipRecipients} ) ) {
        %SkipRecipients = map { $_ => 1 } @{ $Param{Data}->{SkipRecipients} };
    }

    # agent 1 should not receive notifications
    $SkipRecipients{'1'} = 1;

    # remove recipients should not receive a notification
    @RecipientUserIDs = grep { !$SkipRecipients{$_} } @RecipientUserIDs;

    # get valid users list
    my %ValidUsersList = $UserObject->UserList(
        Type          => 'Short',
        Valid         => 1,
        NoOutOfOffice => 0,
    );

    # remove invalid users
    @RecipientUserIDs = grep { $ValidUsersList{$_} } @RecipientUserIDs;

    # remove duplicated
    my %TempRecipientUserIDs = map { $_ => 1 } @RecipientUserIDs;
    @RecipientUserIDs = sort keys %TempRecipientUserIDs;

    # get time object
    my $TimeObject = $Kernel::OM->Get('Time');

    # get current time-stamp
    my $Time = $TimeObject->SystemTime();

    # get all data for recipients as they should be needed by all notification transports
    RECIPIENT:
    for my $UserID (@RecipientUserIDs) {

        my %User = $UserObject->GetUserData(
            UserID => $UserID,
            Valid  => 1,
        );
        next RECIPIENT if !%User;

        # check if the notification needs to be sent just one time per day
        if (
            IsArrayRefWithData($Notification{Data}->{OncePerDay})
            && $Notification{Data}->{OncePerDay}->[0]
            && $User{UserLogin}
        ) {

            # get time object
            my $TimeObject = $Kernel::OM->Get('Time');

            # get current date
            my ( $CurrSec, $CurrMin, $CurrHour, $CurrDay, $CurrMonth, $CurrYear, $CurrWeekDay ) = $TimeObject->SystemTime2Date(
                SystemTime => $TimeObject->SystemTime()
            );

            # get ticket history
            my @HistoryLines = $TicketObject->HistoryGet(
                TicketID      => $Param{Data}->{TicketID},
                HistoryType   => 'SendAgentNotification',
                Name          => "\%\%$Notification{Name}\%\%$User{UserLogin}\%\%Email",      # we use a fixed Email here
                MinCreateTime => "$CurrYear-$CurrMonth-$CurrDay 00:00:00",
                SortReverse   => 1,
                UserID        => $Param{UserID},
                Limit         => 1,
            );

            # do not send the notification if it has been sent already today
            return if @HistoryLines;
        }

        # skip user that triggers the event (it should not be notified) but only if it is not
        #   a pre-calculated recipient
        if (
            !$ConfigObject->Get('AgentSelfNotifyOnAction')
            && $User{UserID} == $Param{UserID}
            && !$PrecalculatedUserIDs{ $Param{UserID} }
            )
        {
            next RECIPIENT;
        }

        # skip users out of the office if configured
        if ( !$Notification{Data}->{SendOnOutOfOffice} && $User{Preferences}->{OutOfOffice} ) {
            my $Start = sprintf(
                "%04d-%02d-%02d 00:00:00",
                $User{Preferences}->{OutOfOfficeStartYear}, $User{Preferences}->{OutOfOfficeStartMonth},
                $User{Preferences}->{OutOfOfficeStartDay}
            );
            my $TimeStart = $TimeObject->TimeStamp2SystemTime(
                String => $Start,
            );
            my $End = sprintf(
                "%04d-%02d-%02d 23:59:59",
                $User{Preferences}->{OutOfOfficeEndYear}, $User{Preferences}->{OutOfOfficeEndMonth},
                $User{Preferences}->{OutOfOfficeEndDay}
            );
            my $TimeEnd = $TimeObject->TimeStamp2SystemTime(
                String => $End,
            );

            next RECIPIENT if $TimeStart < $Time && $TimeEnd > $Time;
        }

        my $Granted;
        my $Resource = '/tickets/' . $Ticket{TicketID};
        if ( exists $Self->{Cache}->{UserPermission}->{$User{UserID}}->{$Resource}->{READ} ) {
            $Granted = $Self->{Cache}->{UserPermission}->{$User{UserID}}->{$Resource}->{READ};
        }
        else {
            # skip users with out READ permissions
            $Granted = $UserObject->CheckResourcePermission(
                UserID              => $User{UserID},
                Target              => $Resource,
                UsageContext        => 'Agent',
                RequestedPermission => 'READ'
            );
        }
        next RECIPIENT if !$Granted;

        # skip PostMasterUserID
        my $PostmasterUserID = $ConfigObject->Get('PostmasterUserID') || 1;
        next RECIPIENT if $User{UserID} == $PostmasterUserID;

        $User{Type} = 'Agent';

        push @RecipientUsers, \%User;
    }

    $Kernel::OM->Get('Log')->Log(
        Priority => 'info',
        Message  => sprintf "   NotificationEvent::_RecipientsGet: %i ms\n", (Time::HiRes::time() - $StartTime) * 1000,
    );

    return @RecipientUsers;
}

sub _SendRecipientNotification {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID Notification Recipient Event Transport TransportObject)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
        }
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    my $TransportObject = $Param{TransportObject};

my $StartTime = Time::HiRes::time();
    my %ReplacedNotification = $Kernel::OM->Get('TemplateGenerator')->NotificationEvent(
        TicketID              => $Param{TicketID},
        Recipient             => $Param{Recipient},
        Notification          => $Param{Notification},
        CustomerMessageParams => $Param{CustomerMessageParams},
        UserID                => $Param{UserID},
    );
    $Kernel::OM->Get('Log')->Log(
        Priority => 'info',
        Message  => sprintf "   TransportObject::_SendRecipientNotification (TemplateGenerator): %i ms\n", (Time::HiRes::time() - $StartTime) * 1000,
    );

$StartTime = Time::HiRes::time();

    # send notification to each recipient
    my $Success = $TransportObject->SendNotification(
        TicketID              => $Param{TicketID},
        UserID                => $Param{UserID},
        Notification          => \%ReplacedNotification,
        CustomerMessageParams => $Param{CustomerMessageParams},
        Recipient             => $Param{Recipient},
        Event                 => $Param{Event},
        Attachments           => $Param{Attachments},
    );

    $Kernel::OM->Get('Log')->Log(
        Priority => 'info',
        Message  => sprintf "   TransportObject::_SendRecipientNotification (Transport-SendNotification): %i ms (Success: $Success)\n", (Time::HiRes::time() - $StartTime) * 1000,
    );

    return if !$Success;

    # create separate history entries if no article has been created
    if ( !IsArrayRefWithData($Param{Notification}->{Data}->{CreateArticle}) || !$Param{Notification}->{Data}->{CreateArticle}->[0] ) {
        if ( $Param{Recipient}->{Type} eq 'Agent'&& $Param{Recipient}->{UserLogin} ) {
            # write history
            $TicketObject->HistoryAdd(
                TicketID     => $Param{TicketID},
                HistoryType  => 'SendAgentNotification',
                Name         => "\%\%$Param{Notification}->{Name}\%\%$Param{Recipient}->{UserLogin}\%\%$Param{Transport}",
                CreateUserID => $Param{UserID},
            );
        }
        elsif ( $Param{Recipient}->{Type} eq 'Customer' && $Param{Recipient}->{Email} ) {
            # write history
            $TicketObject->HistoryAdd(
                TicketID     => $Param{TicketID},
                HistoryType  => 'SendCustomerNotification',
                Name         => "\%\%$Param{Recipient}->{Email}",
                CreateUserID => $Param{UserID},
            );
        }
    }

    my %EventData = %{ $TransportObject->GetTransportEventData() };

    return 1 if !%EventData;

    if ( !$EventData{Event} || !$EventData{Data} || !$EventData{UserID} ) {

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not trigger notification post send event",
        );

        return;
    }

    # ticket event
    $TicketObject->EventHandler(
        %EventData,
    );

    return 1;
}

sub _GetSubscribedUserIDsByQueueID {
    my ( $Self, %Param ) = @_;

    my @UserIDs;
    if ( IsArrayRef($Self->{Cache}->{SubscribedUserIDsByQueueID}->{$Param{QueueID}}) ) {
        @UserIDs = @{$Self->{Cache}->{SubscribedUserIDsByQueueID}->{$Param{QueueID}}};
    }
    else {
        # get subscribed users
        my %MyQueuesUserIDs = map { $_ => 1 } $Kernel::OM->Get('Ticket')->GetSubscribedUserIDsByQueueID(
            QueueID => $Param{QueueID}
        );

        @UserIDs = sort keys %MyQueuesUserIDs;
        $Self->{Cache}->{SubscribedUserIDsByQueueID}->{$Param{QueueID}} = \@UserIDs;
    }

    return @UserIDs;
}

sub _GetSubscribedUserIDsByServiceID {
    my ( $Self, %Param ) = @_;

    my @UserIDs;
    if ( $Param{ServiceID} ) {
        if ( IsArrayRef($Self->{Cache}->{SubscribedUserIDsByServiceID}->{$Param{ServiceID}}) ) {
            @UserIDs = @{$Self->{Cache}->{SubscribedUserIDsByServiceID}->{$Param{ServiceID}}};
        }
        else {
            # get subscribed users
            my %MyServicesUserIDs = map { $_ => 1 } $Kernel::OM->Get('Ticket')->GetSubscribedUserIDsByServiceID(
                ServiceID => $Param{ServiceID},
            );

            @UserIDs = sort keys %MyServicesUserIDs;
            $Self->{Cache}->{SubscribedUserIDsByServiceID}->{$Param{ServiceID}} = \@UserIDs;
        }
    }

    return @UserIDs;
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
