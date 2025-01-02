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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

$Helper->UseTmpArticleDir();

my $UserID = 1;

my @Tests = (

    # normal attachment tests
    {
        Name   => 'Normal Attachment w/Disposition w/ContentID',
        Config => {
            Filename    => 'testing.pdf',
            ContentType => 'application/pdf',
            Disposition => 'attachment',
            ContentID   => 'testing123@example.com',
            Content     => '123',
            UserID      => $UserID,
        },
        ExpectedResults => {
            Filename           => 'testing.pdf',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '<testing123@example.com>',
            ContentType        => 'application/pdf',
            Disposition        => 'attachment',
            ContentAlternative => '',
        },
    },
    {
        Name   => 'Normal Attachment w/Disposition wo/ContentID',
        Config => {
            Filename    => 'testing.pdf',
            ContentType => 'application/pdf',
            Disposition => 'attachment',
            ContentID   => undef,
            Content     => '123',
            UserID      => $UserID,
        },
        ExpectedResults => {
            Filename           => 'testing.pdf',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '',
            ContentType        => 'application/pdf',
            Disposition        => 'attachment',
            ContentAlternative => '',
        },
    },
    {
        Name   => 'Normal Attachment wo/Disposition w/ContentID',
        Config => {
            Filename    => 'testing.pdf',
            ContentType => 'application/pdf',
            Disposition => undef,
            ContentID   => 'testing123@example.com',
            Content     => '123',
            UserID      => $UserID,
        },
        ExpectedResults => {
            Filename           => 'testing.pdf',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '<testing123@example.com>',
            ContentType        => 'application/pdf',
            Disposition        => 'attachment',
            ContentAlternative => '',
        },
    },
    {
        Name   => 'Normal Attachment wo/Disposition wo/ContentID',
        Config => {
            Filename    => 'testing.pdf',
            ContentType => 'application/pdf',
            Disposition => undef,
            ContentID   => undef,
            Content     => '123',
            UserID      => $UserID,
        },
        ExpectedResults => {
            Filename           => 'testing.pdf',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '',
            ContentType        => 'application/pdf',
            Disposition        => 'attachment',
            ContentAlternative => '',
        },
    },
    {
        Name   => 'Normal Attachment inline w/Disposition wo/ContentID',
        Config => {
            Filename    => 'testing.pdf',
            ContentType => 'application/pdf',
            Disposition => 'inline',
            ContentID   => undef,
            Content     => '123',
            UserID      => $UserID,
        },
        ExpectedResults => {
            Filename           => 'testing.pdf',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '',
            ContentType        => 'application/pdf',
            Disposition        => 'inline',
            ContentAlternative => '',
        },
    },
    {
        Name   => 'Normal Attachment inline w/Disposition w/ContentID',
        Config => {
            Filename    => 'testing.pdf',
            ContentType => 'application/pdf',
            Disposition => 'inline',
            ContentID   => 'testing123@example.com',
            Content     => '123',
            UserID      => $UserID,
        },
        ExpectedResults => {
            Filename           => 'testing.pdf',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '<testing123@example.com>',
            ContentType        => 'application/pdf',
            Disposition        => 'inline',
            ContentAlternative => '',
        },
    },

    # image tests
    {
        Name   => 'Image Attachment w/Disposition w/ContentID',
        Config => {
            Filename    => 'testing.png',
            ContentType => 'image/png',
            Disposition => 'attachment',
            ContentID   => 'testing123@example.com',
            Content     => '123',
            UserID      => $UserID,
        },
        ExpectedResults => {
            Filename           => 'testing.png',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '<testing123@example.com>',
            ContentType        => 'image/png',
            Disposition        => 'attachment',
            ContentAlternative => '',
        },
    },
    {
        Name   => 'Image Attachment w/Disposition wo/ContentID',
        Config => {
            Filename    => 'testing.png',
            ContentType => 'image/png',
            Disposition => 'attachment',
            ContentID   => undef,
            Content     => '123',
            UserID      => $UserID,
        },
        ExpectedResults => {
            Filename           => 'testing.png',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '',
            ContentType        => 'image/png',
            Disposition        => 'attachment',
            ContentAlternative => '',
        },
    },
    {
        Name   => 'Image Attachment wo/Disposition w/ContentID',
        Config => {
            Filename    => 'testing.png',
            ContentType => 'image/png',
            Disposition => undef,
            ContentID   => 'testing123@example.com',
            Content     => '123',
            UserID      => $UserID,
        },

        # images with content id and no disposition should be inline
        ExpectedResults => {
            Filename           => 'testing.png',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '<testing123@example.com>',
            ContentType        => 'image/png',
            Disposition        => 'inline',
            ContentAlternative => '',
        },
    },
    {
        Name   => 'Image Attachment wo/Disposition wo/ContentID',
        Config => {
            Filename    => 'testing.png',
            ContentType => 'image/png',
            Disposition => undef,
            ContentID   => undef,
            Content     => '123',
            UserID      => $UserID,
        },
        ExpectedResults => {
            Filename           => 'testing.png',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '',
            ContentType        => 'image/png',
            Disposition        => 'attachment',
            ContentAlternative => '',
        },
    },
    {
        Name   => 'Image Attachment inline w/Disposition wo/ContentID',
        Config => {
            Filename    => 'testing.png',
            ContentType => 'image/png',
            Disposition => 'inline',
            ContentID   => undef,
            Content     => '123',
            UserID      => $UserID,
        },
        ExpectedResults => {
            Filename           => 'testing.png',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '',
            ContentType        => 'image/png',
            Disposition        => 'inline',
            ContentAlternative => '',
        },
    },
    {
        Name   => 'Image Attachment inline w/Disposition w/ContentID',
        Config => {
            Filename    => 'testing.png',
            ContentType => 'image/png',
            Disposition => 'inline',
            ContentID   => 'testing123@example.com',
            Content     => '123',
            UserID      => $UserID,
        },
        ExpectedResults => {
            Filename           => 'testing.png',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '<testing123@example.com>',
            ContentType        => 'image/png',
            Disposition        => 'inline',
            ContentAlternative => '',
        },
    },

    # special attachments tests
    {
        Name   => 'Special Attachment w/Disposition w/ContentID',
        Config => {
            Filename    => 'file-2',
            ContentType => 'text/html',
            Disposition => 'attachment',
            ContentID   => 'testing123@example.com',
            Content     => '123',
            UserID      => $UserID,
        },
        ExpectedResults => {
            Filename           => 'file-2',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '<testing123@example.com>',
            ContentType        => 'text/html',
            Disposition        => 'attachment',
            ContentAlternative => '',
        },
    },
    {
        Name   => 'Special Attachment w/Disposition wo/ContentID',
        Config => {
            Filename    => 'file-2',
            ContentType => 'text/html',
            Disposition => 'attachment',
            ContentID   => undef,
            Content     => '123',
            UserID      => $UserID,
        },
        ExpectedResults => {
            Filename           => 'file-2',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '',
            ContentType        => 'text/html',
            Disposition        => 'attachment',
            ContentAlternative => '',
        },
    },
    {
        Name   => 'Special Attachment wo/Disposition w/ContentID',
        Config => {
            Filename    => 'file-2',
            ContentType => 'text/html',
            Disposition => undef,
            ContentID   => 'testing123@example.com',
            Content     => '123',
            UserID      => $UserID,
        },

        # special attachments with no disposition should be inline
        ExpectedResults => {
            Filename           => 'file-2',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '<testing123@example.com>',
            ContentType        => 'text/html',
            Disposition        => 'inline',
            ContentAlternative => '',
        },
    },
    {
        Name   => 'Special Attachment wo/Disposition wo/ContentID',
        Config => {
            Filename    => 'file-2',
            ContentType => 'text/html',
            Disposition => undef,
            ContentID   => undef,
            Content     => '123',
            UserID      => $UserID,
        },
        ExpectedResults => {
            Filename           => 'file-2',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '',
            ContentType        => 'text/html',
            Disposition        => 'inline',
            ContentAlternative => '',
        },
    },
    {
        Name   => 'Special Attachment inline w/Disposition wo/ContentID',
        Config => {
            Filename    => 'file-2',
            ContentType => 'text/html',
            Disposition => 'inline',
            ContentID   => undef,
            Content     => '123',
            UserID      => $UserID,
        },
        ExpectedResults => {
            Filename           => 'file-2',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '',
            ContentType        => 'text/html',
            Disposition        => 'inline',
            ContentAlternative => '',
        },
    },
    {
        Name   => 'Special Attachment inline w/Disposition w/ContentID',
        Config => {
            Filename    => 'file-2',
            ContentType => 'text/html',
            Disposition => 'inline',
            ContentID   => 'testing123@example.com',
            Content     => '123',
            UserID      => $UserID,
        },
        ExpectedResults => {
            Filename           => 'file-2',
            Filesize           => '3 Bytes',
            FilesizeRaw        => 3,
            ContentID          => '<testing123@example.com>',
            ContentType        => 'text/html',
            Disposition        => 'inline',
            ContentAlternative => '',
        },
    },
);

my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'Some Ticket_Title',
    Queue          => 'Junk',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'closed',
    OrganisationID => 'unittest',
    ContactID      => 'customer@example.com',
    OwnerID        => 1,
    UserID         => 1,
);
$Self->True(
    $TicketID,
    "TicketCreate() - TicketID:'$TicketID'",
);

for my $Test (@Tests) {

    # create an article
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
        NoAgentNotify  => 1,                                         # if you don't want to send agent notifications
    );
    $Self->True(
        $ArticleID,
        "ArticleCreate() - ArticleID:'$ArticleID'",
    );

    # create attachment
    my $Success = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
        %{ $Test->{Config} },
        ArticleID => $ArticleID,
    );
    $Self->True(
        $Success,
        "$Test->{Name} | ArticleWriteAttachment() - created $Test->{Config}->{Filename}",
    );

    # get the list of all attachments (should be only 1)
    my %AttachmentIndex = $Kernel::OM->Get('Ticket')->ArticleAttachmentIndex(
        ArticleID => $ArticleID,
        UserID    => $UserID,
    );
    my @AttachmentIDs = grep { $AttachmentIndex{$_}->{Filename} eq $Test->{Config}->{Filename} }
        keys %AttachmentIndex;
    my $AttachmentID  = $AttachmentIDs[0];
    $Self->IsDeeply(
        $AttachmentIndex{$AttachmentID},
        {
            %{ $Test->{ExpectedResults} },
            ID => $AttachmentID
        },
        "$Test->{Name} | ArticleAttachmentIndex",
    );

    # get the attachment individually
    my %Attachment = $Kernel::OM->Get('Ticket')->ArticleAttachment(
        ArticleID    => $ArticleID,
        AttachmentID => $AttachmentID,
        UserID       => $UserID,
    );

    # add the missing content to the test expected resutls
    my %ExpectedAttachment = (
        %{ $Test->{ExpectedResults} },
        Content => $Test->{Config}->{Content},
        ID      => $AttachmentID
    );
    $Self->IsDeeply(
        \%Attachment,
        \%ExpectedAttachment,
        "$Test->{Name} | ArticleAttachment",
    );

}

# run TicketDelete() to cleanup the FS backend too
my $Success = $Kernel::OM->Get('Ticket')->TicketDelete(
    TicketID => $TicketID,
    UserID   => 1,
);
$Self->True(
    $Success,
    "TicketDelete() - TicketID:'$TicketID'",
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
