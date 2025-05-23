# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::EmailParser;

use strict;
use warnings;

use Mail::Internet;
use MIME::Parser;
use MIME::QuotedPrint;
use MIME::Base64;
use MIME::Words qw(:all);
use Email::Address::XS;
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::EmailParser - parse and encode an email

=head1 SYNOPSIS

A module to parse and encode an email.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::EmailParser;
    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();

    # as string (takes more memory!)
    my $ParserObject = Kernel::System::EmailParser->new(
        Email        => $EmailString,
        Debug        => 0,
    );

    # as stand alone mode, without parsing emails
    my $ParserObject = Kernel::System::EmailParser->new(
        Mode         => 'Standalone',
        Debug        => 0,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get debug level from parent
    $Self->{Debug} = $Param{Debug} || 0;

    if ( $Param{Mode} && $Param{Mode} eq 'Standalone' ) {
        return $Self;
    }

    # check needed objects
    if ( !$Param{Email} && !$Param{Entity} ) {
        die "Need Email or Entity!";
    }

    # if email is given
    if ( $Param{Email} ) {

        my @Email;
        # check if Email is an scalar ref
        if ( ref $Param{Email} eq 'SCALAR' ) {
            my @Content = split( /\n/, ${ $Param{Email} } );
            for my $Line (@Content) {
                $Line .= "\n";
            }
            @Email = @Content;
        }

        # check if Email is not an ref
        elsif ( ref $Param{Email} eq q{} ) {
            my @Content = split( /\n/, $Param{Email} );
            for my $Line (@Content) {
                $Line .= "\n";
            }
            @Email = @Content;
        }
        else {
            @Email = @{$Param{Email}}
        }

        if ( !$Param{NoDecrypt} ) {
            # decrypt email if needed
            my $DecryptedRef = $Kernel::OM->Get('Certificate')->Decrypt(
                Content => \@Email,
                Type    => 'Email'
            );

            if ( IsHashRefWithData($DecryptedRef) ) {
                $Self->{Decrypt} = $DecryptedRef->{Flags};
                @Email = @{$DecryptedRef->{Content}};
                $Self->{DecryptErr} = !$DecryptedRef->{Successful};
            }
            elsif ( !$DecryptedRef ) {
                # sets DecryptErr to 1 if a decryption problem exists
                # Can be queried as WHAT in GetParam.
                $Self->{DecryptErr} = 1;
            }
        }

        if ( !$Param{NoVerify} ) {
            # verify email if needed
            my $VerifyRef = $Kernel::OM->Get('Certificate')->Verify(
                Type    => 'Email',
                Content => \@Email
            );

            if ( IsHashRefWithData($VerifyRef) ) {
                $Self->{Verify} = $VerifyRef->{Flags};
                @Email = @{$VerifyRef->{Content}};
            }
        }
        # create Mail::Internet object
        $Self->{Email} = Mail::Internet->new( \@Email );

        # create a Mail::Header object with email
        $Self->{HeaderObject} = $Self->{Email}->head();

        # create MIME::Parser object and get message body or body of first attachment
        my $Parser = MIME::Parser->new();
        $Parser->output_to_core('ALL');

        # Keep nested messages as attachments (see bug#1970).
        $Parser->extract_nested_messages(0);
        $Self->{ParserParts} = $Parser->parse_data( $Self->{Email}->as_string() );
    }
    else {
        $Self->{ParserParts} = $Param{Entity};
        $Self->{EntityMode}  = 1;
    }

    # get NoHTMLChecks param
    if ( $Param{NoHTMLChecks} ) {
        $Self->{NoHTMLChecks} = $Param{NoHTMLChecks};
    }

    # parse email at first
    $Self->GetMessageBody();

    return $Self;
}

=item GetPlainEmail()

To get a email as a string back (plain email).

    my $Email = $ParserObject->GetPlainEmail();

=cut

sub GetPlainEmail {
    my $Self = shift;

    return $Self->{Email}->as_string();
}

=item GetParam()

To get a header (e. g. Subject, To, ContentType, ...) of an email
(mime is already done!).

    my $To = $ParserObject->GetParam( WHAT => 'To' );

=cut

sub GetParam {
    my ( $Self, %Param ) = @_;

    my $What = $Param{WHAT} || return;

    if ( !$Self->{Email} || !$Self->{HeaderObject} ) {

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Email and HeaderObject is needed!',
        );
        return;
    }

    # First we need to check Decrypt and Verify
    # since these values are not part of the header object
    if ( $What =~ /^(Decrypt|Verify)$/ ) {
        return $Self->{$What} || q{};
    }

    # Return boolean if a decryption problem exists
    # Is required in the PostMaster
    if ( $What eq 'DecryptErr' ) {
        return $Self->{$What} || 0;
    }

    $Self->{HeaderObject}->unfold();
    $Self->{HeaderObject}->combine($What);
    my $Line = $Self->{HeaderObject}->get($What) || q{};
    chomp($Line);
    my $ReturnLine;

    # We need to split address lists before decoding; see "6.2. Display of 'encoded-word's"
    # in RFC 2047. Email::Address::XS routines will quote stuff if necessary (i.e. comma
    # or semicolon found in phrase).
    if ( $What =~ /^(From|To|Cc)/ ) {
        for my $Address ( Email::Address::XS->parse($Line) ) {
            $Address->phrase( $Self->_DecodeString( String => $Address->phrase() ) );
            $Address->address( $Self->_DecodeString( String => $Address->address() ) );
            $Address->comment( $Self->_DecodeString( String => $Address->comment() ) );
            $ReturnLine .= q{, } if $ReturnLine;
            $ReturnLine .= $Address->format();
        }
    }
    else {
        $ReturnLine = $Self->_DecodeString( String => $Line );
    }

    $ReturnLine //= q{};

    # debug
    if ( $Self->{Debug} > 1 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'debug',
            Message  => "Get: $What; ReturnLine: $ReturnLine; OrigLine: $Line",
        );
    }

    return $ReturnLine;
}

=item GetEmailHead()

To get the senders email address back.

    my $HeadRef = $ParserObject->GetEmailHead();

=cut

sub GetEmailHead {
    my ( $Self, %Param ) = @_;

    if ( !$Self->{Email} ) {

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Email is needed!',
        );
        return;
    }

    my $Head = $Self->{Email}->head();

    if ( $Param{NoSMIMEContent} ) {
        $Head->delete('MIME-Version');
        $Head->delete('Content-Type');
        $Head->delete('Content-Disposition');
        $Head->delete('Content-Description');
        $Head->delete('Content-Transfer-Encoding');
    }

    my @NewHeader = map { "$_\n" } split( /\n/, $Head->as_string());

    # return email header
    return \@NewHeader;
}

=item GetEmailAddress()

To get the senders email address back.

    my $SenderEmail = $ParserObject->GetEmailAddress(
        Email => 'Juergen Weber <juergen.qeber@air.com>',
    );

=cut

sub GetEmailAddress {
    my ( $Self, %Param ) = @_;

    my $Email = q{};
    for my $EmailSplit ( $Self->_MailAddressParse( Email => $Param{Email} ) ) {
        $Email = $EmailSplit->address();
    }

    # return if no email address is there
    return if $Email !~ /@/;

    # return email address
    return $Email;
}

=item GetRealname()

To get the senders realname back.

    my $Realname = $ParserObject->GetRealname(
        Email => 'Juergen Weber <juergen.qeber@air.com>',
    );

=cut

sub GetRealname {
    my ( $Self, %Param ) = @_;
    my $Realname = q{};

    # find "NamePart, NamePart" <some@example.com> (get not recognized by Email::Address::XS)
    if ( $Param{Email} =~ /"(.+?)"\s+?\<.+?@.+?\..+?\>/ ) {
        $Realname = $1;

        # removes unnecessary blank spaces, if the string has quotes.
        # This is because of bug 6059
        $Realname =~ s/"\s+?(.+?)\s+?"/"$1"/g;
        return $Realname;
    }

    # fallback of Email::Address::XS
    for my $EmailSplit ( $Self->_MailAddressParse( Email => $Param{Email} ) ) {
        $Realname = $EmailSplit->phrase();
    }

    return $Realname;
}

=item SplitAddressLine()

To get an array of email addresses of an To, Cc or Bcc line back.

    my @Addresses = $ParserObject->SplitAddressLine(
        Line => 'Juergen Weber <juergen.qeber@air.com>, me@example.com, hans@example.com (Hans Huber)',
    );

This returns an array with ('Juergen Weber <juergen.qeber@air.com>', 'me@example.com', 'hans@example.com (Hans Huber)').

=cut

sub SplitAddressLine {
    my ( $Self, %Param ) = @_;

    my @GetParam;
    for my $Line ( $Self->_MailAddressParse( Email => $Param{Line} ) ) {
        push @GetParam, $Line->format();
    }

    return @GetParam;
}

=item GetContentType()

Returns the message body (or from the first attachment) "ContentType" header.

    my $ContentType = $ParserObject->GetContentType();

(e. g. 'text/plain; charset="iso-8859-1"')

=cut

sub GetContentType {
    my $Self = shift;

    return $Self->{ContentType} if $Self->{ContentType};

    return $Self->GetParam( WHAT => 'Content-Type' ) || 'text/plain';
}

=item GetCharset()

Returns the message body (or from the first attachment) "charset".

    my $Charset = $ParserObject->GetCharset();

(e. g. iso-8859-1, utf-8, ...)

=cut

sub GetCharset {
    my $Self = shift;

    # return charset of already defined
    if ( defined $Self->{Charset} ) {

        # debug
        if ( $Self->{Debug} > 0 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "Got charset from mime body: $Self->{Charset}",
            );
        }
        return $Self->{Charset};
    }

    if ( !$Self->{Email} || !$Self->{HeaderObject} ) {

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Email and HeaderObject is needed!',
        );
        return;
    }

    # find charset
    $Self->{HeaderObject}->unfold();
    my $Line = $Self->{HeaderObject}->get('Content-Type') || q{};
    chomp $Line;
    my %Data = $Self->GetContentTypeParams( ContentType => $Line );

    # check content type (only do charset decode if no Content-Type or ContentType
    # with text/* exists) if it's not a text content type (e. g. pdf, png, ...),
    # return no charset
    if ( $Data{ContentType} && $Data{ContentType} !~ /text/i ) {

        # debug
        if ( $Self->{Debug} > 0 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message =>
                    "Got no charset from email body because of ContentType ($Data{ContentType})!",
            );
        }

        # remember charset
        $Self->{Charset} = q{};

        # return charset
        return q{};
    }

    # return charset if it can be detected
    if ( $Data{Charset} ) {

        # debug
        if ( $Self->{Debug} > 0 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "Got charset from email body: $Data{Charset}",
            );
        }

        # remember charset
        $Self->{Charset} = $Data{Charset};

        # return charset
        return $Data{Charset};
    }

    # if there is no available header for charset and content type, use
    # iso-8859-1 as charset

    # debug
    if ( $Self->{Debug} > 0 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'debug',
            Message  => 'Got no charset from email body! Take iso-8859-1!',
        );
    }

    # remember charset
    $Self->{Charset} = 'ISO-8859-1';

    # return charset
    return 'ISO-8859-1';
}

=item GetReturnContentType()

Returns the new message body (or from the first attachment) "ContentType" header
(maybe the message is converted to utf-8).

    my $ContentType = $ParserObject->GetReturnContentType();

(e. g. 'text/plain; charset="utf-8"')

=cut

sub GetReturnContentType {
    my $Self = shift;

    my $ContentType = $Self->GetContentType();
    $ContentType =~ s/(charset=)(.*)/$1utf-8/ig;

    # debug
    if ( $Self->{Debug} > 0 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'debug',
            Message  => "Changed ContentType from '"
                . $Self->GetContentType()
                . "' to '$ContentType'.",
        );
    }
    return $ContentType;
}

=item GetReturnCharset()

Returns the charset of the new message body "Charset"
(maybe the message is converted to utf-8).

    my $Charset = $ParserObject->GetReturnCharset();

(e. g. 'text/plain; charset="utf-8"')

=cut

sub GetReturnCharset {
    my $Self = shift;

    return 'utf-8';
}

=item GetMessageBody()

Returns the message body (or from the first attachment) from the email.

    my $Body = $ParserObject->GetMessageBody();

=cut

sub GetMessageBody {
    my ( $Self, %Param ) = @_;

    # check if message body is already there
    return $Self->{MessageBody} if $Self->{MessageBody};

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    if ( !$Self->{EntityMode} && $Self->{ParserParts}->parts() == 0 ) {
        $Self->{MimeEmail} = 0;
        if ( $Self->{Debug} > 0 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => 'It\'s a plain (not mime) email!',
            );
        }
        my $BodyStrg = join( q{}, @{ $Self->{Email}->body() } );

        # quoted printable!
        if ( $Self->GetParam( WHAT => 'Content-Transfer-Encoding' ) =~ /quoted-printable/i ) {
            $BodyStrg = MIME::QuotedPrint::decode($BodyStrg);
        }

        # base64 decode
        elsif ( $Self->GetParam( WHAT => 'Content-Transfer-Encoding' ) =~ /base64/i ) {
            $BodyStrg = decode_base64($BodyStrg);
        }

        # charset decode
        if ( $Self->GetCharset() ) {
            $Self->{MessageBody} = $EncodeObject->Convert2CharsetInternal(
                Text  => $BodyStrg,
                From  => $Self->GetCharset(),
                Check => 1,
            );
        }
        else {
            $Self->{MessageBody} = $BodyStrg;
        }

        # check if the mail contains only HTML (store it as attachment and add text/plain)
        $Self->CheckMessageBody();

        # return message body
        return $Self->{MessageBody};
    }
    else {
        $Self->{MimeEmail} = 1;
        if ( $Self->{Debug} > 0 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => 'It\'s a mime email!',
            );
        }

        # Check if there is a valid attachment there, if yes, return
        #   the first attachment (normally text/plain) as message body.
        # For multipart/mixed emails, PartsAttachments() will concatenate subsequent
        #   body MIME parts into just one attachment.
        my @Attachments = $Self->GetAttachments();
        if ( @Attachments > 0 ) {
            $Self->{Charset}     = $Attachments[0]->{Charset};
            $Self->{ContentType} = $Attachments[0]->{ContentType};
            if ( $Self->{Debug} > 0 ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'debug',
                    Message  => "First attachment ContentType: $Self->{ContentType}",
                );
            }

            # check if charset is given, set iso-8859-1 if content is text
            if ( !$Self->{Charset} && $Self->{ContentType} =~ /\btext\b/ ) {
                $Self->{Charset} = 'iso-8859-1';
            }

            # check if charset exists
            if ( $Self->GetCharset() ) {
                $Self->{MessageBody} = $EncodeObject->Convert2CharsetInternal(
                    Text  => $Attachments[0]->{Content},
                    From  => $Self->GetCharset(),
                    Check => 1,
                );
            }
            else {
                $Self->{Charset}     = 'us-ascii';
                $Self->{ContentType} = 'text/plain';
                $Self->{MessageBody} = '- no text message => see attachment -';
            }

            # check if it's a html-only email (store it as attachment and add text/plain)
            $Self->CheckMessageBody();

            # return message body
            return $Self->{MessageBody};
        }
        else {
            if ( $Self->{Debug} > 0 ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'debug',
                    Message =>
                        'No attachments returned from GetAttachments(), just an empty attachment!?',
                );
            }

            # return empty attachment
            $Self->{Charset}     = 'iso-8859-1';
            $Self->{ContentType} = 'text/plain';
            return q{-};
        }
    }

    return;
}

=item GetAttachments()

Returns an array of the email attachments.

    my @Attachments = $ParserObject->GetAttachments();
    for my $Attachment (@Attachments) {
        print $Attachment->{Filename};
        print $Attachment->{Charset};
        print $Attachment->{MimeType};
        print $Attachment->{ContentType};
        print $Attachment->{Content};

        # optional
        print $Attachment->{ContentID};
        print $Attachment->{ContentAlternative};
        print $Attachment->{ContentMixed};
    }

=cut

sub GetAttachments {
    my ( $Self, %Param ) = @_;

    # return if it's no mime email
    return if !$Self->{MimeEmail};

    # return if it is already parsed
    return @{ $Self->{Attachments} } if $Self->{Attachments};

    # parse email
    $Self->PartsAttachments( Part => $Self->{ParserParts} );

    # return if no attachments are found
    return if !$Self->{Attachments};

    # return attachments
    return @{ $Self->{Attachments} };
}

# just for internal
sub PartsAttachments {
    my ( $Self, %Param ) = @_;

    my $Part               = $Param{Part}               || $Self->{ParserParts};
    my $PartCounter        = $Param{PartCounter}        || 0;
    my $SubPartCounter     = $Param{SubPartCounter}     || 0;
    my $ContentAlternative = $Param{ContentAlternative} || q{};
    my $ContentMixed       = $Param{ContentMixed}       || q{};
    $Self->{PartCounter}++;
    if ( $Part->parts() > 0 ) {

        # check if it's an alternative part
        $Part->head()->unfold();
        $Part->head()->combine('Content-Type');
        my $ContentType = $Part->head()->get('Content-Type');
        if ( $ContentType && $ContentType =~ /multipart\/alternative;/i ) {
            $ContentAlternative = 1;
        }
        if ( $ContentType && $ContentType =~ /multipart\/mixed;/i ) {
            $ContentMixed = 1;
        }
        $PartCounter++;
        for my $Part ( $Part->parts() ) {
            $SubPartCounter++;
            if ( $Self->{Debug} > 0 ) {
                print STDERR "Sub part($PartCounter/$SubPartCounter)!\n";
            }
            $Self->PartsAttachments(
                Part               => $Part,
                PartCounter        => $PartCounter,
                ContentAlternative => $ContentAlternative,
                ContentMixed       => $ContentMixed,
            );
        }
        return 1;
    }

    # get attachment meta stuff
    my %PartData;

    if ($ContentAlternative) {
        $PartData{ContentAlternative} = $ContentAlternative;
    }

    # get ContentType
    $Part->head()->unfold();
    $Part->head()->combine('Content-Type');

    # get Content-Type, use text/plain if no content type is given
    $PartData{ContentType} = $Part->head()->get('Content-Type') || 'text/plain;';
    chomp $PartData{ContentType};

    # get mime type
    $PartData{MimeType} = $Part->head()->mime_type();

    # get charset
    my %Data = $Self->GetContentTypeParams( ContentType => $PartData{ContentType} );
    if ( $Data{Charset} ) {
        $PartData{Charset} = $Data{Charset};
    }
    else {
        $PartData{Charset} = q{};
    }

    # get content (if possible)
    if ( $Part->bodyhandle() ) {
        $PartData{Content} = $Part->bodyhandle()->as_string();
        if ( !$PartData{Content} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "Totally empty attachment part ($PartCounter)",
            );
        }
    }

    # log error if there is an corrupt MIME email
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message =>
                "Was not able to parse corrupt MIME email! Skipped attachment ($PartCounter)",
        );
        return;
    }

    # check if there is no recommended_filename or subject -> add file-NoFilenamePartCounter
    if ( $Part->head()->recommended_filename() ) {
        $PartData{Filename} = $Self->_DecodeString(
            String => $Part->head()->recommended_filename(),
            Encode => 'utf-8',
        );
        $PartData{ContentDisposition} = $Part->head()->get('Content-Disposition');
        if ( $PartData{ContentDisposition} ) {
            my %Data = $Self->GetContentTypeParams(
                ContentType => $PartData{ContentDisposition},
            );
            if ( $Data{Charset} ) {
                $PartData{Charset} = $Data{Charset};
            }
        }
        else {
            $PartData{Charset} = q{};
        }

        # check if reserved filename file-1 or file-2 is already used
        COUNT:
        for my $Count ( 1 .. 2 ) {
            if ( $PartData{Filename} eq "file-$Count" ) {
                $PartData{Filename} = "File-$Count";
                last COUNT;
            }
        }
    }

    # Guess the filename for nested messages (see bug#1970).
    elsif ( $PartData{ContentType} eq 'message/rfc822' ) {

        my ($SubjectString) = $Part->as_string() =~ m/^Subject: ([^\n]*(\n[ \t][^\n]*)*)/m;
        my $Subject = $Self->_DecodeString( String => $SubjectString );

        # trim whitespace
        $Subject =~ s/^\s+|\n|\s+$//g;
        if ( length($Subject) > 246 ) {
            $Subject = substr( $Subject, 0, 246 );
        }

        if ( $Subject eq q{} ) {
            $Self->{NoFilenamePartCounter}++;
            $Subject = "Unbenannt-$Self->{NoFilenamePartCounter}";
        }
        $PartData{Filename} = $Subject . '.eml';
    }
    else {
        $Self->{NoFilenamePartCounter}++;
        $PartData{Filename} = "file-$Self->{NoFilenamePartCounter}";
    }

    # parse/get Content-Id, Content-Location and Disposition for html email attachments
    $PartData{ContentID}       = $Part->head()->get('Content-Id');
    $PartData{ContentLocation} = $Part->head()->get('Content-Location');
    $PartData{Disposition}     = $Part->head()->get('Content-Disposition');

    if ( $PartData{ContentID} ) {
        chomp $PartData{ContentID};
    }
    elsif ( $PartData{ContentLocation} ) {
        chomp $PartData{ContentLocation};
        $PartData{ContentID} = $PartData{ContentLocation};
    }
    if ( $PartData{Disposition} ) {
        chomp $PartData{Disposition};
        $PartData{Disposition} = lc $PartData{Disposition}
    }

    # get attachment size
    $PartData{Filesize} = bytes::length( $PartData{Content} );

    # debug
    if ( $Self->{Debug} > 0 ) {
        print STDERR
            "->GotArticle::Atm: '$PartData{Filename}' '$PartData{ContentType}' ($PartData{Filesize})\n";
    }

    # For multipart/mixed emails, we check for all text/plain or text/html MIME parts which are
    #   body elements, and concatenate them into the first relevant attachment, to stay in line
    #   with file-1 and file-2 attachment handling.
    # HTML parts will just be concatenated, so that the attachment has two complete HTML documents
    #   inside. Browsers tolerate this.
    if (
        $ContentMixed
        && ( !$PartData{Disposition} || $PartData{Disposition} eq 'inline' )
        && ( $PartData{ContentType} =~ /text\/(?:html|plain)/i )
        )
    {
        # Is it a plain or HTML body?
        my $MimeType = $PartData{ContentType} =~ /text\/html/i ? 'text/html' : 'text/plain';
        my $AttachmentKey = 'AttachmentFor_' . $MimeType;

        # For concatenating multipart/mixed text parts, we have to convert all of them to utf-8 to be sure that
        #   the contents fit together and that all characters can be displayed.
        $PartData{Content} = $Kernel::OM->Get('Encode')->Convert2CharsetInternal(
            Text  => $PartData{Content},
            From  => $PartData{Charset},
            Check => 1,
        );
        $PartData{ContentType} = "$MimeType; charset=utf-8";
        my $OldCharset = $PartData{Charset};
        $PartData{Charset} = "utf-8";

        # Also replace charset in meta tags of HTML emails.
        if ( $MimeType eq 'text/html' ) {
            $PartData{Content} =~ s/(<meta[^>]+charset=("|'|))\Q$OldCharset\E/$1utf-8/gi;
        }

        $PartData{Filesize} = bytes::length( $PartData{Content} );

        # Is it the first body element found? Then remember it.
        if ( !$Self->{$AttachmentKey} ) {
            $Self->{$AttachmentKey} = \%PartData;
        }

        # Is it a subsequent body element? Then concatenate it to the first one and skip it as attachment.
        else {
            # This concatenation only works if all parts have the utf-8 flag on (from Convert2CharsetInternal).
            $Self->{$AttachmentKey}->{Content} .= $PartData{Content};
            $Self->{$AttachmentKey}->{Filesize} += $PartData{Filesize};
            return 1;    # Don't create an attachment for this part.
        }
    }

    push @{ $Self->{Attachments} }, \%PartData;
    return 1;
}

=item GetReferences()

To get an array of reference ids of the parsed email

    my @References = $ParserObject->GetReferences();

This returns an array with ('fasfda@host.de', '4124.2313.1231@host.com').

=cut

sub GetReferences {
    my ( $Self, %Param ) = @_;

    # get references ids
    my @ReferencesAll;
    my $ReferencesString = $Self->GetParam( WHAT => 'References' );
    if ($ReferencesString) {
        push @ReferencesAll, ( $ReferencesString =~ /<([^>]+)>/g );
    }

    # get in reply to id
    my $InReplyToString = $Self->GetParam( WHAT => 'In-Reply-To' );
    if ($InReplyToString) {
        chomp $InReplyToString;
        $InReplyToString =~ s/.*?<([^>]+)>.*/$1/;
        push @ReferencesAll, $InReplyToString;
    }

    # get uniq
    my %Checked;
    my @References;
    for ( reverse @ReferencesAll ) {
        if ( !$Checked{$_} ) {
            push @References, $_;
        }
        $Checked{$_} = 1;
    }
    return @References;
}

# just for internal
sub GetContentTypeParams {
    my ( $Self, %Param ) = @_;

    my $ContentType = $Param{ContentType} || return;
    if ( $Param{ContentType} =~ /charset\s*=.+?/i ) {
        $Param{Charset} = $Param{ContentType};
        $Param{Charset} =~ s/.*?charset\s*=\s*(.*?)/$1/i;
        $Param{Charset} =~ s/"|'//g;
        $Param{Charset} =~ s/(.+?)(;|\s).*/$1/g;
    }
    if ( !$Param{Charset} ) {
        if (
            $Param{ContentType}
            =~ /\?(iso-\d{3,4}-(\d{1,2}|[A-z]{1,2})|utf(-8|8)|windows-\d{3,5}|koi8-.+?|cp(-|)\d{2,4}|big5(|.+?)|shift(_|-)jis|euc-.+?|tcvn|visii|vps|gb.+?)\?/i
            )
        {
            $Param{Charset} = $1;
        }
        elsif ( $Param{ContentType} =~ /name\*0\*=(utf-8|utf8)/i ) {
            $Param{Charset} = $1;
        }
        elsif (
            $Param{ContentType}
            =~ /filename\*=(iso-\d{3,4}-(\d{1,2}|[A-z]{1,2})|utf(-8|8)|windows-\d{3,5}|koi8-.+?|cp(-|)\d{2,4}|big5(|.+?)|shift(_|-)jis|euc-.+?|tcvn|visii|vps|gb.+?)''/i
            )
        {
            $Param{Charset} = $1;
        }
    }
    if ( $Param{ContentType} =~ /Content-Type:\s{0,1}(.+?\/.+?)(;|'|"|\s)/i ) {
        $Param{MimeType} = $1;
        $Param{MimeType} =~ s/"|'//g;
    }
    return %Param;
}

# just for internal
sub CheckMessageBody {
    my ( $Self, %Param ) = @_;

    # if already checked, just return
    return if $Self->{MessageChecked};

    # return if no auto convert from html2text is needed
    return if !$Kernel::OM->Get('Config')->Get('PostmasterAutoHTML2Text');

    # return if no auto convert from html2text is needed
    return if $Self->{NoHTMLChecks};

    # check if it's just a html email (store it as attachment and add text/plain)
    if ( $Self->GetReturnContentType() =~ /text\/html/i ) {
        $Self->{MessageChecked} = 1;

        # add html email as attachment (if needed)
        if ( !$Self->{MimeEmail} ) {
            push(
                @{ $Self->{Attachments} },
                {
                    Charset     => $Self->GetCharset(),
                    ContentType => $Self->GetReturnContentType(),
                    Content     => $Self->{MessageBody},
                    Filename    => 'file-1',
                }
            );
        }

        # add .html suffix to filename if not aleady there
        else {
            if ( $Self->{Attachments}->[0]->{Filename} ) {
                if ( $Self->{Attachments}->[0]->{Filename} !~ /\.(htm|html)/i ) {
                    $Self->{Attachments}->[0]->{Filename} .= '.html';
                }
            }
        }

        # remember to be a mime email now
        $Self->{MimeEmail} = 1;

        # convert from html to ascii
        $Self->{MessageBody} = $Kernel::OM->Get('HTMLUtils')->ToAscii(
            String => $Self->{MessageBody},
        );

        $Self->{ContentType} = 'text/plain';
        if ( $Self->{Debug} > 0 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message =>
                    'It\'s an html only email, added ascii dump, attached html email as attachment.',
            );
        }
    }

    return;
}

=begin Internal:

=item _DecodeString()

Decode all encoded substrings.

    my $Result = $Self->_DecodeString(
        String => 'some text',
    );

=cut

sub _DecodeString {
    my ( $Self, %Param ) = @_;

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    my $DecodedString;
    my $BufferedString;
    my $PrevEncoding;

    $BufferedString = q{};

    # call MIME::Words::decode_mimewords()
    for my $Entry ( decode_mimewords( $Param{String} ) ) {
        if (
            $BufferedString ne q{}
            && ( !$PrevEncoding || !$Entry->[1] || lc($PrevEncoding) ne lc( $Entry->[1] ) )
            )
        {
            my $Encoding = $EncodeObject->FindAsciiSupersetEncoding(
                Encodings => [ $PrevEncoding, $Param{Encode}, $Self->GetCharset() ],
            );
            $DecodedString .= $EncodeObject->Convert2CharsetInternal(
                Text  => $BufferedString,
                From  => $Encoding,
                Check => 1,
            );
            $BufferedString = q{};
        }
        $BufferedString .= $Entry->[0];
        $PrevEncoding = $Entry->[1];
    }

    if ( $BufferedString ne q{} ) {
        my $Encoding = $EncodeObject->FindAsciiSupersetEncoding(
            Encodings => [ $PrevEncoding, $Param{Encode}, $Self->GetCharset() ],
        );
        $DecodedString .= $EncodeObject->Convert2CharsetInternal(
            Text  => $BufferedString,
            From  => $Encoding,
            Check => 1,
        );
    }

    return $DecodedString;
}

=item _MailAddressParse()

    my @Chunks = $ParserObject->_MailAddressParse(Email => $Email);

Wrapper for C<Email::Address::XS->parse($Email)>, but cache it, since it's
not too fast, and often called.

=cut

sub _MailAddressParse {
    my ( $Self, %Param ) = @_;

    my $Email = $Param{Email};
    my $Cache = $Self->{EmailCache};

    if ( $Self->{EmailCache}->{$Email} ) {
        return @{ $Self->{EmailCache}->{$Email} };
    }

    my @Chunks = Email::Address::XS->parse($Email);
    $Self->{EmailCache}->{$Email} = \@Chunks;

    return @Chunks;
}

=end Internal:


1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
