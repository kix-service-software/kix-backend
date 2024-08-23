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

use Unicode::Normalize;

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

$Helper->UseTmpArticleDir();

my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'Some Ticket_Title',
    Queue          => 'Junk',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'closed',
    OrganisationID => '123465',
    ContactID      => 'customer@example.com',
    OwnerID        => 1,
    UserID         => 1,
);
$Self->True(
    $TicketID,
    'TicketCreate()',
);

my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID       => $TicketID,
    Channel        => 'note',
    SenderType     => 'agent',
    From           => 'Some Agent <email@example.com>',
    To             => 'Some Customer <customer-a@example.com>',
    Subject        => 'some short description',
    Body           => 'the message text',
    ContentType    => 'text/plain; charset=ISO-8859-15',
    HistoryType    => 'OwnerUpdate',
    HistoryComment => 'Some free text!',
    UserID         => 1,
    NoAgentNotify  => 1,                                          # if you don't want to send agent notifications
);

$Self->True(
    $ArticleID,
    'ArticleCreate()',
);

for my $File (
    qw(Ticket-Article-Test1.xls Ticket-Article-Test1.txt Ticket-Article-Test1.doc
    Ticket-Article-Test1.png Ticket-Article-Test1.pdf Ticket-Article-Test-utf8-1.txt Ticket-Article-Test-utf8-1.bin)
    )
{
    my $Location = $Kernel::OM->Get('Config')->Get('Home')
        . "/scripts/test/system/sample/Ticket/$File";
    my $ContentRef = $Kernel::OM->Get('Main')->FileRead(
        Location => $Location,
        Mode     => 'binmode',
    );

    for my $FileName (
        'SimpleFile',
        'ÄÖÜカスタマ-',          # Unicode NFC
        'Второй_файл',    # Unicode NFD
        )
    {
        my $Content                = ${$ContentRef};
        my $FileNew                = $FileName . $File;
        my $MD5Orig                = $Kernel::OM->Get('Main')->MD5sum( String => $Content );
        my $ArticleWriteAttachment = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
            Content     => $Content,
            Filename    => $FileNew,
            ContentType => 'image/png',
            ArticleID   => $ArticleID,
            UserID      => 1,
        );
        $Self->True(
            $ArticleWriteAttachment,
            "ArticleWriteAttachment() - $FileNew",
        );

        my %AttachmentIndex = $Kernel::OM->Get('Ticket')->ArticleAttachmentIndex(
            ArticleID => $ArticleID,
            UserID    => 1,
        );

        my $TargetFilename = $FileName . $File;
        # Mac OS (HFS+) will store all filenames as NFD internally.
        if ( $^O eq 'darwin' ) {
            $TargetFilename = Unicode::Normalize::NFD($TargetFilename);
        }

        for my $AttachmentID ( sort( keys( %AttachmentIndex ) ) ) {
            $Self->Is(
                $AttachmentIndex{ $AttachmentID }->{Filename},
                $TargetFilename,
                "ArticleAttachmentIndex() Filename - $FileNew"
            );

            my %Data = $Kernel::OM->Get('Ticket')->ArticleAttachment(
                ArticleID    => $ArticleID,
                AttachmentID => $AttachmentID,
                UserID       => 1,
            );
            $Self->True(
                $Data{Content},
                "ArticleAttachment() Content - $FileNew",
            );
            $Self->True(
                $Data{ContentType},
                "ArticleAttachment() ContentType - $FileNew",
            );
            $Self->True(
                $Data{Content} eq $Content,
                "ArticleWriteAttachment() / ArticleAttachment() - $FileNew",
            );
            $Self->True(
                $Data{ContentType} eq 'image/png',
                "ArticleWriteAttachment() / ArticleAttachment() - $File",
            );
            my $MD5New = $Kernel::OM->Get('Main')->MD5sum( String => $Data{Content} );
            $Self->Is(
                $MD5Orig || '1',
                $MD5New  || '2',
                "MD5 - $FileNew",
            );
            my $Delete = $Kernel::OM->Get('Ticket')->ArticleDeleteAttachment(
                ArticleID => $ArticleID,
                UserID    => 1,
            );
            $Self->True(
                $Delete,
                "ArticleDeleteAttachment() - $FileNew",
            );

            %AttachmentIndex = $Kernel::OM->Get('Ticket')->ArticleAttachmentIndex(
                ArticleID => $ArticleID,
                UserID    => 1,
            );

            $Self->IsDeeply(
                \%AttachmentIndex,
                {},
                "ArticleAttachmentIndex() after delete - $FileNew"
            );
        }
    }
}

# Store file 2 times
my $FileName               = "[Terminology Guide äöß].pdf";
my $Content                = '123';
my $FileNew                = $FileName;
my $ArticleWriteAttachment = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
    Content     => $Content,
    Filename    => $FileNew,
    ContentType => 'image/png',
    ArticleID   => $ArticleID,
    UserID      => 1,
);
$Self->True(
    $ArticleWriteAttachment,
    "ArticleWriteAttachment() - collision check created $FileNew",
);

$ArticleWriteAttachment = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
    Content     => $Content,
    Filename    => $FileNew,
    ContentType => 'image/png',
    ArticleID   => $ArticleID,
    UserID      => 1,
);
$Self->True(
    $ArticleWriteAttachment,
    "ArticleWriteAttachment() - collision check created $FileNew second time",
);

my %AttachmentIndex = $Kernel::OM->Get('Ticket')->ArticleAttachmentIndex(
    ArticleID => $ArticleID,
    UserID    => 1,
);

my $TargetFilename = '[Terminology Guide äöß]';
# Mac OS (HFS+) will store all filenames as NFD internally.
if ( $^O eq 'darwin' ) {
    $TargetFilename = Unicode::Normalize::NFD($TargetFilename);
}

$Self->Is(
    scalar keys %AttachmentIndex,
    2,
    "ArticleWriteAttachment() - collision check number of attachments",
);

my ($Entry1) = grep { $AttachmentIndex{$_}->{Filename} eq "$TargetFilename.pdf" } keys %AttachmentIndex;
my ($Entry2) = grep { $AttachmentIndex{$_}->{Filename} eq "$TargetFilename-1.pdf" } keys %AttachmentIndex;

$Self->IsDeeply(
    $AttachmentIndex{$Entry1},
    {
        'ContentAlternative' => '',
        'ContentID'          => '',
        'ContentType'        => 'image/png',
        'Filename'           => "$TargetFilename.pdf",
        'Filesize'           => '3 Bytes',
        'FilesizeRaw'        => '3',
        'Disposition'        => 'attachment',
        'ID'                 => $Entry1,
    },
    "ArticleAttachmentIndex - collision check entry 1",
);

$Self->IsDeeply(
    $AttachmentIndex{$Entry2},
    {
        'ContentAlternative' => '',
        'ContentID'          => '',
        'ContentType'        => 'image/png',
        'Filename'           => "$TargetFilename-1.pdf",
        'Filesize'           => '3 Bytes',
        'FilesizeRaw'        => '3',
        'Disposition'        => 'attachment',
        'ID'                 => $Entry2,
    },
    "ArticleAttachmentIndex - collision check entry 2",
);

my $Delete = $Kernel::OM->Get('Ticket')->ArticleDeleteAttachment(
    ArticleID => $ArticleID,
    UserID    => 1,
);

$Self->True(
    $Delete,
    "ArticleDeleteAttachment()",
);

%AttachmentIndex = $Kernel::OM->Get('Ticket')->ArticleAttachmentIndex(
    ArticleID => $ArticleID,
    UserID    => 1,
);

$Self->IsDeeply(
    \%AttachmentIndex,
    {},
    "ArticleAttachmentIndex() after delete",
);

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
