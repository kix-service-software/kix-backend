# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
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
my $MainObject   = $Kernel::OM->Get('Main');
my $TicketObject = $Kernel::OM->Get('Ticket');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

$Helper->UseTmpArticleDir();

my @Tests = (
    {
        Name            => 'Disposition1',
        ExpectedResults => {
            'ceeibejd.png' => {
                Filename           => 'ceeibejd.png',
                ContentType        => 'image/png; name="ceeibejd.png"',
                ContentID          => '<part1.02040705.00020608@kixdesk.com>',
                ContentAlternative => '1',
                Disposition        => 'inline',
            },
            'ui-toolbar.png' => {
                Filename           => 'ui-toolbar.png',
                ContentType        => 'image/png; name="ui-toolbar.png"',
                ContentID          => '',
                ContentAlternative => '',
                Disposition        => 'attachment',
            },
            'testing.pdf' => {
                Filename           => 'testing.pdf',
                ContentType        => 'application/pdf; name="testing.pdf"',
                ContentID          => '',
                ContentAlternative => '',
                Disposition        => 'attachment',
            },
        },
    },
    {
        Name            => 'Disposition2',
        ExpectedResults => {
            'ceeibejd.png' => {
                Filename           => 'ceeibejd.png',
                ContentType        => 'image/png; name="ceeibejd.png"',
                ContentID          => '<part1.02040705.00020608@kixdesk.com>',
                ContentAlternative => '1',
                Disposition        => 'inline',
            },
            'ui-toolbar.png' => {
                Filename           => 'ui-toolbar.png',
                ContentType        => 'image/png; name="ui-toolbar.png"',
                ContentID          => '',
                ContentAlternative => '',
                Disposition        => 'inline',
            },
            'testing.pdf' => {
                Filename           => 'testing.pdf',
                ContentType        => 'application/pdf; name="testing.pdf"',
                ContentID          => '',
                ContentAlternative => '',
                Disposition        => 'attachment',
            },
        },
    },
    {
        Name            => 'Disposition3',
        ExpectedResults => {
            'ceeibejd.png' => {
                Filename           => 'ceeibejd.png',
                ContentType        => 'image/png; name="ceeibejd.png"',
                ContentID          => '<part1.02040705.00020608@kixdesk.com>',
                ContentAlternative => '1',
                Disposition        => 'inline',
            },
            'ui-toolbar.png' => {
                Filename           => 'ui-toolbar.png',
                ContentType        => 'image/png; name="ui-toolbar.png"',
                ContentID          => '',
                ContentAlternative => '',
                Disposition        => 'inline',
            },
            'testing.pdf' => {
                Filename           => 'testing.pdf',
                ContentType        => 'application/pdf; name="testing.pdf"',
                ContentID          => '<part1.02040705.0001234@kixdesk.com>',
                ContentAlternative => '',
                Disposition        => 'attachment',
            },
        },
    },
    {
        Name            => 'Disposition4',
        ExpectedResults => {
            'ceeibejd.png' => {
                Filename           => 'ceeibejd.png',
                ContentType        => 'image/png; name="ceeibejd.png"',
                ContentID          => '<part1.02040705.00020608@kixdesk.com>',
                ContentAlternative => '1',
                Disposition        => 'attachment',
            },
            'ui-toolbar.png' => {
                Filename           => 'ui-toolbar.png',
                ContentType        => 'image/png; name="ui-toolbar.png"',
                ContentID          => '',
                ContentAlternative => '',
                Disposition        => 'attachment',
            },
            'testing.pdf' => {
                Filename           => 'testing.pdf',
                ContentType        => 'application/pdf; name="testing.pdf"',
                ContentID          => '',
                ContentAlternative => '',
                Disposition        => 'attachment',
            },
        },
    },
);

# begin transaction on database
$Helper->BeginWork();

for my $Test (@Tests) {
    my $Location = $ConfigObject->Get('Home')
        . '/scripts/test/system/sample/PostMaster/' . $Test->{Name} . '.box';

    my $ContentRef = $MainObject->FileRead(
        Location => $Location,
        Mode     => 'binmode',
        Result   => 'ARRAY',
    );

    my @Return;
    my $TicketID;
    {
        my $PostMasterObject = Kernel::System::PostMaster->new(
            Email => $ContentRef,
        );

        @Return = $PostMasterObject->Run();
        @Return = @{ $Return[0] || [] };

        $TicketID = $Return[1];
    }

    $Self->Is(
        $Return[0] || 0,
        1,
        "$Test->{Name} | Postmaster NewTicket",
    );

    $Self->True(
        $TicketID,
        "$Test->{Name} | Ticket created $TicketID",
    );

    my @ArticleIDs = $TicketObject->ArticleIndex( TicketID => $TicketID );
    $Self->True(
        $ArticleIDs[0],
        "$Test->{Name} | Article created",
    );

    my %AttachmentIndex = $TicketObject->ArticleAttachmentIndex(
        ArticleID => $ArticleIDs[0],
        UserID    => 1,
    );

    my %AttachmentsLookup = map { $AttachmentIndex{$_}->{Filename} => $_ } sort keys %AttachmentIndex;

    for my $AttachmentFilename ( sort keys %{ $Test->{ExpectedResults} } ) {

        my $AttachmentID = $AttachmentsLookup{$AttachmentFilename};

        # add attachment id to expected results
        $Test->{ExpectedResults}->{$AttachmentFilename}->{ID} = $AttachmentID;

        # delete zise attributes for easy compare
        delete $AttachmentIndex{$AttachmentID}->{Filesize};
        delete $AttachmentIndex{$AttachmentID}->{FilesizeRaw};

        $Self->IsDeeply(
            $AttachmentIndex{$AttachmentID},
            $Test->{ExpectedResults}->{$AttachmentFilename},
            "$Test->{Name} | Attachment",
        );
    }

    # delete ticket
    my $Success = $TicketObject->TicketDelete(
        TicketID => $TicketID,
        UserID   => 1,
    );
    $Self->True(
        $Success,
        "$Test->{Name} | Ticket deleted",
    );

    # new/clear ticket object
    $Kernel::OM->ObjectsDiscard(
        Objects => ['Ticket'],
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
