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

$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::ArchiveSystem',
    Value => 1,
);

my @Tests = (
    {
        Name   => 'default archive system',
        Config => {
            RemoveSeenFlags      => 1,
            RemoveTicketWatchers => 1,
        },
    },
    {
        Name   => 'archive system without ticket watcher removal',
        Config => {
            RemoveSeenFlags      => 1,
            RemoveTicketWatchers => 0,
        },
    },
    {
        Name   => 'archive system without seen flags removal',
        Config => {
            RemoveSeenFlags      => 0,
            RemoveTicketWatchers => 1,
        },
    },
);

for my $Test (@Tests) {
    $Kernel::OM->Get('Config')->Set(
        Key   => 'Ticket::ArchiveSystem::RemoveSeenFlags',
        Value => $Test->{Config}->{RemoveSeenFlags},
    );

    $Kernel::OM->Get('Config')->Set(
        Key   => 'Ticket::ArchiveSystem::RemoveTicketWatchers',
        Value => $Test->{Config}->{RemoveTicketWatchers},
    );

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

    my $ArticleID2 = $Kernel::OM->Get('Ticket')->ArticleCreate(
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
        $ArticleID2,
        'ArticleCreate()',
    );

    # Seen flags are set for UserID 1 already
    my %Flag = $Kernel::OM->Get('Ticket')->TicketFlagGet(
        TicketID => $TicketID,
        UserID   => 1,
    );

    $Self->Is(
        $Flag{'Seen'},
        1,
        "$Test->{Name} - TicketFlagGet() article 1",
    );

    %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagGet(
        TicketID  => $TicketID,
        ArticleID => $ArticleID,
        UserID    => 1,
    );

    $Self->Is(
        $Flag{'Seen'},
        1,
        "$Test->{Name} - ArticleFlagGet() article 1",
    );

    # subscribe user to ticket
    my $WatcherID = $Kernel::OM->Get('Watcher')->WatcherAdd(
        Object      => 'Ticket',
        ObjectID    => $TicketID,
        WatchUserID => 1,
        UserID      => 1,
    );

    $Self->True(
        $WatcherID,
        "$Test->{Name} - subscribe watcher",
    );

    my %Watcher = $Kernel::OM->Get('Watcher')->WatcherGet(
        ID => $WatcherID,
    );
    delete( $Watcher{WatchUserID} );

    my @Watchers = $Kernel::OM->Get('Watcher')->WatcherList(
        ObjectType  => 'Ticket',
        ObjectID    => $TicketID,
    );

    $Self->IsDeeply(
        \@Watchers,
        [\%Watcher],
        "$Test->{Name} - get watchers",
    );

    # Now set the archive flag
    my $Success = $Kernel::OM->Get('Ticket')->TicketArchiveFlagSet(
        TicketID    => $TicketID,
        ArchiveFlag => 'y',
        UserID      => 1,
    );

    $Self->True(
        $Success,
        "$Test->{Name} - TicketArchiveFlagSet()",
    );

    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet( TicketID => $TicketID );

    $Self->Is(
        $Ticket{ArchiveFlag},
        'y',
        "$Test->{Name} - TicketFlag value",
    );

    # now check the seen flags
    %Flag = $Kernel::OM->Get('Ticket')->TicketFlagGet(
        TicketID => $TicketID,
        UserID   => 1,
    );

    $Self->Is(
        $Flag{'Seen'},
        $Test->{Config}->{RemoveSeenFlags} ? undef : 1,
        "$Test->{Name} - TicketFlagGet() after archiving",
    );

    %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagGet(
        TicketID  => $TicketID,
        ArticleID => $ArticleID,
        UserID    => 1,
    );

    $Self->Is(
        $Flag{'Seen'},
        $Test->{Config}->{RemoveSeenFlags} ? undef : 1,
        "$Test->{Name} - ArticleFlagGet() article 1 after archiving",
    );


    @Watchers = $Kernel::OM->Get('Watcher')->WatcherList(
        ObjectType  => 'Ticket',
        ObjectID    => $TicketID,
    );

    $Self->Is(
        scalar( @Watchers ),
        $Test->{Config}->{RemoveTicketWatchers} ? 0 : 1,
        "$Test->{Name} - TicketWatchGet()",
    );

    # article flag tests
    my @Tests = (
        {
            Name   => 'seen flag',
            Key    => 'seen',
            Value  => 1,
            UserID => 1,
        },
        {
            Name   => 'not seen flag',
            Key    => 'not seen',
            Value  => 2,
            UserID => 1,
        },
    );

    # delete pre-existing article flags which are created on TicketCreate
    $Kernel::OM->Get('Ticket')->ArticleFlagDelete(
        ArticleID => $ArticleID,
        Key       => 'Seen',
        UserID    => 1,
    );
    $Kernel::OM->Get('Ticket')->ArticleFlagDelete(
        ArticleID => $ArticleID2,
        Key       => 'Seen',
        UserID    => 1,
    );

    for my $Test (@Tests) {

        # Set for article 1
        my %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagGet(
            TicketID  => $TicketID,
            ArticleID => $ArticleID,
            UserID    => 1,
        );
        $Self->False(
            $Flag{ $Test->{Key} },
            'ArticleFlagGet() article 1',
        );
        my $Set = $Kernel::OM->Get('Ticket')->ArticleFlagSet(
            ArticleID => $ArticleID,
            Key       => $Test->{Key},
            Value     => $Test->{Value},
            UserID    => 1,
        );
        $Self->True(
            $Set,
            'ArticleFlagSet() article 1',
        );

        # Set for article 2
        %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagGet(
            TicketID  => $TicketID,
            ArticleID => $ArticleID2,
            UserID    => 1,
        );
        $Self->False(
            $Flag{ $Test->{Key} },
            'ArticleFlagGet() article 2',
        );
        $Set = $Kernel::OM->Get('Ticket')->ArticleFlagSet(
            ArticleID => $ArticleID2,
            Key       => $Test->{Key},
            Value     => $Test->{Value},
            UserID    => 1,
        );
        $Self->True(
            $Set,
            'ArticleFlagSet() article 2',
        );
        %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagGet(
            TicketID  => $TicketID,
            ArticleID => $ArticleID2,
            UserID    => 1,
        );
        $Self->Is(
            $Flag{ $Test->{Key} },
            $Test->{Value},
            'ArticleFlagGet() article 2',
        );

        # Get all flags of ticket
        %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagsOfTicketGet(
            TicketID => $TicketID,
            UserID   => 1,
        );
        $Self->IsDeeply(
            \%Flag,
            {
                $ArticleID => {
                    $Test->{Key} => $Test->{Value},
                },
                $ArticleID2 => {
                    $Test->{Key} => $Test->{Value},
                },
            },
            'ArticleFlagsOfTicketGet() both articles',
        );

        # Delete for article 1
        my $Delete = $Kernel::OM->Get('Ticket')->ArticleFlagDelete(
            ArticleID => $ArticleID,
            Key       => $Test->{Key},
            UserID    => 1,
        );
        $Self->True(
            $Delete,
            'ArticleFlagDelete() article 1',
        );
        %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagGet(
            TicketID  => $TicketID,
            ArticleID => $ArticleID,
            UserID    => 1,
        );
        $Self->False(
            $Flag{ $Test->{Key} },
            'ArticleFlagGet() article 1',
        );

        %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagsOfTicketGet(
            TicketID => $TicketID,
            UserID   => 1,
        );
        $Self->IsDeeply(
            \%Flag,
            {
                $ArticleID2 => {
                    $Test->{Key} => $Test->{Value},
                },
            },
            'ArticleFlagsOfTicketGet() only one article',
        );

        # Delete for article 2
        $Delete = $Kernel::OM->Get('Ticket')->ArticleFlagDelete(
            ArticleID => $ArticleID2,
            Key       => $Test->{Key},
            UserID    => 1,
        );
        $Self->True(
            $Delete,
            'ArticleFlagDelete() article 2',
        );

        %Flag = $Kernel::OM->Get('Ticket')->ArticleFlagsOfTicketGet(
            TicketID => $TicketID,
            UserID   => 1,
        );
        $Self->IsDeeply(
            \%Flag,
            {},
            'ArticleFlagsOfTicketGet() empty articles',
        );
    }
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
