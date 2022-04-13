# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get layout object
my $LayoutObject = $Kernel::OM->Get('Output::HTML::Layout');

# rich text tests
my @Tests = (
    {
        Name => '_RichTextReplaceLinkOfInlineContent() - generated by outlook',
        String =>
            '<img alt="" src="/kix-cvs/kix-cvs/bin/cgi-bin/index.pl?Action=PictureUpload&amp;FormID=1255961382.1012148.29113074&amp;ContentID=&lt;734083011@19102009-1795&gt;" />',
        Result => '<img alt="" src="cid:&lt;734083011@19102009-1795&gt;" />',
    },
    {
        Name => '_RichTextReplaceLinkOfInlineContent() - generated itself',
        String =>
            '<img width="343" height="563" alt="" src="/kix-cvs/kix-cvs/bin/cgi-bin/index.pl?Action=PictureUpload&amp;FormID=1255961382.1012148.29113074&amp;ContentID=inline244217.547683276.1255961382.1012148.29113074@vo7.vo.kixdesk.com" />',
        Result =>
            '<img width="343" height="563" alt="" src="cid:inline244217.547683276.1255961382.1012148.29113074@vo7.vo.kixdesk.com" />',
    },
    {
        Name => '_RichTextReplaceLinkOfInlineContent() - generated itself, with newline',
        String =>
            "<img width=\"343\" height=\"563\" alt=\"\"\nsrc=\"/kix-cvs/kix-cvs/bin/cgi-bin/index.pl?Action=PictureUpload&amp;FormID=1255961382.1012148.29113074&amp;ContentID=inline244217.547683276.1255961382.1012148.29113074\@vo7.vo.kixdesk.com\" />",
        Result =>
            "<img width=\"343\" height=\"563\" alt=\"\"\nsrc=\"cid:inline244217.547683276.1255961382.1012148.29113074\@vo7.vo.kixdesk.com\" />",
    },
    {
        Name =>
            '_RichTextReplaceLinkOfInlineContent() - generated itself, with internal and external image',
        String =>
            '<img width="140" vspace="10" hspace="1" height="38" border="0" alt="AltText" src="http://www.kixdesk.com/fileadmin/templates/skins/skin_kix/css/images/logo.gif" /> This text should be displayed <img width="400" height="81" border="0" alt="Description: cid:image001.jpg@01CC3AFE.F81F0B30" src="/kix/index.pl?Action=PictureUpload&amp;FormID=1311080525.12118416.3676164&amp;ContentID=image001.jpg@01CC4216.1E22E9A0" id="Picture_x0020_1" />',
        Result =>
            '<img width="140" vspace="10" hspace="1" height="38" border="0" alt="AltText" src="http://www.kixdesk.com/fileadmin/templates/skins/skin_kix/css/images/logo.gif" /> This text should be displayed <img width="400" height="81" border="0" alt="Description: cid:image001.jpg@01CC3AFE.F81F0B30" src="cid:image001.jpg@01CC4216.1E22E9A0" id="Picture_x0020_1" />',
    },
    {
        Name =>
            '_RichTextReplaceLinkOfInlineContent() - generated itself, with internal and external image, no space before />',
        String =>
            '<img width="140" vspace="10" hspace="1" height="38" border="0" alt="AltText" src="http://www.kixdesk.com/fileadmin/templates/skins/skin_kix/css/images/logo.gif" /> This text should be displayed <img width="400" height="81" border="0" alt="Description: cid:image001.jpg@01CC3AFE.F81F0B30" src="/kix/index.pl?Action=PictureUpload&amp;FormID=1311080525.12118416.3676164&amp;ContentID=image001.jpg@01CC4216.1E22E9A0" id="Picture_x0020_1"/>',
        Result =>
            '<img width="140" vspace="10" hspace="1" height="38" border="0" alt="AltText" src="http://www.kixdesk.com/fileadmin/templates/skins/skin_kix/css/images/logo.gif" /> This text should be displayed <img width="400" height="81" border="0" alt="Description: cid:image001.jpg@01CC3AFE.F81F0B30" src="cid:image001.jpg@01CC4216.1E22E9A0" id="Picture_x0020_1"/>',
    },
    {
        Name =>
            '_RichTextReplaceLinkOfInlineContent() - generated itself, ContentID in src, > just after src',
        String =>
            '<img src="/app/index.pl?Action=PictureUpload&amp;FormID=1111111111.2222222.33333333&amp;ContentID=test1@test"></img>',
        Result =>
            '<img src="cid:test1@test"></img>',
    },
    {
        Name =>
            '_RichTextReplaceLinkOfInlineContent() - generated itself, ContentID in other attribute than src, ContentID in src also',
        String =>
            '<img src="/app/index.pl?Action=PictureUpload&amp;FormID=1111111111.2222222.33333333&amp;ContentID=test1@test" other_attribute_with_different_contentid="ContentID=test2@test" style="color: #000;">',
        Result =>
            '<img src="cid:test1@test" other_attribute_with_different_contentid="ContentID=test2@test" style="color: #000;">',
    },
    {
        Name =>
            '_RichTextReplaceLinkOfInlineContent() - generated itself, ContentID in other attribute than src, no ContentID in src',
        String =>
            '<img src="/app/index.pl?Action=PictureUpload&amp;FormID=1111111111.2222222.33333333" other_attribute_with_different_contentid="ContentID=test2@test" style="color: #000;">',
        Result =>
            '<img src="/app/index.pl?Action=PictureUpload&amp;FormID=1111111111.2222222.33333333" other_attribute_with_different_contentid="ContentID=test2@test" style="color: #000;">',
    },
);

for my $Test (@Tests) {
    my $HTML = $LayoutObject->_RichTextReplaceLinkOfInlineContent(
        String => \$Test->{String},
    );
    $Self->Is(
        ${$HTML} || '',
        $Test->{Result},
        $Test->{Name},
    );
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
