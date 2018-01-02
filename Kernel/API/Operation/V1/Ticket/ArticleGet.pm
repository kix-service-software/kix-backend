# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::ArticleGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ArticleGet - API Ticket Get Operation backend

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

perform ArticleGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID             => '1',                                           # required 
            ArticleID            => '32,33',                                       # required, could be coma separated IDs or an Array
            include              => '...',                                         # Optional, 0 as default. Include additional objects
                                                                                   # (supported: DynamicFields, Attachments)
            expand               => 0,                                             # Optional, 0 as default. Expand referenced objects
                                                                                   # (supported: Attachments) 
            HTMLBodyAsAttachment => 1                                              # Optional, If enabled the HTML body version of each article is added to the attachments list
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            Article => [
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
                            AttachmentID       => 123
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
            'ArticleID' => {
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
    my $Permission = $Self->CheckAccessPermission(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Self->{Authorization}->{UserID},
        UserType => $Self->{Authorization}->{UserType},
    );

    if ( !$Permission ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to access ticket $Param{Data}->{TicketID}.",
        );
    }

    # By default does not include HTML body as attachment (3) unless is explicitly requested (2).
    my $StripPlainBodyAsAttachment = $Param{Data}->{HTMLBodyAsAttachment} ? 2 : 3;

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my @ArticleList;

    # start article loop
    ARTICLE:
    for my $ArticleID ( sort @{$Param{Data}->{ArticleID}} ) {

        my %ArticleRaw = $TicketObject->ArticleGet(
            ArticleID          => $ArticleID,
            DynamicFields      => $Param{Data}->{include}->{DynamicFields},
            UserID             => $Self->{Authorization}->{UserID},
        );

        # restrict article sender types
        if ( $Self->{Authorization}->{UserType} eq 'Customer' && $ArticleRaw{ArticleSenderType} ne 'customer') {
            return $Self->_Error(
                Code    => 'Object.NoPermission',
                Message => "No permission to access article $ArticleID.",
            );
        }

        if ( $Param{Data}->{include}->{Attachments} ) {
            # get attachment index (without attachments)
            my %AtmIndex = $TicketObject->ArticleAttachmentIndex(
                ContentPath                => $ArticleRaw{ContentPath},
                ArticleID                  => $ArticleID,
                StripPlainBodyAsAttachment => $StripPlainBodyAsAttachment,
                UserID                     => $Self->{Authorization}->{UserID},
            );

            my @Attachments = sort keys %AtmIndex;

            # set Attachments data
            $ArticleRaw{Attachments} = \@Attachments;
        }

        my %ArticleData;
        my @DynamicFields;

        # remove all dynamic fields from main article hash and set them into an array.
        ATTRIBUTE:
        for my $Attribute ( sort keys %ArticleRaw ) {

            if ( $Attribute =~ m{\A DynamicField_(.*) \z}msx ) {
                if ( $ArticleRaw{$Attribute} ) {
                    push @DynamicFields, {
                        Name  => $1,
                        Value => $ArticleRaw{$Attribute},
                    };
                }
                next ATTRIBUTE;
            }

            $ArticleData{$Attribute} = $ArticleRaw{$Attribute};
        }

        # add dynamic fields array into 'DynamicFields' hash key if included
        if ( $Param{Data}->{include}->{DynamicFields} ) {
            $ArticleData{DynamicFields} = \@DynamicFields;
        }
            
        # add
        push(@ArticleList, \%ArticleData);
    }

    if ( scalar(@ArticleList) == 1 ) {
        return $Self->_Success(
            Article => $ArticleList[0],
        );    
    }

    return $Self->_Success(
        Article => \@ArticleList,
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
