# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
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

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    my %Article = $TicketObject->ArticleGet(
        ArticleID     => $Param{Data}->{ArticleID},
        DynamicFields => 0,
    );

    # check if article exists
    if ( !%Article ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # check if article belongs to the given ticket
    if ( $Article{TicketID} != $Param{Data}->{TicketID} ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # everything is ok, let's update the article
    return $Self->_ArticleUpdate(
        TicketID  => $Param{Data}->{TicketID},
        ArticleID => $Param{Data}->{ArticleID},
        Article   => $Article,
        UserID    => $Self->{Authorization}->{UserID},
    );
}

=begin Internal:

=item _ArticleUpdate()

update a ticket with its dynamic fields

    my $Response = $OperationObject->_ArticleUpdate(
        TicketID          => 123,
        ArticleID         => 123,
        Article           => { },                # all article parameters
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

    my $TicketObject = $Kernel::OM->Get('Ticket');
    my $Article    = $Param{Article};
    my %OldArticle = $TicketObject->ArticleGet(
        ArticleID => $Param{ArticleID},
        UserID    => $Param{UserID}
    );

    if (
        $Article->{Body}
        && !$Article->{Attachments}
    ) {
        my %OldAttachments = $TicketObject->ArticleAttachmentIndex(
            ArticleID                  => $Param{ArticleID},
            UserID                     => $Param{UserID},
            Article                    => \%OldArticle,
            StripPlainBodyAsAttachment => 3,
        );

        if ( %OldAttachments ) {
            for my $FileID ( sort keys %OldAttachments ) {
                my %Attachment = $TicketObject->ArticleAttachment(
                    FileID    => $FileID,
                    ArticleID => $Param{ArticleID},
                    UserID    => $Param{UserID}
                );

                $Attachment{Content} = MIME::Base64::encode_base64($Attachment{Content});

                push ( @{$Article->{Attachments}}, \%Attachment );
            }
        }
    }

    if ( !$Article->{Body} ) {
        if ( defined $Article->{Attachments} ) {
            $Article->{Body}     = $OldArticle{Body};
            $Article->{HTMLBody} = $Self->_GetBodyRichtext(
                Article => $Article,
                UserID  => $Param{UserID}
            );
        }
    } else {

        # replace placeholders
        $Article->{Body} = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
            RichText => $Article->{MimeType} =~ m/text\/html/i ? 1 : 0,
            Text     => $Article->{Body},
            TicketID => $Param{TicketID},
            Data     => {},
            UserID   => $Param{UserID},
        );
        if (
            IsHashRefWithData($Article->{OrigHeader})
            && $Article->{OrigHeader}->{Body}
        ) {
            $Article->{OrigHeader}->{Body} = $Article->{Body};
        }

        # process html article
        if ( $Article->{MimeType} =~ /text\/html/i ) {

            # add html article as attachment
            my $Attach = {
                Content     => $Article->{Body},
                ContentType => "text/html; charset=\"$Article->{Charset}\"",
                Filename    => 'file-2',
            };
            push @{ $Article->{Attachments} }, $Attach;

             # get ascii body
            $Article->{MimeType} = 'text/plain';
            $Article->{ContentType} =~ s/html/plain/i;
            $Article->{Body} = $Kernel::OM->Get('HTMLUtils')->ToAscii(
                String => $Article->{Body},
            );
        }
        elsif ( $Article->{MimeType} && $Article->{MimeType} eq "application/json" ) {

            # Keep JSON body unchanged
        }

        # if body isn't text, attach body as attachment (mostly done by OE) :-/
        elsif ( $Article->{MimeType} && $Article->{MimeType} !~ /\btext\b/i ) {

            # add non text as attachment
            my $FileName = 'unknown';
            if ( $Article->{ContentType} =~ /name="(.+?)"/i ) {
                $FileName = $1;
            }
            my $Attach = {
                Content     => $Article->{Body},
                ContentType => $Article->{ContentType},
                Filename    => $FileName,
            };
            push @{ $Article->{Attachments} }, $Attach;

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
    foreach my $Attribute (
        qw(
            Subject Body From To Cc Bcc
            IncomingTime ReplyTo CustomerVisible
            SenderType SenderTypeID
        )
    ) {
        next if !defined $Article->{$Attribute};

        my $Success = $TicketObject->ArticleUpdate(
            ArticleID => $Param{ArticleID},
            Key       => $Attribute,
            Value     => $Article->{$Attribute},
            UserID    => $Param{UserID},
            TicketID  => $Param{TicketID},
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code         => 'Object.UnableToUpdate',
                Message      => "Unable to update article attribute $Attribute",
            );
        }
    }

    if (
        defined $Article->{Attachments}
        || defined $Article->{Body}
    ) {

        # delete all (old) attachments
        my $UpdateSuccessful = $TicketObject->ArticleDeleteAttachment(
            ArticleID => $Param{ArticleID},
            UserID    => $Param{UserID},
        );

        if ( !$UpdateSuccessful ) {
            return $Self->_Error(
                Code    => 'Object.UnableToUpdate',
                Message => "Unable to delete article attachments",
            );
        }

        # write attachments
        for my $Attachment (@{$Article->{Attachments}}) {

            # write existing file to backend
            $UpdateSuccessful = $TicketObject->ArticleWriteAttachment(
                %{$Attachment},
                ArticleID => $Param{ArticleID},
                UserID    => $Param{UserID},
            );
        }
    }

    # check if we have to move the article
    if ( IsStringWithData($Article->{TicketID}) && $Article->{TicketID} != $Param{TicketID} ) {
        my $Success = $TicketObject->ArticleMove(
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

    # check if we have to update the incoming time
    if ( IsStringWithData($Article->{IncomingTime}) ) {
        my $Success = $TicketObject->ArticleMove(
            TicketID  => $Param{TicketID},
            ArticleID => $Param{ArticleID},
            UserID    => $Param{UserID},
        );
        if ( !$Success ) {
            return $Self->_Error(
                Code         => 'Object.UnableToUpdate',
                Message      => "Unable to update article",
            );
        }
    }

    # check if we have to update the TimeUnit
    if ( IsStringWithData($Article->{TimeUnit}) ) {

        # delete old time account values
        my $DeleteSuccess = $TicketObject->TicketAccountedTimeDelete(
            TicketID  => $Param{TicketID},
            ArticleID => $Param{ArticleID},
        );

        if ( !$DeleteSuccess ) {
            return $Self->_Error(
                Code         => 'Object.UnableToUpdate',
                Message      => "Unable to update article (TimeUnit)",
            );
        }

        # set new time account value
        my $UpdateSuccess = $TicketObject->TicketAccountTime(
            TicketID  => $Param{TicketID},
            ArticleID => $Param{ArticleID},
            TimeUnit  => $Article->{TimeUnit},
            UserID    => $Param{UserID},
        );

        if ( !$UpdateSuccess ) {
            return $Self->_Error(
                Code         => 'Object.UnableToUpdate',
                Message      => "Unable to update article (TimeUnit)",
            );
        }
    }

    # set dynamic fields
    if ( IsArrayRefWithData($Article->{DynamicFields}) ) {

        DYNAMICFIELD:
        foreach my $DynamicField ( @{$Article->{DynamicFields}} ) {
            my $Result = $Self->SetDynamicFieldValue(
                %{$DynamicField},
                ArticleID => $Param{ArticleID},
                UserID    => $Param{UserID},
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


sub _GetBodyRichtext {
    my ( $Self, %Param ) = @_;

    my $BodyRichtext = q{};

    my %AttachmentIndex = $Self->{TicketObject}->ArticleAttachmentIndex(
        Article                    => $Param{Article},
        ArticleID                  => $Param{Article}->{ArticleID},
        StripPlainBodyAsAttachment => 2,
        UserID                     => $Param{UserID},
    );

    if (IsHashRefWithData(\%AttachmentIndex)) {
        my @InlineAttachments;

        for my $AttachmentID ( keys %AttachmentIndex ) {

            # only inline attachments relevant
            next if (
                !$AttachmentIndex{ $AttachmentID }->{Disposition}
                || $AttachmentIndex{ $AttachmentID }->{Disposition} ne 'inline'
            );

            if ( $AttachmentIndex{$AttachmentID}->{Filename} eq 'file-2') {
                my %Attachment = $Self->{TicketObject}->ArticleAttachment(
                    ArticleID => $Param{Article}->{ArticleID},
                    FileID    => $AttachmentID,
                    UserID    => $Param{UserID},
                );

                if (IsHashRefWithData(\%Attachment)) {
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
                    $BodyRichtext = $Body;
                }
            } elsif ($AttachmentIndex{$AttachmentID}->{ContentID} && $Param{WithInline}) {
                my %Attachment = $Self->{TicketObject}->ArticleAttachment(
                    ArticleID => $Param{Article}->{ArticleID},
                    FileID    => $AttachmentID,
                    UserID    => $Param{UserID},
                );
                if (IsHashRefWithData(\%Attachment)) {
                    push(@InlineAttachments, \%Attachment);
                }
            }
        }

        if ($BodyRichtext && scalar @InlineAttachments) {
            for my $Attachment ( @InlineAttachments ) {
                my $Content = MIME::Base64::encode_base64( $Attachment->{Content} );

                my $ContentType = $Attachment->{ContentType};
                $ContentType =~ s/"/\'/g;

                my $ReplaceString = "data:$ContentType;base64,$Content";

                # remove < and > arround id (eg. <123456> ==> 1323456)
                my $ContentID = substr($Attachment->{ContentID}, 1, -1);
                $BodyRichtext =~ s/cid:$ContentID/$ReplaceString/g;
            }
        }
    }

    return $BodyRichtext;
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
