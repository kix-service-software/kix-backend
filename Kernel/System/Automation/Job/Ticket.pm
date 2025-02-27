# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::Job::Ticket;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::Job::Common);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
);

=head1 NAME

Kernel::System::Automation::Job::Ticket - job type for automation lib

=head1 SYNOPSIS

Handles ticket based jobs.

=head1 PUBLIC INTERFACE

=over 4

=cut


sub _Run {
    my ( $Self, %Param ) = @_;

    my $Filters = $Param{Filter};

    # extend the filter with the ArticleID or TicketID
    if ( IsHashRefWithData($Param{Data}) && $Param{Data}->{ArticleID} ) {

        # add ArticleID to filter
        $Filters = $Self->_ExtendFilter(
            Filters => $Filters,
            Extend  => {
                Field    => 'ArticleID',
                Operator => 'EQ',
                Value    => $Param{Data}->{ArticleID}
            }
        );
    }
    elsif ( IsHashRefWithData($Param{Data}) && $Param{Data}->{TicketID} ) {

        # add TicketID to filter
        $Filters = $Self->_ExtendFilter(
            Filters => $Filters,
            Extend  => {
                Field    => 'TicketID',
                Operator => 'EQ',
                Value    => $Param{Data}->{TicketID}
            }
        )
    }

    my @TicketIDs;

    # do the search
    if (IsArrayRefWithData($Filters)) {
        for my $Search ( @{$Filters} ) {
            my @TicketIDsPart = $Kernel::OM->Get('ObjectSearch')->Search(
                ObjectType => 'Ticket',
                Result     => 'ARRAY',
                Search     => $Search,
                Sort       => $Param{Sort},
                UserID     => 1,
                UserType   => 'Agent'
            );
            push(@TicketIDs, @TicketIDsPart);
        }
        @TicketIDs = $Kernel::OM->Get('Main')->GetUnique(@TicketIDs);

        # do additional "search" to sort all results combined
        if (IsArrayRefWithData($Param{Sort}) && scalar(@{$Filters}) > 1) {
            @TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
                ObjectType => 'Ticket',
                Result     => 'ARRAY',
                Search     => {
                    AND => [
                        {
                            Field    => 'TicketID',
                            Operator => 'IN',
                            Value    => \@TicketIDs
                        }
                    ]
                },
                Sort       => $Param{Sort},
                UserID     => 1,
                UserType   => 'Agent'
            );
        }
    } else {
        @TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType => 'Ticket',
            Result     => 'ARRAY',
            Sort       => $Param{Sort},
            UserID     => 1,
            UserType   => 'Agent'
        );
    }

    return @TicketIDs;
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
