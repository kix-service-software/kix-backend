# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::TicketNewMessageUpdate;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Log',
    'Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Parameter (qw(Data Event Config)) {
        if ( !$Param{$Parameter} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Parameter!"
            );
            return;
        }
    }

    # handle only events with given TicketID
    return 1 if ( !$Param{Data}->{TicketID} );

    # handle only events with given ArticleID
    return 1 if ( !$Param{Data}->{ArticleID} );

    # update ticket new message flag
    if ( $Param{Event} eq 'ArticleCreate' ) {

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Ticket');

        $TicketObject->TicketFlagDelete(
            TicketID => $Param{Data}->{TicketID},
            Key      => 'Seen',
            AllUsers => 1,
        );

        # Set the seen flag to 1 for the agent who created the article.
        #   This must also be done for articles with SenderType other than agent because
        #   it could be still coming from an agent (see bug#11565).
        $TicketObject->ArticleFlagSet(
            ArticleID => $Param{Data}->{ArticleID},
            Key       => 'Seen',
            Value     => 1,
            UserID    => $Param{UserID},
        );

        return 1;
    }
    elsif ( $Param{Event} eq 'ArticleFlagSet' && $Param{Data}->{Key} && $Param{Data}->{Key} eq 'Seen' ) {

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Ticket');

        my @ArticleList;
        my @SenderTypes = (qw(external agent system));

        # ignore system sender
        if ( $Kernel::OM->Get('Config')->Get('Ticket::NewArticleIgnoreSystemSender') ) {
            @SenderTypes = (qw(external agent));
        }

        for my $SenderType (@SenderTypes) {
            push @ArticleList, $TicketObject->ArticleIndex(
                TicketID   => $Param{Data}->{TicketID},
                SenderType => $SenderType,
            );
        }

        # check if ticket needs to be marked as seen
        my $ArticleAllSeen = 1;
        ARTICLE:
        for my $ArticleID (@ArticleList) {
            my %ArticleFlag = $TicketObject->ArticleFlagGet(
                TicketID  => $Param{Data}->{TicketID},
                ArticleID => $ArticleID,
                UserID    => $Param{Data}->{UserID},
            );

            # last ARTICLE if article was not shown
            if ( !$ArticleFlag{Seen} ) {
                $ArticleAllSeen = 0;
                last ARTICLE;
            }
        }

        # mark ticket as seen if all articles have been seen else mark ticket unseen
        if ($ArticleAllSeen) {
            $TicketObject->TicketFlagSet(
                TicketID => $Param{Data}->{TicketID},
                Key      => 'Seen',
                Value    => 1,
                UserID   => $Param{Data}->{UserID},
            );
        } else {
            $TicketObject->TicketFlagDelete(
                TicketID => $Param{Data}->{TicketID},
                Key      => 'Seen',
                UserID   => $Param{Data}->{UserID},
            );
        }
    }

    return;
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
