# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Email;

use strict;
use warnings;

use Email::Address::XS;
use MIME::Entity;
use MIME::Parser;
use MIME::Words;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    Certificate
    Config
    Encode
    HTMLUtils
    Log
    Main
    Time
);

=head1 NAME

Kernel::System::Email - to send email

=head1 SYNOPSIS

Global module to send email via sendmail or SMTP.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $EmailObject = $Kernel::OM->Get('Email');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # debug level
    $Self->{Debug} = $Param{Debug} || 0;

    # get configured backend module
    my $GenericModule = $Kernel::OM->Get('Config')->Get('SendmailModule')
        || 'Kernel::System::Email::Sendmail';

    # get backend object
    $Self->{Backend} = $Kernel::OM->Get($GenericModule);

    return $Self;
}

=item Send()

To send an email without already created header:

    my $Sent = $SendObject->Send(
        From          => 'me@example.com',
        To            => 'friend@example.com',
        Cc            => 'Some Customer B <customer-b@example.com>',   # not required
        ReplyTo       => 'Some Customer B <customer-b@example.com>',   # not required, is possible to use 'Reply-To' instead
        Subject       => 'Some words!',
        Charset       => 'iso-8859-15',
        MimeType      => 'text/plain', # "text/plain" or "text/html"
        Body          => 'Some nice text',
        InReplyTo     => '<somemessageid-2@example.com>',
        References    => '<somemessageid-1@example.com> <somemessageid-2@example.com>',
        Loop          => 1, # not required, removes smtp from
        CustomHeaders => {
            X-KIX-MyHeader => 'Some Value',
        },
        Attachment   => [
            {
                Filename    => "somefile.csv",
                Content     => $ContentCSV,
                ContentType => "text/csv",
            },
            {
                Filename    => "somefile.png",
                Content     => $ContentPNG,
                ContentType => "image/png",
            }
        ],
    );

    if ($Sent) {
        print "Email sent!\n";
    }
    else {
        print "Email not sent!\n";
    }

=cut

sub Send {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Body Charset)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    if ( !$Param{To} && !$Param{Cc} && !$Param{Bcc} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need To, Cc or Bcc!'
        );
        return;
    }

    # exchanging original reference prevent it to grow up
    if ( ref $Param{Attachment} && ref $Param{Attachment} eq 'ARRAY' ) {
        my @LocalAttachment = @{ $Param{Attachment} };
        $Param{Attachment} = \@LocalAttachment;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # check from
    if ( !$Param{From} ) {
        $Param{From} = $ConfigObject->Get('AdminEmail') || 'kix@localhost';
    }

    # replace all br tags with br tags with a space to show newlines in Lotus Notes
    if ( $Param{MimeType} && lc $Param{MimeType} eq 'text/html' ) {
        $Param{Body} =~ s{\Q<br/>\E}{<br />}xmsgi;
    }

    # map ReplyTo into Reply-To if present
    if ( $Param{ReplyTo} ) {
        $Param{'Reply-To'} = $Param{ReplyTo};
    }

    my @ExtractedImages;
    # extract images as cid
    if ( $Kernel::OM->Get('Config')->Get('SendmailEmbeddedImages') eq 'cid' ) {
        $Kernel::OM->Get('HTMLUtils')->EmbeddedImagesExtract(
            DocumentRef    => \$Param{Body},
            AttachmentsRef => \@ExtractedImages,
        );
    }

    # correct charset if necessary (KIX2018-8418)
    $Param{Charset} =~ s/utf8/utf-8/i;

    # build header
    my %Header;
    if ( IsHashRefWithData( $Param{CustomHeaders} ) ) {
        %Header = %{ $Param{CustomHeaders} };
    }
    ATTRIBUTE:
    for my $Attribute (qw(From To Cc Subject Charset Reply-To)) {
        next ATTRIBUTE if !$Param{$Attribute};
        $Header{$Attribute} = $Param{$Attribute};
    }

    my $IgnoreEmailPattern = $Kernel::OM->Get('Config')->Get('IgnoreEmailAddressesAsRecipients');
    for my $Attribute (qw(To Cc Bcc)) {
        if ( $Header{$Attribute} && $Header{$Attribute} =~ /$IgnoreEmailPattern/ ) {
            $Header{$Attribute} =~ s/$IgnoreEmailPattern//gi;
            $Header{$Attribute} =~ s/,\s*,/,/g;
        }
    }

    # loop
    if ( $Param{Loop} ) {
        $Header{'X-Loop'}          = 'yes';
        $Header{'Precedence:'}     = 'bulk';
        $Header{'Auto-Submitted:'} = "auto-generated";
    }

    # do some encode
    ATTRIBUTE:
    for my $Attribute (qw(From To Cc Subject)) {
        next ATTRIBUTE if !$Header{$Attribute};
        $Header{$Attribute} = $Self->_EncodeMIMEWords(
            Field   => $Attribute,
            Line    => $Header{$Attribute},
            Charset => $Param{Charset},
        );
    }

    # check if it's html, add text attachment
    my $HTMLEmail = 0;
    if ( $Param{MimeType} && $Param{MimeType} =~ /html/i ) {
        $HTMLEmail = 1;

        # add html as first attachment
        my $Attach = {
            Content     => $Param{Body},
            ContentType => "text/html; charset=\"$Param{Charset}\"",
            Filename    => '',
        };
        if ( !$Param{Attachment} ) {
            @{ $Param{Attachment} } = ($Attach);
        }
        else {
            @{ $Param{Attachment} } = ( $Attach, @{ $Param{Attachment} } );
        }

        # remember html body for later comparison
        $Param{HTMLBody} = $Param{Body};

        # add ascii body
        $Param{MimeType} = 'text/plain';
        $Param{Body}     = $Kernel::OM->Get('HTMLUtils')->ToAscii(
            String => $Param{Body},
        );

    }

    my $Product = $ConfigObject->Get('Product');
    my $Version = $ConfigObject->Get('Version');

    if ( $ConfigObject->Get('Secure::DisableBanner') ) {

        # Set this to undef to avoid having a value like "MIME-tools 5.507 (Entity 5.507)"
        #   which could lead to the mail being treated as SPAM.
        $Header{'X-Mailer'} = undef;
    }
    else {
        $Header{'X-Mailer'}     = "$Product Mail Service ($Version)";
        $Header{'X-Powered-By'} = 'KIX (https://www.kixdesk.com/)';
    }
    $Header{Type} = $Param{MimeType} || 'text/plain';

    # define email encoding
    if ( $Param{Charset} && $Param{Charset} =~ /^iso/i ) {
        $Header{Encoding} = '8bit';
    }
    else {
        $Header{Encoding} = 'quoted-printable';
    }

    # check if we need to force the encoding
    if ( $ConfigObject->Get('SendmailEncodingForce') ) {
        $Header{Encoding} = $ConfigObject->Get('SendmailEncodingForce');
    }

    # check and create message id
    if ( $Param{'Message-ID'} ) {
        $Header{'Message-ID'} = $Param{'Message-ID'};
    }
    else {
        $Header{'Message-ID'} = $Self->GenerateMessageID();
    }

    # save MessageID for later use
    my $MessageID = $Header{'Message-ID'};

    # add date header
    $Header{Date} = 'Date: ' . $Kernel::OM->Get('Time')->MailTimeStamp();

    # add organisation header
    my $Organization = $ConfigObject->Get('Organization');
    if ($Organization) {
        $Header{Organization} = $Self->_EncodeMIMEWords(
            Field   => 'Organization',
            Line    => $Organization,
            Charset => $Param{Charset},
        );
    }

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    # build MIME::Entity, Data should be bytes, not utf-8
    # see http://bugs.otrs.org/show_bug.cgi?id=9832
    $EncodeObject->EncodeOutput( \$Param{Body} );
    my $Entity = MIME::Entity->build( %Header, Data => $Param{Body} );

    # set In-Reply-To and References header
    my $Header = $Entity->head();
    if ( $Param{InReplyTo} ) {
        $Param{'In-Reply-To'} = $Param{InReplyTo};
    }
    KEY:
    for my $Key ( 'In-Reply-To', 'References' ) {
        next KEY if !$Param{$Key};
        $Header->replace( $Key, $Param{$Key} );
    }

    # add attachments to email
    if ( $Param{Attachment} || @ExtractedImages ) {
        my $Count    = 0;
        my $PartType = '';
        my @NewAttachments;
        ATTACHMENT:
        for my $Upload ( (@{ $Param{Attachment}}, @ExtractedImages) ) {

            # ignore attachment if no content is given
            next ATTACHMENT if !defined $Upload->{Content};

            # ignore attachment if no filename is given
            next ATTACHMENT if !defined $Upload->{Filename};

            # prepare ContentType for Entity Type. $Upload->{ContentType} has
            # useless `name` parameter, we don't need to send it to the `attach`
            # constructor. For more details see Bug #7879 and MIME::Entity.
            # Note: we should remove `name` attribute only.
            my @ContentTypeTmp = grep { !/\s*name=/ } ( split /;/, $Upload->{ContentType} );
            $Upload->{ContentType} = join ';', @ContentTypeTmp;

            # if it's a html email, add the first attachment as alternative (to show it
            # as alternative content)
            if ($HTMLEmail) {
                $Count++;
                if ( $Count == 1 ) {
                    $Entity->make_multipart('alternative;');
                    $PartType = 'alternative';
                }
                else {

                    # don't attach duplicate html attachment (aka file-2)
                    next ATTACHMENT if
                        $Upload->{Filename} eq 'file-2'
                        && $Upload->{ContentType} =~ /html/i
                        && $Upload->{Content} eq $Param{HTMLBody};

                    # skip, but remember all attachments except inline images
                    if (
                        ( !defined $Upload->{ContentID} )
                        || ( !defined $Upload->{ContentType} || $Upload->{ContentType} !~ /image/i )
                        || (
                            !defined $Upload->{Disposition}
                            || $Upload->{Disposition} ne 'inline'
                        )
                        )
                    {
                        push @NewAttachments, \%{$Upload};
                        next ATTACHMENT;
                    }

                    # add inline images as related
                    if ( $PartType ne 'related' ) {
                        $Entity->make_multipart(
                            'related;',
                            Force => 1,
                        );
                        $PartType = 'related';
                    }
                }
            }

            # content encode
            $EncodeObject->EncodeOutput( \$Upload->{Content} );

            # filename encode
            my $Filename = $Self->_EncodeMIMEWords(
                Field   => 'filename',
                Line    => $Upload->{Filename},
                Charset => $Param{Charset},
            );

            # format content id, leave undefined if no value
            my $ContentID = $Upload->{ContentID};
            if ( $ContentID && $ContentID !~ /^</ ) {
                $ContentID = '<' . $ContentID . '>';
            }

            # attach file to email
            $Entity->attach(
                Filename    => $Filename,
                Data        => $Upload->{Content},
                Type        => $Upload->{ContentType},
                Id          => $ContentID,
                Disposition => $Upload->{Disposition} || 'inline',
                Encoding    => $Upload->{Encoding} || '-SUGGEST',
            );
        }

        # add all other attachments as multipart mixed (if we had html body)
        for my $Upload (@NewAttachments) {

            # make multipart mixed
            if ( $PartType ne 'mixed' ) {
                $Entity->make_multipart(
                    'mixed;',
                    Force => 1,
                );
                $PartType = 'mixed';
            }

            # content encode
            $EncodeObject->EncodeOutput( \$Upload->{Content} );

            # filename encode
            my $Filename = $Self->_EncodeMIMEWords(
                Field   => 'filename',
                Line    => $Upload->{Filename},
                Charset => $Param{Charset},
            );

            my $Encoding = $Upload->{Encoding};
            if ( !$Encoding ) {

                # attachments of unknown text/* content types might be displayed directly in mail clients
                # because MIME::Entity detects them as 'quoted printable'
                # this causes problems e.g. for pdf files with broken text/pdf content type
                # therefore we fall back to 'base64' in these cases
                if (
                    $Upload->{ContentType} =~ m{ \A text/  }xmsi
                    && $Upload->{ContentType} !~ m{ \A text/ (?: plain | html ) ; }xmsi
                    )
                {
                    $Encoding = 'base64';
                }
                else {
                    $Encoding = '-SUGGEST';
                }
            }

            # attach file to email (no content id needed)
            $Entity->attach(
                Filename    => $Filename,
                Data        => $Upload->{Content},
                Type        => $Upload->{ContentType},
                Disposition => $Upload->{Disposition} || 'inline',
                Encoding    => $Encoding,
            );
        }
    }

    my @Flags;
    my %Sign = $Kernel::OM->Get('Certificate')->Sign(
        %Param,
        Entity => $Entity
    );

    if ( %Sign ) {
        push( @Flags, @{$Sign{Flags}} );

        if ( $Sign{Entity} ) {
            $Entity = $Sign{Entity};
        }
    }
    else {
        return {
            HeadRef => undef,
            BodyRef => undef,
            Flags   => [
                {
                    Key   => 'SMIMESigned',
                    Value => 1
                },
                {
                    Key   => 'SMIMESignedError',
                    Value => "Internal Error!"
                }
            ]
        };
    }

    my %Encrypt = $Kernel::OM->Get('Certificate')->Encrypt(
        %Param,
        Entity             => $Entity,
        IgnoreEmailPattern => $IgnoreEmailPattern
    );

    if ( %Encrypt ) {
        push( @Flags, @{$Encrypt{Flags}} );
        if (
            !$Encrypt{Successful}
            && $Param{Encrypt} == 1
        ) {
            return {
                HeadRef => undef,
                BodyRef => undef,
                Flags   => [
                    \@Flags,
                    {
                        Key   => 'RetryEncrypt',
                        Value => 1
                    }
                ]
            };
        }
        if ( $Encrypt{Entity} ) {
            $Entity = $Encrypt{Entity};
        }
    }
    else {
        return {
            HeadRef => undef,
            BodyRef => undef,
            Flags   => [
                {
                    Key   => 'SMIMEEncrypted',
                    Value => 1
                },
                {
                    Key   => 'SMIMEEncryptedError',
                    Value => "Internal Error!"
                },
                {
                    Key   => 'RetryEncrypt',
                    Value => $Param{Encrypt} ? 1 : 0
                }
            ]
        };
    }

    # get header from Entity
    my $Head = $Entity->head();
    $Param{Header} = $Head->as_string();

    # remove not needed folding of email heads, we do have many problems with email clients
    my @Headers = split( /\n/, $Param{Header} );

    # reset orig header
    $Param{Header} = q{};
    for my $Line (@Headers) {
        $Line =~ s/^    (.*)$/ $1/;

        # Perform own wrapping of long lines due to MIME::Tools problems (see bug#9345).
        #  MIME::Tools fails to wrap long lines where the Message-IDs are too long or
        #  directly concatenated without spaces in between.
        if ( $Line =~ m{^(References|In-Reply-To):}smx ) {
            $Line =~ s{(.{64,}?)>\s*<}{$1>\n <}sxmg;
        }
        $Param{Header} .= $Line . "\n";
    }

    # get body from Entity
    $Param{Body} = $Entity->body_as_string();

    # get recipients
    my @ToArray;

    RECIPIENT:
    for my $Recipient ( qw(To Cc Bcc) ) {
        next RECIPIENT if !$Param{$Recipient};
        for my $Email ( Email::Address::XS->parse($Param{$Recipient}) ) {
            my $EmailAddress = $Email->address();
            if ( $EmailAddress !~ /$IgnoreEmailPattern/gix ) {
                push(@ToArray, $EmailAddress);

            }
        }
    }

    # add Bcc recipients
    my $SendmailBcc = $ConfigObject->Get('SendmailBcc');
    if ( $SendmailBcc ) {
        for my $Email ( Email::Address::XS->parse($SendmailBcc) ) {
            my $EmailAddress = $Email->address();
            if ( $EmailAddress !~ /$IgnoreEmailPattern/gix ) {
                push(@ToArray, $SendmailBcc);
            }
        }
    }

    # set envelope sender for replies
    my $RealFrom = $ConfigObject->Get('SendmailEnvelopeFrom') || '';
    if ( !$RealFrom ) {
        my @Sender = Email::Address::XS->parse( $Param{From} );
        $RealFrom = $Sender[0]->address();
    }

    # set envelope sender for notifications
    if ( $Param{Loop} ) {
        my $NotificationEnvelopeFrom = $ConfigObject->Get('SendmailNotificationEnvelopeFrom') || q{};
        my $NotificationFallback     = $ConfigObject->Get('SendmailNotificationEnvelopeFrom::FallbackToEmailFrom');
        if (
            $NotificationEnvelopeFrom
            || !$NotificationFallback
        ) {
            $RealFrom = $NotificationEnvelopeFrom;
        }
    }

    # debug
    if ( $Self->{Debug} > 1 ) {
        my $To = join( q{,}, @ToArray );
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "Sent email to '$To' from '$RealFrom'. Subject => '$Param{Subject}';",
        );
    }

    # send email to backend
    my $Sent = $Self->{Backend}->Send(
        From    => $RealFrom,
        ToArray => \@ToArray,
        Header  => \$Param{Header},
        Body    => \$Param{Body},
    );

    if ( !$Sent ) {
        $Kernel::OM->Get('Log')->Log(
            Message  => "Error sending message",
            Priority => 'info',
        );
        return;
    }

    return {
        HeadRef => \$Param{Header},
        BodyRef => \$Param{Body},
        Flags   => \@Flags
    };
}

=item Check()

Check mail configuration

    my %Check = $SendObject->Check();

=cut

sub Check {
    my ( $Self, %Param ) = @_;

    my %Check = $Self->{Backend}->Check();

    if ( $Check{Successful} ) {
        return ( Successful => 1 )
    }
    else {
        return (
            Successful => 0,
            Message    => $Check{Message}
        );
    }
}

=item Bounce()

Bounce an email

    $SendObject->Bounce(
        From  => 'me@example.com',
        To    => 'friend@example.com',
        Email => $Email,
    );

=cut

sub Bounce {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(From To Email)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check and create message id
    my $MessageID = $Param{'Message-ID'} || $Self->GenerateMessageID();

    # split body && header
    my @EmailPlain = split( /\n/, $Param{Email} );
    my $EmailObject = Mail::Internet->new( \@EmailPlain );

    # get sender
    my @Sender   = Email::Address::XS->parse( $Param{From} );
    my $RealFrom = $Sender[0]->address();

    # add ReSent header (see https://www.ietf.org/rfc/rfc2822.txt A.3. Resent messages)
    my $HeaderObject = $EmailObject->head();
    $HeaderObject->replace( 'Resent-Message-ID', $MessageID );
    $HeaderObject->replace( 'Resent-To',         $Param{To} );
    $HeaderObject->replace( 'Resent-From',       $RealFrom );
    $HeaderObject->replace( 'Resent-Date',       $Kernel::OM->Get('Time')->MailTimeStamp() );
    my $Body         = $EmailObject->body();
    my $BodyAsString = '';
    for ( @{$Body} ) {
        $BodyAsString .= $_ . "\n";
    }
    my $HeaderAsString = $HeaderObject->as_string();

    # debug
    if ( $Self->{Debug} > 1 ) {
        my $OldMessageID = $HeaderObject->get('Message-ID') || '??';
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "Bounced email to '$Param{To}' from '$RealFrom'. "
                . "MessageID => '$OldMessageID';",
        );
    }

    my $Sent = $Self->{Backend}->Send(
        From    => $RealFrom,
        ToArray => [ $Param{To} ],
        Header  => \$HeaderAsString,
        Body    => \$BodyAsString,
    );

    return ( \$HeaderAsString, \$BodyAsString );
}

=item GenerateMessageID()

generate a new message id

    my $MessageID = $EmailObject->GenerateMessageID();

    returns

    $NewMessageID = '<1739230819.861376@example.com>';


=cut

sub GenerateMessageID {
    my ( $Self, %Param ) = @_;

    my $Time   = $Kernel::OM->Get('Time')->SystemTime();
    my $Random = $Kernel::OM->Get('Main')->GenerateRandomString(
        Length     => 6,
        Dictionary => [ 0..9 ],
    );
    my $FQDN   = $Kernel::OM->Get('Config')->Get('FQDN');
    if ( IsHashRefWithData($FQDN) ) {
        $FQDN = $FQDN->{Backend}
    }
    my $NewMessageID = '<' . $Time . '.' . $Random . '@' . $FQDN . '>';

    return $NewMessageID;
}

=begin Internal:

=cut

sub _EncodeMIMEWords {
    my ( $Self, %Param ) = @_;

    # return if no content is given
    return '' if !defined $Param{Line};

    return MIME::Words::encode_mimewords(
        Encode::encode(
            $Param{Charset},
            $Param{Line},
        ),
        Charset => $Param{Charset},

        # for line length calculation to fold lines (gets ignored by
        # MIME::Words, see pod of MIME::Words)
        Field => $Param{Field},
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
