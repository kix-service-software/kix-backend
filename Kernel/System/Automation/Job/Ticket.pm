# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
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

=item Run()

Run this job module. Returns the list of TicketIDs to run this job on.

Example:
    my @TicketIDs = $Object->Run(
        Filter => {}         # optional, filter for objects
        Data   => {},        # optional, contains the relevant data given by an event or otherwise
        UserID => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    my $Filter =  $Param{Filter};

    # create or extend the filter with the ArticleID or TicketID
    if ( IsHashRefWithData($Param{Data}) && $Param{Data}->{ArticleID} ) {
        # add ArticleID to filter
        $Filter //= {};
        $Filter->{AND} //= [];
        push @{$Filter->{AND}}, {
            Field    => 'ArticleID',
            Operator => 'EQ',
            Value    => $Param{Data}->{ArticleID}
        };
    }
    elsif ( IsHashRefWithData($Param{Data}) && $Param{Data}->{TicketID} ) {
        # add TicketID to filter
        $Filter //= {};
        $Filter->{AND} //= [];
        push @{$Filter->{AND}}, {
            Field    => 'TicketID',
            Operator => 'EQ',
            Value    => $Param{Data}->{TicketID}
        };
    }

    # do the search
    my @TicketIDs = $Kernel::OM->Get('Ticket')->TicketSearch(
        Result => 'ARRAY',
        Search => $Filter,
        UserID => 1,
    );

    return @TicketIDs;
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
