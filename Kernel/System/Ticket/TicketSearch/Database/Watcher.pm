# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::Watcher;

use strict;
use warnings;

use base qw(
    Kernel::System::Ticket::TicketSearch::Database::Common
);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Ticket::TicketSearch::Database::Watcher - attribute module for database ticket search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Filter => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Filter => [
            'WatcherUserID',
        ],
        Sort => []
    };
}

=item Filter()

run this module and return the SQL extensions

    my $Result = $Object->Filter(
        Filter => {}
    );

    $Result = {
        SQLJoin    => [ ],
    };

=cut

sub Filter {
    my ( $Self, %Param ) = @_;
    my @SQLJoin;
    my @SQLWhere;

    # check params
    if ( !$Param{Filter} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Filter!",
        );
        return;
    }

    # check if we have to add a join
    if ( !$Self->{AlreadyJoined} ) {
        push( @SQLJoin, 'INNER JOIN ticket_watcher tw ON st.id = tw.ticket_id' );
        $Self->{AlreadyJoined} = 1;
    }

    if ( $Param{Filter}->{Operator} eq 'EQ' ) {
        push( @SQLWhere, 'tw.user_id = '.$Param{Filter}->{Value} );
    }
    elsif ( $Param{Filter}->{Operator} eq 'IN' ) {
        push( @SQLWhere, 'tw.user_id IN ('.(join(',', @{$Param{Filter}->{Value}})).')' );
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unsupported Operator $Param{Filter}->{Operator}!",
        );
        return;
    }

    return {
        SQLJoin  => \@SQLJoin,
        SQLWhere => \@SQLWhere,
    };        
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
