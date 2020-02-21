# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
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

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

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
            TicketID             => '32,33',                                       # required, could be coma separated IDs or an Array
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
                    SLA                => 'some sla',
                    SLAID              => 123,
                    Service            => 'some service',
                    ServiceID          => 123,
                    Responsible        => 'some_responsible_login',
                    ResponsibleID      => 123,
                    Age                => 3456,
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

                    # (time stamps of expected escalations)
                    EscalationResponseTime           (unix time stamp of response time escalation)
                    EscalationUpdateTime             (unix time stamp of update time escalation)
                    EscalationSolutionTime           (unix time stamp of solution time escalation)

                    # (general escalation info of nearest escalation type)
                    EscalationDestinationIn          (escalation in e. g. 1h 4m)
                    EscalationDestinationTime        (date of escalation in unix time, e. g. 72193292)
                    EscalationDestinationDate        (date of escalation, e. g. "2009-02-14 18:00:00")
                    EscalationTimeWorkingTime        (seconds of working/service time till escalation, e. g. "1800")
                    EscalationTime                   (seconds total till escalation of nearest escalation time type - response, update or solution time, e. g. "3600")

                    # (detailed escalation info about first response, update and solution time)
                    FirstResponseTimeEscalation      (if true, ticket is escalated)
                    FirstResponseTimeNotification    (if true, notify - x% of escalation has reached)
                    FirstResponseTimeDestinationTime (date of escalation in unix time, e. g. 72193292)
                    FirstResponseTimeDestinationDate (date of escalation, e. g. "2009-02-14 18:00:00")
                    FirstResponseTimeWorkingTime     (seconds of working/service time till escalation, e. g. "1800")
                    FirstResponseTime                (seconds total till escalation, e. g. "3600")

                    UpdateTimeEscalation             (if true, ticket is escalated)
                    UpdateTimeNotification           (if true, notify - x% of escalation has reached)
                    UpdateTimeDestinationTime        (date of escalation in unix time, e. g. 72193292)
                    UpdateTimeDestinationDate        (date of escalation, e. g. "2009-02-14 18:00:00")
                    UpdateTimeWorkingTime            (seconds of working/service time till escalation, e. g. "1800")
                    UpdateTime                       (seconds total till escalation, e. g. "3600")

                    SolutionTimeEscalation           (if true, ticket is escalated)
                    SolutionTimeNotification         (if true, notify - x% of escalation has reached)
                    SolutionTimeDestinationTime      (date of escalation in unix time, e. g. 72193292)
                    SolutionTimeDestinationDate      (date of escalation, e. g. "2009-02-14 18:00:00")
                    SolutionTimeWorkingTime          (seconds of working/service time till escalation, e. g. "1800")
                    SolutionTime                     (seconds total till escalation, e. g. "3600")

                    # if you use param Extended to get extended ticket attributes
                    FirstResponse                   (timestamp of first response, first contact with customer)
                    FirstResponseInMin              (minutes till first response)
                    FirstResponseDiffInMin          (minutes till or over first response)

                    SolutionTime                    (timestamp of solution time, also close time)
                    SolutionInMin                   (minutes till solution time)
                    SolutionDiffInMin               (minutes till or over solution time)

                    FirstLock                       (timestamp of first lock)

                    # if Include=TimeUnits was passed, the sum of all TimeUnits of all articles will be included
                    TimeUnits

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

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my @TicketList;

    # start loop
    for my $TicketID ( @{$Param{Data}->{TicketID}} ) {

        # get the Ticket
        my %TicketRaw = $TicketObject->TicketGet(
            TicketID      => $TicketID,
            DynamicFields => $Param{Data}->{include}->{DynamicFields},
            Extended      => $Param{Data}->{extended},
            UserID        => $Self->{Authorization}->{UserID},
        );

        if ( !IsHashRefWithData( \%TicketRaw ) ) {

            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # add unseen information
        my %Flags = $TicketObject->TicketFlagGet(
            TicketID => $TicketID,
            UserID   => $Self->{Authorization}->{UserID},  
        );
        $TicketRaw{Unseen} = (!exists($Flags{Seen}) || !$Flags{Seen}) ? 1 : 0;

        my %TicketData;
        my @DynamicFields;

        # inform API caching about a new dependency
        $Self->AddCacheDependency(Type => 'DynamicField');

        # remove all dynamic fields from main ticket hash and set them into an array.
        ATTRIBUTE:
        for my $Attribute ( sort keys %TicketRaw ) {

            if ( $Attribute =~ m{\A DynamicField_(.*) \z}msx ) {
                if ( $TicketRaw{$Attribute} ) {
                    my $DynamicFieldConfig = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet(
                        Name => $1,
                    );
                    if ( IsHashRefWithData($DynamicFieldConfig) ) {

                        # get prepared value
                        my $DFPreparedValue = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->ValueLookup(
                            DynamicFieldConfig => $DynamicFieldConfig,
                            Key                => $TicketRaw{$Attribute},
                        );

                        # get display value string
                        my $DisplayValue = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->DisplayValueRender(
                            DynamicFieldConfig => $DynamicFieldConfig,
                            Value              => $TicketRaw{$Attribute}
                        );

                        if (!IsHashRefWithData($DisplayValue)) {
                            my $Separator = ', ';
                            if (
                                IsHashRefWithData($DynamicFieldConfig) &&
                                IsHashRefWithData($DynamicFieldConfig->{Config}) &&
                                defined $DynamicFieldConfig->{Config}->{ItemSeparator}
                            ) {
                                $Separator = $DynamicFieldConfig->{Config}->{ItemSeparator};
                            }

                            my @Values;
                            if ( ref $DFPreparedValue eq 'ARRAY' ) {
                                @Values = @{ $DFPreparedValue };
                            }
                            else {
                                @Values = ($DFPreparedValue);
                            }

                            $DisplayValue = {
                                Value => join($Separator, @Values)
                            };
                        }

                        # get html display value string
                        my $DisplayValueHTML = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->HTMLDisplayValueRender(
                            DynamicFieldConfig => $DynamicFieldConfig,
                            Value              => $TicketRaw{$Attribute},
                        );

                        # get short display value string
                        my $DisplayValueShort = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->ShortDisplayValueRender(
                            DynamicFieldConfig => $DynamicFieldConfig,
                            Value              => $TicketRaw{$Attribute}
                        );
                        
                        push @DynamicFields, {
                            ID                => $DynamicFieldConfig->{ID},
                            Name              => $DynamicFieldConfig->{Name},
                            Label             => $DynamicFieldConfig->{Label},
                            Value             => $TicketRaw{$Attribute},
                            DisplayValue      => $DisplayValue->{Value},
                            DisplayValueHTML  => $DisplayValueHTML ? $DisplayValueHTML->{Value} : $DisplayValue->{Value},
                            DisplayValueShort => $DisplayValueShort ? $DisplayValueShort->{Value} : $DisplayValue->{Value},
                            PreparedValue     => $DFPreparedValue
                        };
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

        # include TimeUnits if requested
        if ( $Param{Data}->{include}->{TimeUnits} ) {
            $TicketData{TimeUnits} = $TicketObject->TicketAccountedTimeGet(
                TicketID => $TicketID,
            );
        }

        # add
        push(@TicketList, \%TicketData);
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

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
