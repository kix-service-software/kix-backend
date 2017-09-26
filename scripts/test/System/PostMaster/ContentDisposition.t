# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::PostMaster;

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');
my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase  => 1,
        UseTmpArticleDir => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my @Tests = (
    {
        Name            => 'Disposition1',
        ExpectedResults => {
            'ceeibejd.png' => {
                Filename           => 'ceeibejd.png',
                ContentType        => 'image/png; name="ceeibejd.png"',
                ContentID          => '<part1.02040705.00020608@otrs.com>',
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
                ContentID          => '<part1.02040705.00020608@otrs.com>',
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
                ContentID          => '<part1.02040705.00020608@otrs.com>',
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
                ContentID          => '<part1.02040705.0001234@otrs.com>',
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
                ContentID          => '<part1.02040705.00020608@otrs.com>',
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

my @AddedTicketIDs;

for my $Test (@Tests) {

    for my $Backend (qw(DB FS)) {

        $ConfigObject->Set(
            Key   => 'Ticket::StorageModule',
            Value => 'Kernel::System::Ticket::ArticleStorage' . $Backend,
        );

        my $Location = $ConfigObject->Get('Home')
            . '/scripts/test/sample/PostMaster/' . $Test->{Name} . '.box';

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

            $TicketID = $Return[1];
        }

        $Self->True(
            $TicketID,
            "$Test->{Name} | $Backend - Ticket created $TicketID",
        );

        # remember added tickets
        push @AddedTicketIDs, $TicketID;

        my @ArticleIDs = $TicketObject->ArticleIndex( TicketID => $TicketID );
        $Self->True(
            $ArticleIDs[0],
            "$Test->{Name} | $Backend - Article created",
        );

        my %AttachmentIndex = $TicketObject->ArticleAttachmentIndex(
            ArticleID => $ArticleIDs[0],
            UserID    => 1,
        );

        my %AttachmentsLookup = map { $AttachmentIndex{$_}->{Filename} => $_ } sort keys %AttachmentIndex;

        for my $AttachmentFilename ( sort keys %{ $Test->{ExpectedResults} } ) {

            my $AttachmentID = $AttachmentsLookup{$AttachmentFilename};

            # delete zise attributes for easy compare
            delete $AttachmentIndex{$AttachmentID}->{Filesize};
            delete $AttachmentIndex{$AttachmentID}->{FilesizeRaw};

            $Self->IsDeeply(
                $AttachmentIndex{$AttachmentID},
                $Test->{ExpectedResults}->{$AttachmentFilename},
                "$Test->{Name} | $Backend - Attachment",
            );
        }
    }
}

# cleanup is done by RestoreDatabase.

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut