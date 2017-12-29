# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::TicketGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

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
                    CustomerID         => 'customer_id_123',
                    CustomerUserID     => 'customer_user_id_123',
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

                    # If Include=Articles was passed, you'll get an entry like this for each article:
                    Articles => [
                        <ArticleID>
                        # . . .
                    ]

                    # If Include=Articles AND Expand=Articles was passed, you'll the article data will be expanded (see ArticleGet for details):
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
                            ArticleType
                            ArticleTypeID
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
                Type     => 'ARRAY',
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

    # check ticket permission
    TICKET:
    for my $TicketID ( @{$Param{Data}->{TicketID}} ) {

        my $Permission = $Self->CheckAccessPermission(
            TicketID => $TicketID,
            UserID   => $Self->{Authorization}->{UserID},
            UserType => $Self->{Authorization}->{UserType},
        );

        next TICKET if $Permission;

        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to access ticket $TicketID.",
        );
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my @TicketList;

    # start ticket loop
    TICKET:
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
                Code    => 'Object.NotFound',
                Message => "Could not get data for ticket $TicketID",
            );
        }

        my %TicketData;
        my @DynamicFields;

        # remove all dynamic fields from main ticket hash and set them into an array.
        ATTRIBUTE:
        for my $Attribute ( sort keys %TicketRaw ) {

            if ( $Attribute =~ m{\A DynamicField_(.*) \z}msx ) {
                if ( $TicketRaw{$Attribute} ) {
                    push @DynamicFields, {
                        Name  => $1,
                        Value => $TicketRaw{$Attribute},
                    };
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

        # include articles if requested
        if ( $Param{Data}->{include}->{Articles} ) {
            my $ArticleTypes;
            if ( $Self->{Authorization}->{UserType} eq 'Customer' ) {
                $ArticleTypes = [ $TicketObject->ArticleTypeList( Type => 'Customer' ) ];
            }

            my @ArticleIndex = $TicketObject->ArticleIndex(
                TicketID   => $TicketID,
                SenderType => $ArticleTypes,
                UserID     => $Self->{Authorization}->{UserID},
            );

            $TicketData{Articles} = \@ArticleIndex;
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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
