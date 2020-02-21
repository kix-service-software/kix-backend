# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::PostMaster::Filter::FollowUpChannelCheck;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Contact',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get parser object
    $Self->{ParserObject} = $Param{ParserObject} || die "Got no ParserObject!";

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return 1 if !$Param{TicketID};

    # check needed stuff
    for (qw(JobConfig GetParam)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # Only run if we have a follow-up article with SenderType 'external'.
    #   It could be that follow-ups have a different SenderType like 'system' for
    #   automatic notifications. In these cases there is no need to hide them.
    #   See also bug#10182 for details.
    if (
        !$Param{GetParam}->{'X-KIX-FollowUp-SenderType'}
        || $Param{GetParam}->{'X-KIX-FollowUp-SenderType'} ne 'external'
        )
    {
        return 1;
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # Get all articles.
    my @ArticleIndex = $TicketObject->ArticleGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );
    return if !@ArticleIndex;

    # get ticket for Article
    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{TicketID}
    );

    # Check if it is a known customer, otherwise use email address from ContactID field of the ticket.
    my %CustomerData = $Kernel::OM->Get('Kernel::System::Contact')->ContactGet(
        ID => $Ticket{ContactID},
    );
    my $CustomerEmailAddress = $CustomerData{Email} || $Ticket{ContactID};

    # Email sender address
    my $SenderAddress = $Param{GetParam}->{'X-Sender'};

    # Email Reply-To address for forwarded emails
    my $ReplyToAddress;
    if ( $Param{GetParam}->{ReplyTo} ) {
        $ReplyToAddress = $Self->{ParserObject}->GetEmailAddress(
            Email => $Param{GetParam}->{ReplyTo},
        );
    }

    # check if current sender is customer (do nothing)
    if ( $CustomerEmailAddress && $SenderAddress ) {
        return 1 if lc $CustomerEmailAddress eq lc $SenderAddress;
    }

    my @References = $Self->{ParserObject}->GetReferences();

    # check if current sender got an internal forward
    my $InternalForward;
    ARTICLE:
    for my $Article ( reverse @ArticleIndex ) {

        # just check agent sent article
        next ARTICLE if $Article->{SenderType} ne 'agent';

        # just check email internal
        next ARTICLE if $Article->{Channel} ne 'email' || !$Article->{CustomerVisible};

        # check recipients
        next ARTICLE if !$Article->{To};

        # check based on recipient addresses of the article
        my @ToEmailAddresses = $Self->{ParserObject}->SplitAddressLine(
            Line => $Article->{To},
        );
        my @CcEmailAddresses = $Self->{ParserObject}->SplitAddressLine(
            Line => $Article->{Cc},
        );
        my @EmailAdresses = ( @ToEmailAddresses, @CcEmailAddresses );

        EMAIL:
        for my $Email (@EmailAdresses) {
            my $Recipient = $Self->{ParserObject}->GetEmailAddress(
                Email => $Email,
            );
            if ( lc $Recipient eq lc $SenderAddress ) {
                $InternalForward = 1;
                last ARTICLE;
            }
            if ( $ReplyToAddress && lc $Recipient eq lc $ReplyToAddress ) {
                $InternalForward = 1;
                last ARTICLE;
            }
        }

        # check based on Message-ID of the article
        for my $Reference (@References) {
            if ( $Article->{MessageID} && $Article->{MessageID} eq $Reference ) {
                $InternalForward = 1;
                last ARTICLE;
            }
        }
    }

    return 1 if !$InternalForward;

    # get latest customer article (current arrival)
    $Param{GetParam}->{'X-KIX-FollowUp-Channel'} = $Param{JobConfig}->{Channel} || 'email';
    $Param{GetParam}->{'X-KIX-FollowUp-CustomerVisible'} = $Param{JobConfig}->{VisibleForCustomer} || 'email';

    # set article type to email-internal
    $Param{GetParam}->{'X-KIX-FollowUp-SenderType'} = $Param{JobConfig}->{SenderType} || 'external';

    return 1;
}

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
