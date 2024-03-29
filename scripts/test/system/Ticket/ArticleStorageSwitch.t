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

my $Helper = $Kernel::OM->Get('UnitTest::Helper');

use Kernel::System::PostMaster;

# create tickets/article/attachments in backend for article storage switch tests
for my $SourceBackend (qw(ArticleStorageDB ArticleStorageFS)) {

    # Make sure that all objects get recreated for each loop.
    $Kernel::OM->ObjectsDiscard();

    # begin transaction on database
    $Helper->BeginWork();

    $Helper->UseTmpArticleDir();

    $Kernel::OM->Get('Config')->Set(
        Key   => 'Ticket::StorageModule',
        Value => 'Kernel::System::Ticket::' . $SourceBackend,
    );

    $Self->True(
        $Kernel::OM->Get('Ticket')->isa( 'Kernel::System::Ticket::' . $SourceBackend ),
        "TicketObject loaded the correct backend",
    );

    my @TicketIDs;
    my %ArticleIDs;
    my $NamePrefix = "ArticleStorageSwitch ($SourceBackend)";
    for my $File (qw(1 2 3 4 5 6 7 8 9 10 11 20)) {

        my $NamePrefix = "$NamePrefix #$File ";

        # new ticket check
        my $Location = $Kernel::OM->Get('Config')->Get('Home')
            . "/scripts/test/system/sample/PostMaster/PostMaster-Test$File.box";
        my $ContentRef = $Kernel::OM->Get('Main')->FileRead(
            Location => $Location,
            Mode     => 'binmode',
            Result   => 'ARRAY',
        );
        my @Content = @{$ContentRef};

        my $PostMasterObject = Kernel::System::PostMaster->new(
            Email => \@Content,
        );

        my @Return = $PostMasterObject->Run();
        @Return = @{ $Return[0] || [] };

        $Self->Is(
            $Return[0] || 0,
            1,
            $NamePrefix . ' Run() - NewTicket',
        );
        $Self->True(
            $Return[1] || 0,
            $NamePrefix . " Run() - NewTicket/TicketID:$Return[1]",
        );

        # remember created tickets
        push @TicketIDs, $Return[1];

        # remember created article and attachments
        my @ArticleBox = $Kernel::OM->Get('Ticket')->ArticleContentIndex(
            TicketID => $Return[1],
            UserID   => 1,
        );
        for my $Article (@ArticleBox) {
            $ArticleIDs{ $Article->{ArticleID} } = { %{ $Article->{Atms} } };
        }
    }

    my @Map = (
        [ 'ArticleStorageDB', 'ArticleStorageFS' ],
        [ 'ArticleStorageFS', 'ArticleStorageDB' ],
        [ 'ArticleStorageDB', 'ArticleStorageFS' ],
        [ 'ArticleStorageFS', 'ArticleStorageDB' ],
        [ 'ArticleStorageFS', 'ArticleStorageDB' ],
    );
    for my $Case (@Map) {
        my $SourceBackend      = $Case->[0];
        my $DestinationBackend = $Case->[1];
        my $NamePrefix         = "ArticleStorageSwitch ($SourceBackend->$DestinationBackend)";

        # verify
        for my $ArticleID ( sort keys %ArticleIDs ) {
            my %Index = $Kernel::OM->Get('Ticket')->ArticleAttachmentIndex(
                ArticleID => $ArticleID,
                UserID    => 1,
            );

            # check file attributes
            for my $AttachmentID ( sort keys %{ $ArticleIDs{$ArticleID} } ) {

                ATTACHMENTINDEXID:
                for my $ID ( sort keys %Index ) {
                    if (
                        $ArticleIDs{$ArticleID}->{$AttachmentID}->{Filename} ne
                        $Index{$ID}->{Filename}
                        )
                    {
                        next ATTACHMENTINDEXID;
                    }
                    for my $Attribute ( sort keys %{ $ArticleIDs{$ArticleID}->{$AttachmentID} } ) {
                        $Self->Is(
                            $Index{$ID}->{$Attribute},
                            $ArticleIDs{$ArticleID}->{$AttachmentID}->{$Attribute},
                            "$NamePrefix - Verify before - $Attribute (ArticleID:$ArticleID)",
                        );
                    }
                }
            }
        }

        # switch to backend b
        for my $TicketID (@TicketIDs) {
            my $Success = $Kernel::OM->Get('Ticket')->TicketArticleStorageSwitch(
                TicketID    => $TicketID,
                Source      => $SourceBackend,
                Destination => $DestinationBackend,
                UserID      => 1,
            );
            $Self->True(
                $Success,
                "$NamePrefix - backend move TicketID:$TicketID",
            );
        }

        # verify
        for my $ArticleID ( sort keys %ArticleIDs ) {
            my %Index = $Kernel::OM->Get('Ticket')->ArticleAttachmentIndex(
                ArticleID => $ArticleID,
                UserID    => 1,
            );

            # check file attributes
            for my $AttachmentID ( sort keys %{ $ArticleIDs{$ArticleID} } ) {

                ATTACHMENTINDEXID:
                for my $ID ( sort keys %Index ) {
                    if (
                        $ArticleIDs{$ArticleID}->{$AttachmentID}->{Filename} ne
                        $Index{$ID}->{Filename}
                        )
                    {
                        next ATTACHMENTINDEXID;
                    }
                    for my $Attribute ( sort keys %{ $ArticleIDs{$ArticleID}->{$AttachmentID} } ) {
                        $Self->Is(
                            $Index{$ID}->{$Attribute},
                            $ArticleIDs{$ArticleID}->{$AttachmentID}->{$Attribute},
                            "$NamePrefix - Verify after - $Attribute (ArticleID:$ArticleID)",
                        );
                    }
                }
            }
        }
    }

    # rollback transaction on database
    $Helper->Rollback();
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
