# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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

use Kernel::System::EmailParser;

my $Home = $Kernel::OM->Get('Config')->Get('Home');

my @Tests = (
    {
        Name     => "plain email with ascii and utf-8 part",
        RawEmail => "$Home/scripts/test/system/sample/EmailParser/MultipartMixedPlain.eml",
        Body     => 'first part



second part äöø',
        Attachments => [

            # Look for the concatenated plain body part that was converted to utf-8.
            {
                'Charset' => 'utf-8',
                'Content' => 'first part



second part äöø',
                'ContentID'       => undef,
                'ContentLocation' => undef,
                'ContentType'     => 'text/plain; charset=utf-8',
                'Disposition'     => undef,
                'Filename'        => 'file-1',
                'Filesize'        => 32,
                'MimeType'        => 'text/plain'
            },

            # Look for the attachment.
            {
                'Charset'            => '',
                'Content'            => "1\n",
                'ContentDisposition' => "attachment; filename=1.txt\n",
                'ContentID'          => undef,
                'ContentLocation'    => undef,
                'ContentType'        => 'text/plain; name="1.txt"',
                'Disposition'        => 'attachment; filename=1.txt',
                'Filename'           => '1.txt',
                'Filesize'           => 2,
                'MimeType'           => 'text/plain'
            }
        ],
    },
    {
        Name     => "HTML email with ascii and utf-8 part",
        RawEmail => "$Home/scripts/test/system/sample/EmailParser/MultipartMixedHTML.eml",
        Body     => 'first part



second part äöø',
        Attachments => [

            # Look for the plain body part.
            {
                'Charset' => 'utf-8',
                'Content' => 'first part



second part äöø',
                'ContentAlternative' => 1,
                'ContentID'          => undef,
                'ContentLocation'    => undef,
                'ContentType'        => 'text/plain; charset=utf-8',
                'Disposition'        => undef,
                'Filename'           => 'file-1',
                'Filesize'           => 32,
                'MimeType'           => 'text/plain'
            },

            # Look for the concatenated HTML body part that was converted to utf-8.
            {
                'Charset' => 'utf-8',
                'Content' =>
                    '<html><head><meta http-equiv="Content-Type" content="text/html charset=utf-8"></head><body style="word-wrap: break-word; -webkit-nbsp-mode: space; -webkit-line-break: after-white-space;" class=""><b class="">first</b> part<div class=""><br class=""></div><div class=""></div></body></html><html><head><meta http-equiv="Content-Type" content="text/html charset=utf-8"></head><body style="word-wrap: break-word; -webkit-nbsp-mode: space; -webkit-line-break: after-white-space;" class=""><div class=""></div><div class=""><br class=""></div><div class="">second part äöø</div></body></html>',
                'ContentAlternative' => 1,
                'ContentID'          => undef,
                'ContentLocation'    => undef,
                'ContentType'        => 'text/html; charset=utf-8',
                'Disposition'        => undef,
                'Filename'           => 'file-2',
                'Filesize'           => 590,
                'MimeType'           => 'text/html'
            },

            # Look for the attachment.
            {
                'Charset'            => '',
                'Content'            => "1\n",
                'ContentAlternative' => 1,
                'ContentDisposition' => "attachment; filename=1.txt\n",
                'ContentID'          => undef,
                'ContentLocation'    => undef,
                'ContentType'        => 'text/plain; name="1.txt"',
                'Disposition'        => 'attachment; filename=1.txt',
                'Filename'           => '1.txt',
                'Filesize'           => 2,
                'MimeType'           => 'text/plain'
            }
        ],
    },
);

for my $Test (@Tests) {
    my @Array;
    open my $IN, '<', $Test->{RawEmail};    ## no critic
    while (<$IN>) {
        push @Array, $_;
    }
    close $IN;

    # create local object
    my $EmailParserObject = Kernel::System::EmailParser->new(
        Email => \@Array,
    );

    my @Attachments = $EmailParserObject->GetAttachments();
    my $Body        = $EmailParserObject->GetMessageBody();

    $Self->Is(
        $Body,
        $Test->{Body},
        "Test->{Name} - body",
    );

    # Turn on utf-8 flag for parts that were not converted but are still utf-8 for correct comparison.
    for my $Attachment (@Attachments) {
        if ( $Attachment->{Charset} eq 'utf-8' ) {
            Encode::_utf8_on( $Attachment->{Content} );
        }
    }

    $Self->IsDeeply(
        \@Attachments,
        $Test->{Attachments},
        "$Test->{Name} - attachments"
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
