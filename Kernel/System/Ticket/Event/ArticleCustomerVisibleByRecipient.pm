# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::ArticleCustomerVisibleByRecipient;

use strict;
use warnings;

our @ObjectDependencies = (
    'Contact',
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

    # check possible to, cc and bcc emailaddresses
    my $Recipient = '';
    RECIPIENT:
    for my $Key (qw(To Cc Bcc)) {

        next RECIPIENT if !$Article{$Key};

        if ($Recipient) {
            $Recipient .= ', ';
        }

        $Recipient .= $Article{$Key};
    }
    return 1 if ( !$Recipient );

    # create email parser object
    my $EmailParser = Kernel::System::EmailParser->new(
        Mode => 'Standalone',
    );

    # get addresses
    my @EmailAddresses = $EmailParser->SplitAddressLine( Line => $Recipient );

    # prepare addresses for search
    my @EmailIn = ();
    EMAIL:
    for my $Email ( @EmailAddresses ) {
        next EMAIL if ( !$Email );

        my $Address = $EmailParser->GetEmailAddress( Email => $Email );
        next EMAIL if ( !$Address );

        # remove quotation marks
        $Address =~ s/("|')//g;

        # add address for search
        push( @EmailIn, $Address );
    }
    return 1 if ( !@EmailIn );

    # get ticket data
    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID      => $Param{Data}->{TicketID},
        DynamicFields => 0,
        UserID        => 1,
    );

    # search for relevant contacts
    my %ContactList = $Kernel::OM->Get('ObjectSearch')->Search(
        Search => {
            AND => [
                {
                    Field    => 'Emails',
                    Operator => 'IN',
                    Value    => \@EmailIn
                }
            ]
        },
        ObjectType => 'Contact',
        Result     => 'HASH',
        UserID     => 1,
        UserType   => 'Agent'
    );

    # check if ticket customer is a relevant contact
    if (
        %ContactList
        && $ContactList{ $Ticket{ContactID} }
    ) {
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
