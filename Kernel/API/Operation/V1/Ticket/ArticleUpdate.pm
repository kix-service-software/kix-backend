# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::ArticleUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ArticleUpdate - API Ticket ArticleUpdate Operation backend

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
        'ArticleID' => {
            Required => 1
        },
        'Article' => {
            Type     => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform ArticleUpdate Operation. This will return the updated ArticleID

    my $Result = $OperationObject->Run(
        Data => {
            TicketID  => 123,                                                  # required
            ArticleID => 123,                                                  # required
            Article  => {                                                      # required
                Subject                         => 'some subject',             # optional
                Body                            => 'some body'                 # optional
                # ContentType                     => 'some content type',        # optional ContentType or MimeType and Charset is requieed
                # MimeType                        => 'some mime type',           # optional
                # Charset                         => 'some charset',             # optional

                IncomingTime                    => 'YYYY-MM-DD HH24:MI:SS',    # optional
                TicketID                        => 123,                        # optional, used to move the article to another ticket
                # ChannelID                       => 123,                        # optional
                # Channel                         => 'some channel name',        # optional
                CustomerVisible                 => 0|1,                        # optional
                SenderTypeID                    => 123,                        # optional
                SenderType                      => 'some sender type name',    # optional
                From                            => 'some from string',         # optional
                To                              => 'some to string',           # optional
                Cc                              => 'some cc string',           # optional
                Bcc                             => 'some bcc string',          # optional
                ReplyTo                         => ''                          # optional
                TimeUnit                        => 123,                        # optional
                DynamicFields => [                                             # optional
                    {
                        Name   => 'some name',
                        Value  => $Value,                                      # value type depends on the dynamic field
                    },
                    # ...
                ],
            }
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ArticleID => 123,                       # ID of changed article
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Article parameter
    my $Article = $Self->_Trim(
        Data => $Param{Data}->{Article}
    );

    my %OldArticle = $Kernel::OM->Get('Ticket')->ArticleGet(
        ArticleID     => $Param{Data}->{ArticleID},
        DynamicFields => 0,
    );

    # check if article exists
    if ( !%OldArticle ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # check if article belongs to the given ticket
    if ( $OldArticle{TicketID} != $Param{Data}->{TicketID} ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # everything is ok, let's update the article
    return $Self->_ArticleUpdate(
        TicketID   => $Param{Data}->{TicketID},
        ArticleID  => $Param{Data}->{ArticleID},
        Article    => $Article,
        OldArticle => \%OldArticle,
        UserID     => $Self->{Authorization}->{UserID},
    );
}

=begin Internal:

=item _ArticleUpdate()

update a ticket with its dynamic fields

    my $Response = $OperationObject->_ArticleUpdate(
        TicketID          => 123,
        ArticleID         => 123,
        Article           => { },                # all article parameters
        OldArticle        => { },                # data of article before update
        UserID            => 123,
    );

    returns:

    $Response = {
        Success => 1,                           # if everything is OK
        Data => {
            ArticleID     => 123,
        }
    }

    $Response = {
        Success      => 0,                      # if unexpected error
        Code         => '...'
        Message      => '...',
    }

=cut

sub _ArticleUpdate {
    my ( $Self, %Param ) = @_;

    # isolate article parameter
    my $Article = $Param{Article};

    # get current richtext body if attachments are given, but no new body
    # updating attachments will delete all current entries, so file-2 has to be prepared
    if (
        defined( $Article->{Attachments} )
        && !$Article->{Body}
    ) {
        # prepare old richtext body and content type
        ( $Article->{Body}, $Article->{ContentType} ) = $Self->_GetRichtextData(
            Article => $Param{OldArticle},
            UserID  => $Param{UserID}
        );
    }

    # prepare body data
    if ( $Article->{Body} ) {

        # check ContentType vs. Charset & MimeType
        if ( !$Article->{ContentType} ) {
            for my $Needed ( qw(Charset MimeType) ) {
                if ( !$Article->{ $Needed } ) {
                    return $Self->_Error(
                        Code    => 'Object.UnableToUpdate',
                        Message => "Need ContentType or MimeType and Charset when updating Body!",
                    );
                }
            }
            $Article->{ContentType} = $Article->{MimeType} . '; charset=' . $Article->{Charset};
        }
        else {
            if ( $Article->{ContentType} =~ /charset=/i ) {
                my $Charset = $Article->{ContentType};
                $Charset =~ s/.+?charset=("|'|)(\w+)/$2/gi;
                $Charset =~ s/"|'//g;
                $Charset =~ s/(.+?);.*/$1/g;

                # only change if we extracted a charset
                $Article->{Charset} = $Charset || $Article->{Charset};
            }

            if ( $Param{ContentType} =~ /^(\w+\/\w+)/i ) {
                my $MimeType = $1;
                $MimeType =~ s/"|'//g;

                # only change if we extracted a mime type
                $Article->{MimeType} = $MimeType || $Article->{MimeType};
            }
        }

        # correct charset if necessary
        if ( $Article->{Charset} ) {
            $Article->{Charset} =~ s/utf8/utf-8/i;
        }
        # fallback for Charset
        else {
            $Article->{Charset} = 'utf-8';
        }

        # if no attachment list is definend, get current attachments to keep them
        if ( !defined( $Article->{Attachments} ) ) {
            my %AttachmentIndex = $Kernel::OM->Get('Ticket')->ArticleAttachmentIndex(
                ContentPath                => $Param{OldArticle}->{ContentPath},
                ArticleID                  => $Param{ArticleID},
                UserID                     => $Param{UserID},
                Article                    => $Article,
                StripPlainBodyAsAttachment => 3,
            );

            if ( %AttachmentIndex ) {

                # get already prepared Article data from ArticleGet operation
                my $GetResult = $Self->ExecOperation(
                    OperationType            => 'V1::Ticket::ArticleAttachmentGet',
                    SuppressPermissionErrors => 1,
                    Data                     => {
                        TicketID               => $Param{TicketID},
                        ArticleID              => $Param{ArticleID},
                        AttachmentID           => join(',', sort keys %AttachmentIndex),
                        include                => 'Content'
                    }
                );
                if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
                    return $Self->_Error(
                        Code    => 'Object.UnableToUpdate',
                        Message => "Could not get current attachments to update article body!",
                    );
                }

                # normalize attachment result to array
                if ( defined( $GetResult->{Data}->{Attachment} ) ) {
                    my @AttachmentList = IsArrayRef($GetResult->{Data}->{Attachment}) ? @{$GetResult->{Data}->{Attachment}} : ( $GetResult->{Data}->{Attachment} );

                    $Article->{Attachments} = \@AttachmentList;
                }
                # init attachment as empty array
                else {
                    $Article->{Attachments} = [];
                }
            }
        }

        # process html article
        if ( $Article->{MimeType} =~ /text\/html/i ) {

            # add html article as attachment
            my $Attachment = {
                Content     => $Article->{Body},
                ContentType => "text/html; charset=\"$Article->{Charset}\"",
                Filename    => 'file-2',
            };
            push( @{ $Article->{Attachments} }, $Attachment );

             # get ascii body
            $Article->{MimeType}    = 'text/plain';
            $Article->{ContentType} =~ s/html/plain/i;
            $Article->{Body}        = $Kernel::OM->Get('HTMLUtils')->ToAscii(
                String => $Article->{Body},
            );
        }
        elsif ( $Article->{MimeType} eq "application/json" ) {

            # Keep JSON body unchanged
        }

        # if body isn't text, attach body as attachment (mostly done by OE) :-/
        elsif ( $Article->{MimeType} !~ /\btext\b/i ) {

            # add non text as attachment
            my $FileName = 'unknown';
            if ( $Article->{ContentType} =~ /name="(.+?)"/i ) {
                $FileName = $1;
            }
            my $Attachment = {
                Content     => $Article->{Body},
                ContentType => $Article->{ContentType},
                Filename    => $FileName,
            };
            push( @{ $Article->{Attachments} }, $Attachment );

            # set ascii body
            $Article->{MimeType}    = 'text/plain';
            $Article->{ContentType} = 'text/plain';
            $Article->{Body}        = '- no text message => see attachment -';
        }

        # fix some bad stuff from some browsers (Opera)!
        else {
            $Article->{Body} =~ s/(\n\r|\r\r\n|\r\n)/\n/g;
        }
    }

    # update normal attributes
    for my $Attribute (
        qw(
            Subject Body From To Cc Bcc
            IncomingTime ReplyTo CustomerVisible
            SenderType SenderTypeID ContentType
        )
    ) {
        # skip undefined attribute
        next if( !defined( $Article->{ $Attribute } ) );

        # skip unchanged attribute
        next if(
            !DataIsDifferent(
                Data1 => $Article->{ $Attribute },
                Data2 => $Param{OldArticle}->{ $Attribute }
            )
        );

        # update attribute
        my $Success = $Kernel::OM->Get('Ticket')->ArticleUpdate(
            ArticleID => $Param{ArticleID},
            Key       => $Attribute,
            Value     => $Article->{ $Attribute },
            UserID    => $Param{UserID},
            TicketID  => $Param{TicketID},
        );
        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToUpdate',
                Message => "Unable to update article attribute $Attribute",
            );
        }
    }

    # update attachment list
    if ( defined( $Article->{Attachments} ) ) {
        # delete all (old) attachments
        my $DeleteSuccessful = $Kernel::OM->Get('Ticket')->ArticleDeleteAttachment(
            ArticleID => $Param{ArticleID},
            UserID    => $Param{UserID},
        );
        if ( !$DeleteSuccessful ) {
            return $Self->_Error(
                Code    => 'Object.UnableToUpdate',
                Message => "Unable to delete article attachments",
            );
        }

        # write (new) attachments
        for my $Attachment ( @{ $Article->{Attachments} } ) {
            # decode attachment content from base64
            if ($Attachment->{Filename} !~ m/^(?:file-[12]|pasted[-]\d+[-]\d+[.].*)$/smx) {
                $Attachment->{Content} = MIME::Base64::decode_base64($Attachment->{Content});
            }
            # extract embedded images from file-2
            elsif (
                $Attachment->{ContentType} eq "text/html; charset=\"$Article->{Charset}\""
                && $Attachment->{Filename} eq 'file-2'
            ) {
                $Kernel::OM->Get('HTMLUtils')->EmbeddedImagesExtract(
                    DocumentRef    => \$Attachment->{Content},
                    AttachmentsRef => $Article->{Attachments},
                );
            }

            # write file to backend
            my $UpdateSuccessful = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
                %{ $Attachment },
                ArticleID => $Param{ArticleID},
                UserID    => $Param{UserID},
            );
            if ( !$UpdateSuccessful ) {
                ## ToDo: inform requester, that writing of attachment failed
            }
        }
    }

    # check if we have to move the article
    if (
        IsStringWithData( $Article->{TicketID} )
        && $Article->{TicketID} != $Param{TicketID}
    ) {
        my $Success = $Kernel::OM->Get('Ticket')->ArticleMove(
            TicketID  => $Param{TicketID},
            ArticleID => $Param{ArticleID},
            UserID    => $Param{UserID},
        );
        if ( !$Success ) {
            return $Self->_Error(
                Code         => 'Object.UnableToUpdate',
                Message      => "Unable to move article",
            );
        }
    }

    # check if we have to update the TimeUnit
    if ( IsStringWithData($Article->{TimeUnit}) ) {
        # delete old time account values
        my $DeleteSuccess = $Kernel::OM->Get('Ticket')->TicketAccountedTimeDelete(
            TicketID  => $Param{TicketID},
            ArticleID => $Param{ArticleID},
        );
        if ( !$DeleteSuccess ) {
            return $Self->_Error(
                Code         => 'Object.UnableToUpdate',
                Message      => "Unable to update article (delete current TimeUnit)",
            );
        }

        # set new time account value
        my $UpdateSuccess = $Kernel::OM->Get('Ticket')->TicketAccountTime(
            TicketID  => $Param{TicketID},
            ArticleID => $Param{ArticleID},
            TimeUnit  => $Article->{TimeUnit},
            UserID    => $Param{UserID},
        );
        if ( !$UpdateSuccess ) {
            return $Self->_Error(
                Code         => 'Object.UnableToUpdate',
                Message      => "Unable to update article (set new TimeUnit)",
            );
        }
    }

    # set dynamic fields
    if ( IsArrayRefWithData( $Article->{DynamicFields} ) ) {
        for my $DynamicField ( @{ $Article->{DynamicFields} } ) {
            my $Result = $Self->_SetDynamicFieldValue(
                %{ $DynamicField },
                ObjectID   => $Param{ArticleID},
                ObjectType => 'Article',
                UserID     => $Self->{Authorization}->{UserID},
            );
            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    Code         => 'Object.UnableToUpdate',
                    Message      => "Dynamic Field $DynamicField->{Name} could not be set ($Result->{Message})",
                );
            }
        }
    }

    return $Self->_Success(
        ArticleID => $Param{ArticleID},
    );
}

sub _GetRichtextData {
    my ( $Self, %Param ) = @_;

    # init result variables with plain text values
    my $RichtextBody        = $Param{Article}->{Body};
    my $RichtextContentType = $Param{Article}->{ContentType};

    # get attachment index
    my %AttachmentIndex = $Kernel::OM->Get('Ticket')->ArticleAttachmentIndex(
        Article                    => $Param{Article},
        ArticleID                  => $Param{Article}->{ArticleID},
        StripPlainBodyAsAttachment => 2,
        UserID                     => $Param{UserID},
    );
    if ( IsHashRefWithData( \%AttachmentIndex ) ) {
        my @InlineAttachments;

        # process attachments
        for my $AttachmentID ( keys( %AttachmentIndex ) ) {
            # skip everything but file-2
            next if ( $AttachmentIndex{ $AttachmentID }->{Filename} ne 'file-2' );

            # get attachment data
            my %Attachment = $Kernel::OM->Get('Ticket')->ArticleAttachment(
                ArticleID    => $Param{Article}->{ArticleID},
                AttachmentID => $AttachmentID,
                UserID       => $Param{UserID},
            );

            if ( IsHashRefWithData( \%Attachment ) ) {
                # prepare content for encoding
                my $Charset = $Attachment{ContentType} || q{};
                $Charset =~ s/.+?charset=("|'|)(\w+)/$2/gi;
                $Charset =~ s/"|'//g;
                $Charset =~ s/(.+?);.*/$1/g;

                # convert html body to correct charset
                my $Body = $Kernel::OM->Get('Kernel::System::Encode')->Convert(
                    Text  => $Attachment{Content},
                    From  => $Charset,
                    To    => 'utf-8',
                    Check => 1,
                );

                # add url quoting
                $Body = $Kernel::OM->Get('Kernel::System::HTMLUtils')->LinkQuote(
                    String => $Body,
                );

                # strip head, body and meta elements
                $Body = $Kernel::OM->Get('Kernel::System::HTMLUtils')->DocumentStrip(
                    String => $Body,
                );

                # set richtext parameter
                $RichtextBody        = $Body;
                $RichtextContentType = $Attachment{ContentType};

                # preparation is done
                last;
            }
        }
    }

    return ( $RichtextBody, $RichtextContentType );
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
