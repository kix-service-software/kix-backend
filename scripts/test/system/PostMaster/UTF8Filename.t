# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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

use Kernel::System::PostMaster;

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Config');
my $TicketObject = $Kernel::OM->Get('Ticket');
my $MainObject   = $Kernel::OM->Get('Main');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

$Helper->UseTmpArticleDir();

for my $Backend (qw(DB FS)) {

    $ConfigObject->Set(
        Key   => 'Ticket::StorageModule',
        Value => 'Kernel::System::Ticket::ArticleStorage' . $Backend,
    );

    my $Location = $ConfigObject->Get('Home')
        . "/scripts/test/system/sample/PostMaster/UTF8Filename.box";

    my $ContentRef = $MainObject->FileRead(
        Location => $Location,
        Mode     => 'binmode',
        Result   => 'ARRAY',
    );

    my $TicketID;
    {
        my $PostMasterObject = Kernel::System::PostMaster->new(
            Email => $ContentRef,
        );

        my @Return = $PostMasterObject->Run();
        @Return = @{ $Return[0] || [] };

        $TicketID = $Return[1];
    }

    $Self->True(
        $TicketID,
        "$Backend - Ticket created",
    );

    my @ArticleIDs = $TicketObject->ArticleIndex( TicketID => $TicketID );
    $Self->True(
        $ArticleIDs[0],
        "$Backend - Article created",
    );

    my %Attachments = $TicketObject->ArticleAttachmentIndex(
        ArticleID => $ArticleIDs[0],
        UserID    => 1,
    );

    $Self->IsDeeply(
        $Attachments{1},
        {
            ContentAlternative => '',
            ContentID          => '',
            Filesize           => '132 Bytes',
            ContentType        => 'application/pdf; name="=?UTF-8?Q?Documentacio=CC=81n=2Epdf?="',
            Filename           => 'Documentación.pdf',
            FilesizeRaw        => '132',
            Disposition        => 'attachment'
        },
        "$Backend - Attachment filename",
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
