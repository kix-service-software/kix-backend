# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::ArticleCustomerVisibleByReferences;

use strict;
use warnings;

our @ObjectDependencies = (
    'Log',
    'Main',
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
    for (qw(Data Event Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    for (qw(TicketID)) {
        if ( !$Param{Data}->{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_ in Data!"
            );
            return;
        }
    }

    # check preconditions
    return 1 if ( $Param{Event} ne 'ArticleCreate' );
    return 1 if ( !$Param{Data}->{ArticleID} );

    # get article with filter for channel 'email' and invisible for customer
    my %Article = $Kernel::OM->Get('Ticket')->ArticleGet(
        ArticleID       => $Param{Data}->{ArticleID},
        Channel         => [ 'email' ],
        CustomerVisible => 0,
        DynamicFields   => 0,
        UserID          => 1,
    );
    return 1 if ( !%Article );

    # get possible references
    my @ReferencesAll;
    my $ReferencesString = $Article{References};
    if ( $ReferencesString ) {
        push( @ReferencesAll, ( $ReferencesString =~ /(<[^>]+>)/g ) );
    }

    # get in reply to id
    my $InReplyToString = $Article{InReplyTo};
    if ( $InReplyToString ) {
        chomp( $InReplyToString );
        $InReplyToString =~ s/.*?(<[^>]+>).*/$1/;
        push( @ReferencesAll, $InReplyToString );
    }

    # check references
    return 1 if ( !@ReferencesAll );

    # get unique references
    my @References = $Kernel::OM->Get('Main')->GetUnique(@ReferencesAll);

    # get reference article with filter for channel 'email', visible for customer and relevant message id
    my @ReferenceArticles = $Kernel::OM->Get('Ticket')->ArticleGet(
        TicketID        => $Param{Data}->{TicketID},
        Channel         => [ 'email' ],
        CustomerVisible => 1,
        MessageID       => \@References,
        DynamicFields   => 0,
        UserID          => 1,
    );

    # check if reference article exists
    if ( @ReferenceArticles ) {
        # set article visible for customer
        my $Success = $Kernel::OM->Get('Ticket')->ArticleUpdate(
            ArticleID       => $Param{Data}->{ArticleID},
            CustomerVisible => 1,
            UserID          => 1,
        );
        if ( !$Success ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Could not set article id '$Param{Data}->{ArticleID}' visible for customer"
            );
            return;
        }
    }

    return 1;
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
