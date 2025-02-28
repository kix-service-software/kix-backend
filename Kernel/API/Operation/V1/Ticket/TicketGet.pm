# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::TicketGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::TicketGet - API Ticket Get Operation backend

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
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        },
    }
}

=item Run()

perform TicketGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID             => '32,33',                                       # required, could be comma separated IDs or an Array
            Extended             => 0,                                             # Optional, 0 as default. Add extended data (escalation data, ...)
            include              => '...',                                         # Optional, 0 as default. Include additional objects
                                                                                   # (supported: DynamicFields, Articles)
            expand               => 0,                                             # Optional, 0 as default. Expand referenced objects
                                                                                   # (supported: Articles)
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            Ticket => [
                {
                    TicketNumber       => '20101027000001',
                    Title              => 'some title',
                    TicketID           => 123,
                    State              => 'some state',
                    StateID            => 123,
                    StateType          => 'some state type',
                    Priority           => 'some priority',
                    PriorityID         => 123,
                    Lock               => 'lock',
                    LockID             => 123,
                    Queue              => 'some queue',
                    QueueID            => 123,
                    OrganisationID     => 'customer_id_123',
                    ContactID          => 'customer_user_id_123',
                    Owner              => 'some_owner_login',
                    OwnerID            => 123,
                    Type               => 'some ticket type',
                    TypeID             => 123,
                    Responsible        => 'some_responsible_login',
                    ResponsibleID      => 123,
                    Created            => '2010-10-27 20:15:00'
                    CreateTimeUnix     => '1231414141',
                    CreateBy           => 123,
                    Changed            => '2010-10-27 20:15:15',
                    ChangeBy           => 123,
                    ArchiveFlag        => 'y',

                    # If Include=DynamicFields was passed, you'll get an entry like this for each dynamic field:
                    DynamicFields => [
                        {
                            Name  => 'some name',
                            Value => 'some value',
                        },
                    ],

                    FirstLock                       (timestamp of first lock)

                    # if Include=TimeUnit was passed, the sum of all TimeUnits of all articles will be included
                    TimeUnit

                    # If Include=Articles was passed, you'll get an entry like this:
                    Articles => [
                        <ArticleID>
                        # . . .
                    ]

                    # If Include=Articles AND Expand=Articles was passed, the article data will be expanded (see ArticleGet for details):
                    Articles => [
                        {
                            ArticleID
                            From
                            To
                            Cc
                            Subject
                            Body
                            ReplyTo
                            MessageID
                            InReplyTo
                            References
                            SenderType
                            SenderTypeID
                            Channel
                            ChannelID
                            ContentType
                            Charset
                            MimeType
                            IncomingTime

                            # If include=DynamicFields => 1 was passed, you'll get an entry like this for each dynamic field:
                            DynamicFields => [
                                {
                                    Name  => 'some name',
                                    Value => 'some value',
                                },
                            ],

                            # If include=Attachments => 1 was passed, you'll get an entry like this for each attachment:
                            Attachments => [
                                <AttachmentID>
                                # . . .
                            ]
                            # If include=Attachments => 1 AND expand=Attachments => 1 was passed, you'll get an entry like this for each attachment:
                            Attachments => [
                                {
                                    Content            => "xxxx",     # actual attachment contents, base64 enconded
                                    ContentAlternative => "",
                                    ContentID          => "",
                                    ContentType        => "application/pdf",
                                    Filename           => "StdAttachment-Test1.pdf",
                                    Filesize           => "4.6 KBytes",
                                    FilesizeRaw        => 4722,
                                },
                                {
                                   # . . .
                                },
                            ]
                        },
                        {
                            #. . .
                        },
                    ],

                    # If Include=History was passed, you'll get an entry like this:
                    History => [
                        <HistoryID>
                        # . . .
                    ]

                    # If Include=History AND Expand=History was passed, the history data will be expanded (see HistoryGet for details):
                    History => [
                        {
                            OwnerID
                            ArticleID
                            CreateBy
                            HistoryType
                            CreateTime
                            StateID
                            TypeID
                            HistoryTypeID
                            Name
                            HistoryID
                            QueueID
                            TicketID
                            PriorityID
                        },
                        {
                            #. . .
                        },
                    ],
                },
                {
                    #. . .
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @TicketList;

    if ( $Self->_CanRunParallel(Items => $Param{Data}->{TicketID}) ) {
        @TicketList = $Self->_RunParallel(
            \&_GetTicketData,
            Items => $Param{Data}->{TicketID},
            %Param,
        );
    }
    else {
        # start loop
        for my $TicketID ( @{$Param{Data}->{TicketID}} ) {
            my $TicketData = $Self->_GetTicketData(
                TicketID => $TicketID,
                Data     => $Param{Data}
            );
            if ( IsHashRefWithData($TicketData) ) {
                push @TicketList, $TicketData;
            }
            else {
                return $Self->_Error(
                    Code => 'Object.NotFound',
                );
            }
        }
    }

    if ( scalar(@TicketList) == 1 ) {
        return $Self->_Success(
            Ticket => $TicketList[0],
        );
    }

    return $Self->_Success(
        Ticket => \@TicketList,
    );
}

sub _GetTicketData {
    my ( $Self, %Param ) = @_;

    my $TicketID = $Param{Item} || $Param{TicketID};

    my $TicketObject = $Kernel::OM->Get('Ticket');

    # get the Ticket
    my %TicketRaw = $TicketObject->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => $Param{Data}->{include}->{DynamicFields},
        Extended      => $Param{Data}->{extended},
        UserID        => $Self->{Authorization}->{UserID},
    );

    if ( !IsHashRefWithData( \%TicketRaw ) ) {
        return;
    }

    my %TicketData;
    my @DynamicFields;

    # inform API caching about a new dependency
    $Self->AddCacheDependency(Type => 'DynamicField') if $Param{Data}->{include}->{DynamicFields};

    # remove all dynamic fields from main ticket hash and set them into an array.
    ATTRIBUTE:
    for my $Attribute ( sort keys %TicketRaw ) {

        if ( $Attribute =~ m{\A DynamicField_(.*) \z}msx ) {
            if ( $TicketRaw{$Attribute} ) {
                my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
                    Name => $1,
                );
                if ( IsHashRefWithData($DynamicFieldConfig) ) {

                    # ignore DFs which are not visible for the customer, if the user session is a Customer session
                    next ATTRIBUTE if $Self->{Authorization}->{UserType} eq 'Customer' && !$DynamicFieldConfig->{CustomerVisible};

                    my $PreparedValue = $Self->_GetPrepareDynamicFieldValue(
                        Config          => $DynamicFieldConfig,
                        Value           => $TicketRaw{$Attribute},
                        NoDisplayValues => [ split(',', $Param{Data}->{NoDynamicFieldDisplayValues}||'') ]
                    );

                    if (IsHashRefWithData($PreparedValue)) {
                        push(@DynamicFields, $PreparedValue);
                    }

                }
            }
            next ATTRIBUTE;
        }

        $TicketData{$Attribute} = $TicketRaw{$Attribute};
    }

    # add dynamic fields array into 'DynamicFields' hash key if any
    if (@DynamicFields) {
        $TicketData{DynamicFields} = \@DynamicFields;
    }
    else {
        $TicketData{DynamicFields} = [];
    }

    # include AccountedTime if requested
    if ( $Param{Data}->{include}->{AccountedTime} && !defined $TicketData{AccountedTime} ) {
        $TicketData{AccountedTime} = $TicketObject->TicketAccountedTimeGet(
            TicketID => $TicketID,
        );
    }

    # add previous state
    if ( $Param{Data}->{include}->{StatePrevious} ) {
        $TicketData{StatePrevious} = $TicketObject->GetPreviousTicketState(
            TicketID => $TicketID,
        ) || undef;
        if ( $TicketData{StatePrevious} ) {
            $TicketData{StateIDPrevious} = 0 + $Kernel::OM->Get('State')->StateLookup(
                State => $TicketData{StatePrevious},
            );
        }
        else {
            $TicketData{StateIDPrevious} = undef;
        }
    }

    # add unseen information
    if ( $Param{Data}->{include}->{Unseen} ) {
        my $Exists = $TicketObject->TicketUserFlagExists(
            TicketID => $TicketID,
            Flag     => 'Seen',
            Value    => 1,
            UserID   => $Self->{Authorization}->{UserID},
        );
        $TicketData{Unseen} = $Exists ? 0 : 1;
    }

    # add watcher info
    if ( $Param{Data}->{include}->{WatcherID} ) {
        my $WatcherID = $Kernel::OM->Get('Watcher')->WatcherLookup(
            Object      => 'Ticket',
            ObjectID    => $TicketID,
            WatchUserID => $Self->{Authorization}->{UserID},
        );
        $TicketData{WatcherID} = $WatcherID || undef;
    }

    # add link count
    if ( $Param{Data}->{include}->{LinkCount} ) {
        $TicketData{LinkCount} = 0 + $Kernel::OM->Get('LinkObject')->LinkCount(
            Object => 'Ticket',
            Key    => $TicketID
        );
    }

    # add array of article ids
    if ( $Param{Data}->{include}->{ArticleIDs} ) {
        my @ArticleIndex = $TicketObject->ArticleIndex(
            TicketID => $TicketID,
            UserID   => $Self->{Authorization}->{UserID},
        );

        # filter for customer assigned articles if necessary
        @ArticleIndex = $Self->_FilterCustomerUserVisibleObjectIds(
            TicketID               => $Param{Data}->{TicketID},
            ObjectType             => 'TicketArticle',
            ObjectIDList           => \@ArticleIndex,
            UserID                 => $Self->{Authorization}->{UserID},
            RelevantOrganisationID => $Param{Data}->{RelevantOrganisationID}
        );
        $TicketData{ArticleIDs} = \@ArticleIndex;
    }

    #FIXME: workaround KIX2018-3308
    if ($TicketData{ContactID}) {
        $TicketData{ContactID}      = "" . $TicketData{ContactID};
    }
    if ($TicketData{OrganisationID}) {
        $TicketData{OrganisationID} = "" . $TicketData{OrganisationID};
    }

    delete $TicketData{Age};

    return \%TicketData;
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
