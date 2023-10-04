# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLToPDF::Object::Article;

use strict;
use warnings;

use base qw(
    Kernel::System::HTMLToPDF::Object::Common
);

our @ObjectDependencies = (
    "Config",
    "DB",
    "Log",
);

use Kernel::System::VariableCheck qw(:all);
use MIME::Base64 qw(encode_base64);

sub GetParams {
    my ( $Self, %Param) = @_;

    return {
        IDKey => 'ArticleID',
    };
}

sub GetPossibleExpands {
    my ( $Self, %Param) = @_;

    return [
        'DynamicField'
    ];
}

sub CheckParams {
    my ( $Self, %Param) = @_;

    for my $Needed ( qw(ArticleID) ) {
        if ( !$Param{$Needed} ) {
            return {
                error => "No given $Needed!"
            }
        }
    }

    return 1;
}

sub DataGet {
    my ($Self, %Param) = @_;

    my $TicketObject    = $Kernel::OM->Get('Ticket');
    my $LinkObject      = $Kernel::OM->Get('LinkObject');
    my $ConfigObject    = $Kernel::OM->Get('Config');
    my $EncodeObject    = $Kernel::OM->Get('Encode');
    my $HTMLUtilsObject = $Kernel::OM->Get('HTMLUtils');
    my $LayoutObject    = $Kernel::OM->Get('Output::HTML::Layout');

    my %Article;
    my %Expands;
    my %Filters;

    if ( IsArrayRefWithData($Param{Expands}) ) {
        %Expands = map { $_ => 1 } @{$Param{Expands}};
    }
    elsif( $Param{Expands} ) {
        %Expands = map { $_ => 1 } split( /[,]/smx, $Param{Expands});
    }

    my %ExpendFunc = (
        DynamicField => '_GetDynamicFields',
    );

    if (
        $Param{Filters}
        && $Param{Filters}->{Article}
        && IsHashRefWithData($Param{Filters}->{Article})
    ) {
        %Filters = %{$Param{Filters}->{Article}};
    }

    if ( !%Article ) {
        %Article = $TicketObject->ArticleGet(
            ArticleID => $Article{ArticleID} || $Param{ArticleID},
            UserID    => $Param{UserID}
        );

        $TicketObject->ArticleAttachmentIndex(
            ArticleID                  => $Article{ArticleID} || $Param{ArticleID},
            UserID                     => $Param{UserID},
            Article                    => \%Article,
            StripPlainBodyAsAttachment => 1,
        );

        if ($Article{AttachmentIDOfHTMLBody}) {

            # html quoting
            $Article{Body} = $LayoutObject->Ascii2Html(
                NewLine => $ConfigObject->Get('DefaultViewNewLine'),
                Text    => $Article{Body},
                VMax    => $ConfigObject->Get('DefaultViewLines') || 5000,
            );

            my %AttachmentHTML = $TicketObject->ArticleAttachment(
                ArticleID => $Article{ArticleID},
                FileID    => $Article{AttachmentIDOfHTMLBody},
                UserID    => $Param{UserID},
            );

            my $Charset = $AttachmentHTML{ContentType} || q{};
            $Charset =~ s/.+?charset=("|'|)(\w+)/$2/gi;
            $Charset =~ s/"|'//g;
            $Charset =~ s/(.+?);.*/$1/g;

            my $Body = $AttachmentHTML{Content};
            # convert html body to correct charset
            $Body = $EncodeObject->Convert(
                Text => $Body,
                From => $Charset,
                To   => 'utf-8',
            );

            # add url quoting
            $Body = $HTMLUtilsObject->LinkQuote(
                String => $Body,
            );
            # strip head, body and meta elements
            $Body = $HTMLUtilsObject->DocumentStrip(
                String => $Body,
            );

            my %AttachmentIndex = $TicketObject->ArticleAttachmentIndex(
                ArticleID => $Article{ArticleID},
                UserID    => $Param{UserID},
            );

            my %Attachments = %AttachmentIndex;
            $Body =~ s{
                (=|"|')cid:(.*?)("|'|>|\/>|\s)
            }
            {
                my $Start= $1;
                my $ContentID = $2;
                my $End = $3;
                # improve html quality
                if ( $Start ne '"' && $Start ne '\'' ) {
                    $Start .= '"';
                }
                if ( $End ne '"' && $End ne '\'' ) {
                    $End = '"' . $End;
                }

                # find attachment to include
                ATMCOUNT:
                for my $AttachmentID ( sort keys %Attachments ) {

                    if ( lc $Attachments{$AttachmentID}->{ContentID} ne lc "<$ContentID>" ) {
                        next ATMCOUNT;
                    }

                    # get whole attachment
                    my %AttachmentPicture = $TicketObject->ArticleAttachment(
                        ArticleID => $Article{ArticleID},
                        FileID    => $AttachmentID,
                        UserID    => $Param{UserID},
                    );
                    ## encode content zo base64
                    my $Base64Content = encode_base64($AttachmentPicture{Content});
                    my ($ContentType) = $AttachmentPicture{ContentType} =~ /^(.*\/.*;)/msx;

                    # find cid, add attachment URL and remember, file is already uploaded
                    $ContentID = 'data:' . $ContentType . ';base64,' . $Base64Content;
                }

                # return link
                $Start . $ContentID . $End;
            }egxi;

            # scale image
            $Body =~ s/(<img[^>]+style="[^"]*)width:[0-9]+px([^"]*"[^>]*>)/$1$2/g;
            $Body =~ s/(<img[^>]+style="[^"]*)height:[0-9]+px([^"]*"[^>]*>)/$1$2/g;
            $Body =~ s/(<img[^>]+)style="[\s;]*"([^>]*>)/$1$2/g;
            if ($Body =~ m/<img[^>]+style="/) {
                $Body =~ s/(<img[^>]+style=")([^>]+>)/$1width:auto;max-width:612px;height:auto;$2/g;
            } else {
                $Body =~ s/(<img)([^>]+>)/$1 style="width:auto;max-width:612px;height:auto;" $2/g;
            }

            # strip head, body and meta elements
            $Article{Body} = $Body;
        }
        else {
            # convert plain to html
            $Article{Body} = $Kernel::OM->Get('HTMLUtils')->ToHTML(
                String => $Article{Body}
            );
        }
    }
    else {
        %Article = %{$Param{Data}};
    }

    my $DynamicFields;
    if ( %Expands ) {
        for my $Expand ( keys %Expands ) {
            my $Function = $ExpendFunc{$Expand};

            next if !$Function;

            $Self->$Function(
                Expands  => $Expands{$Expand} || 0,
                ObjectID => $Article{ArticleID} || $Param{ArticleID},
                UserID   => $Param{UserID},
                Type     => 'Article',
                Data     => \%Article,
            );

            if ( $Expand eq 'DynamicField' ) {
                $DynamicFields = $Article{Expands}->{DynamicFied};
            }
        }
    }

    if ( %Filters ) {
        my $Match = $Self->_Filter(
            Data   => {
                %Article,
                %{$DynamicFields || {}},
                ArticleNumber => $Param{Count}
            },
            Filter => \%Filters
        );

        return if !$Match;
    }

    return \%Article;
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