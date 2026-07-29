# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::PostMaster;

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $HomeDir = $Kernel::OM->Get('Config')->Get('Home');

for my $TestIndex ( 1..3 ) {
    # check log when To header is missing
    my $Location = $HomeDir . '/scripts/test/system/sample/PostMaster/KIX2018-16772-Test' . $TestIndex . '.box';
    my $ContentRef = $Kernel::OM->Get('Main')->FileRead(
        Location => $Location,
        Mode     => 'binmode',
    );
    my @Return;
    {
        my $PostMasterObject = Kernel::System::PostMaster->new(
            Email => $ContentRef,
        );

        @Return = $PostMasterObject->Run();
    }

    $Self->Is(
        scalar(@Return),
        1,
        'TestIndex ' . $TestIndex . ': PostMaster returned one result'
    );
    $Self->Is(
        $Return[0][0],
        1,
        'TestIndex ' . $TestIndex . ': PostMaster created new ticket'
    );

    my %Article = $Kernel::OM->Get('Ticket')->ArticleFirstArticle(
        TicketID => $Return[0][1]
    );
    my %ArticleAttachmentIndex = $Kernel::OM->Get('Ticket')->ArticleAttachmentIndex(
        ArticleID                  => $Article{ArticleID},
        UserID                     => 1,
        Article                    => \%Article,
        StripPlainBodyAsAttachment => 2,
    );
    my %Attachment = $Kernel::OM->Get('Ticket')->ArticleAttachment(
        ArticleID    => $Article{ArticleID},
        AttachmentID => $Article{AttachmentIDOfHTMLBody},
        UserID       => 1,
        NoContent    => 0,
    );
    $Self->Is(
        $Attachment{Content},
        '<html><head></head><body><p>Mit freundlichen Gr&uuml;&szlig;en</p>
</body></html>',
        'TestIndex ' . $TestIndex . ': Expected HTML body'
    );
}

# rollback transaction on database
$Helper->Rollback();

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
