# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Placeholder::Article;

use strict;
use warnings;

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Placeholder::Base);

our @ObjectDependencies = (
    'HTMLUtils',
    'Log',
    'Ticket',
    'Config',
    'Main'
);

=head1 NAME

Kernel::System::Placeholder::Article

=cut

=begin Internal:

=cut

sub _Replace {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Text UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    $Self->{TicketObject} = $Kernel::OM->Get('Ticket');

    # replace article placeholders
    my $Tag = $Self->{Start} . 'KIX_ARTICLE_';

    # FIXME: keep old placeholder syntax for backward compatibility
    my $OldTag = $Self->{Start} . 'KIX_ARTICLE_DATA_';

    if ($Param{Text} =~ m/$Tag/ || $Param{Text} =~ m/$OldTag/) {
        $Param{ArticleID} ||= IsHashRefWithData($Param{Data}) ? $Param{Data}->{ArticleID} : undef;
        $Param{ArticleID} ||= IsHashRefWithData($Param{DataAgent}) ? $Param{DataAgent}->{ArticleID} : undef;
        if (IsArrayRefWithData($Param{ArticleID})) {
            $Param{ArticleID} = $Param{ArticleID}->[0];
        }
        if ( $Param{ArticleID} ) {
            my %Article = $Self->{TicketObject}->ArticleGet(
                ArticleID => $Param{ArticleID},
            );

            $Param{Text} = $Self->_ReplaceArticlePlaceholders(
                %Param,
                Tag     => "(?:$Tag|$OldTag)",
                Article => \%Article
            );

            # replace it
            $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, "$Tag|$OldTag", %Article );
        }

        # cleanup
        $Param{Text} =~ s/(?:$Tag|$OldTag).+?$Self->{End}/$Param{ReplaceNotFound}/gi;
    }

    # replace first article placeholders
    $Tag = $Self->{Start} . 'KIX_FIRST_';
    if ($Param{Text} =~ m/$Tag/) {
        if ( $Param{TicketID} && $Param{Text} =~ /$Tag.+$Self->{End}/i ) {
            my %Article = $Self->{TicketObject}->ArticleFirstArticle(
                TicketID => $Param{TicketID},
            );

            $Param{Text} = $Self->_ReplaceArticlePlaceholders(
                %Param,
                Tag     => $Tag,
                Article => \%Article
            );

            # replace it
            $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, $Tag, %Article );
        }

        # cleanup all not needed <KIX_FIRST_ tags
        $Param{Text} =~ s/$Tag.+?$Self->{End}/-/gi;
    }

    # replace last article placeholders
    $Tag = $Self->{Start} . 'KIX_LAST_';
    if ($Param{Text} =~ m/$Tag/) {
        if ( $Param{TicketID} && $Param{Text} =~ /$Tag.+$Self->{End}/i ) {
            my %Article = $Self->{TicketObject}->ArticleLastArticle(
                TicketID => $Param{TicketID},
            );

            $Param{Text} = $Self->_ReplaceArticlePlaceholders(
                %Param,
                Tag     => $Tag,
                Article => \%Article
            );

            # replace it
            $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, $Tag, %Article );
        }

        # cleanup all not needed <KIX_LAST_ tags
        $Param{Text} =~ s/$Tag.+?$Self->{End}/$Param{ReplaceNotFound}/gi;
    }

    # place last agent article placeholders
    $Tag = $Self->{Start} . 'KIX_AGENT_';
    if ($Param{Text} =~ m/$Tag/) {
        if ( $Param{TicketID} && $Param{Text} =~ /$Tag.+$Self->{End}/i ) {
            my @ArticleIDs = $Self->{TicketObject}->ArticleIndex(
                SenderType => 'agent',
                TicketID   => $Param{TicketID}
            );
            my %Article = @ArticleIDs ? $Self->{TicketObject}->ArticleGet(
                ArticleID     => $ArticleIDs[-1]
            ) : ();

            $Param{Text} = $Self->_ReplaceArticlePlaceholders(
                %Param,
                Tag     => $Tag,
                Article => \%Article
            );
        }

        # cleanup all not needed <KIX_AGENT_ tags
        $Param{Text} =~ s/$Tag.+?$Self->{End}/$Param{ReplaceNotFound}/gi;
    }

    # replace last external article placeholders
    $Tag = $Self->{Start} . 'KIX_CUSTOMER_';
    if ($Param{Text} =~ m/$Tag/) {
        if ( $Param{TicketID} && $Param{Text} =~ /$Tag.+$Self->{End}/i ) {
            my @ArticleIDs = $Self->{TicketObject}->ArticleIndex(
                SenderType      => 'external',
                CustomerVisible => 1,
                TicketID        => $Param{TicketID}
            );
            my %Article = @ArticleIDs ? $Self->{TicketObject}->ArticleGet(
                ArticleID     => $ArticleIDs[-1]
            ) : ();

            $Param{Text} = $Self->_ReplaceArticlePlaceholders(
                %Param,
                Tag     => $Tag,
                Article => \%Article
            );
        }

        # cleanup all not needed <KIX_CUSTOMER_ tags
        $Param{Text} =~ s/$Tag.+?$Self->{End}/$Param{ReplaceNotFound}/gi;
    }

    return $Param{Text};
}

sub _ReplaceArticlePlaceholders {
    my ( $Self, %Param ) = @_;

    # add (simple) ID
    $Param{Article}->{ID} = $Param{Article}->{ArticleID};

    # replace <KIX_$Param{Tag}_Subject/Body_xx> tags
    for my $Attribute ( qw(Subject Body) ) {
        my $Tag = $Param{Tag} . $Attribute;

        my @Matches = $Param{Text} =~ /$Tag\_\d+?$Self->{End}/g;
        for my $Match (@Matches) {
            my $AttributeValue = $Param{Article}->{$Attribute};
            next if !defined $AttributeValue;

            my $CharLength = $Match;
            $CharLength =~ s/.+_(\d+).+/$1/;

            $AttributeValue =~ s/^(.{$CharLength}).*$/$1 [...]/;

            $Param{Text} =~ s/$Match/$AttributeValue/g;
        }
    }

    # html quoting of content
    if ( $Param{RichText} ) {
        for ( keys %{$Param{Article}} ) {
            next if !$Param{Article}->{$_};
            $Param{Article}->{$_} = $Kernel::OM->Get('HTMLUtils')->ToHTML(
                String => $Param{Article}->{$_},
            );
        }
    }

    # add html body content if necessary
    if ( $Param{Text} =~ /$Param{Tag}BodyRichtext_?\d*?$Self->{End}/g ) {
        $Param{Text} = $Self->_ReplaceBodyRichtext(
            Tag        => "$Param{Tag}BodyRichtext",
            Text       => $Param{Text},
            Article    => $Param{Article},
            UserID     => $Param{UserID},
            WithInline => 1
        );
    }
    if ( $Param{Text} =~ /$Param{Tag}BodyRichtextNoInline_?\d*?$Self->{End}/g ) {
        $Param{Text} = $Self->_ReplaceBodyRichtext(
            Tag     => "$Param{Tag}BodyRichtextNoInline",
            Text    => $Param{Text},
            Article => $Param{Article},
            UserID  => $Param{UserID}
        );
    }

    # replace it
    return $Self->_HashGlobalReplace( $Param{Text}, $Param{Tag}, %{$Param{Article}} );
}

sub _ReplaceBodyRichtext {
    my ( $Self, %Param ) = @_;

    my $BodyRichtext = $Param{Article}->{Body};
    my @InlineAttachments;

    my %AttachmentIndex = $Self->{TicketObject}->ArticleAttachmentIndex(
        ContentPath                => $Param{Article}->{ContentPath},
        ArticleID                  => $Param{Article}->{ArticleID},
        StripPlainBodyAsAttachment => 2,
        UserID                     => $Param{UserID},
    );

    if (IsHashRefWithData(\%AttachmentIndex)) {
        for my $AttachmentID ( keys %AttachmentIndex ) {

            # only inline attachments relevant
            next if (
                !$AttachmentIndex{ $AttachmentID }->{Disposition}
                || $AttachmentIndex{ $AttachmentID }->{Disposition} ne 'inline'
            );

            if ( $AttachmentIndex{$AttachmentID}->{Filename} eq 'file-2') {
                my %Attachment = $Self->{TicketObject}->ArticleAttachment(
                    ArticleID    => $Param{Article}->{ArticleID},
                    AttachmentID => $AttachmentID,
                    UserID       => $Param{UserID},
                );

                if (IsHashRefWithData(\%Attachment)) {
                    my $Charset = $Attachment{ContentType} || '';
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

                    if (!$Param{WithInline}) {
                        # remove inline images
                        $BodyRichtext =~ s/<img.+?src=["']?cid:.+?>//gs;
                    }
                }
            } elsif ($AttachmentIndex{$AttachmentID}->{ContentID} && $Param{WithInline}) {
                my %Attachment = $Self->{TicketObject}->ArticleAttachment(
                    ArticleID    => $Param{Article}->{ArticleID},
                    AttachmentID => $AttachmentID,
                    UserID       => $Param{UserID},
                );
                if (IsHashRefWithData(\%Attachment)) {
                    push(@InlineAttachments, \%Attachment);
                }
            }
        }
    }

    if ($BodyRichtext) {
        my %PreparedInline;
        if (scalar @InlineAttachments) {
            $BodyRichtext =~ s/src=(?!["\'])(cid:[^\s\/\>\"\']+)/src="$1"/g;
            for my $Attachment ( @InlineAttachments ) {
                my $Content = MIME::Base64::encode_base64( $Attachment->{Content}, '' );

                my $ContentType = $Attachment->{ContentType};
                $ContentType =~ s/"/\'/g;

                my $ReplaceString = "data:$ContentType;base64,$Content";

                # remove < and > arround id (eg. <123456> ==> 1323456)
                my $ContentID = substr($Attachment->{ContentID}, 1, -1);
                $PreparedInline{$ContentID} = $ReplaceString;
            }
        }

        my @Matches = $Param{Text} =~ /$Param{Tag}_?\d*?$Self->{End}/g;
        @Matches = $Kernel::OM->Get('Main')->GetUnique(@Matches);

        for my $Match (@Matches) {

            # if line count is given in placeholder
            if ($Match =~ /_(\d+)/) {
                my $LineCount = $1;
                my $PreparedBody = $Self->_GetPreparedBody(
                    Body      => $BodyRichtext,
                    Inline    => \%PreparedInline,
                    LineCount => $LineCount
                );
                $Param{Text} =~ s/$Param{Tag}_$LineCount$Self->{End}/$PreparedBody/g;
            }
            # else use config
            else {
                my $LineCount = $Kernel::OM->Get('Config')->Get('Ticket::Placeholder::BodyRichtext::DefaultLineCount') || 0;
                my $PreparedBody = $Self->_GetPreparedBody(
                    Body      => $BodyRichtext,
                    Inline    => \%PreparedInline,
                    LineCount => $LineCount
                );
                $Param{Text} =~ s/$Param{Tag}$Self->{End}/$PreparedBody/g;

            }
        }
    }

    return $Param{Text};
}

sub _GetPreparedBody {
    my ( $Self, %Param ) = @_;

    my $PreparedBody = $Param{Body};

    # do nothing (full body, no limit) if undefined or 0
    if ($Param{LineCount} && $Param{LineCount} =~ /^\d+$/ && $Param{LineCount} > 0) {
        my @Lines = split(/\n/, $Param{Body});

        if (scalar @Lines > $Param{LineCount}) {
            $PreparedBody = $Self->_CloseTags(
                Body => join("\n",splice(@Lines,0,$Param{LineCount}))
            );
            $PreparedBody .= "\n[...]";
        }
    }

    # add images if needed and given
    if ($PreparedBody =~ /<img.+?src="cid:.+?>/s && IsHashRefWithData($Param{Inline})) {
        for my $ContentID ( keys %{$Param{Inline}} ) {
            $PreparedBody =~ s/cid:$ContentID/$Param{Inline}->{$ContentID}/g;
        }
    }

    return $PreparedBody;
}

sub _CloseTags {
    my ( $Self, %Param ) = @_;

    # get all opening and closing tags but not self closing ones and ignore some specific
    # e.g. <div>, <p class...> but not <br /> or <img src... />
    my @StartTags = grep {defined && $_ !~ /^(area|base|br|col|command|embed|hr|img|input|keygen|link|meta|param|source|track|wbr)$/} $Param{Body} =~ /(?:<([^!\s\/>]+)(?:\s+[^\/>]+)?>)/gs;
    my @EndTags   = grep {defined && $_ !~ /^(area|base|br|col|command|embed|hr|img|input|keygen|link|meta|param|source|track|wbr)$/} $Param{Body} =~ /<\/(.+?)>/g;

    my @ReversedStartTags = reverse @StartTags;

    # rember only opening tags with no closing counterpart
    if (@EndTags) {

        # remove now closed tags (start with last opened)
        for my $Tag (reverse @EndTags) {
            my $Index = -1;
            for my $OpenedTag (@ReversedStartTags) {
                $Index++;
                last if ($OpenedTag eq $Tag);
            }
            if ($Index != -1) {
                splice(@ReversedStartTags,$Index,1);
            }
        }
    }

    # add closing tags if needed (start with last - use reversed)
    for my $Tag (@ReversedStartTags) {
        $Param{Body} .= "\n</$Tag>";
    }

    return $Param{Body};
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
