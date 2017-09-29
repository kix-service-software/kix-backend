# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::TicketTimes;

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

Kernel::System::Ticket::TicketSearch::Database::TicketTimes - attribute module for database ticket search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my @AttributeList = $Object->GetSupportedAttributes();

    $Result = [
        ...
    ];

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return (
        '',
    );
}


=item Run()

run this module and return the SQL extensions

    my $Result = $Object->Run(
        Filter => {}
    );

    $Result = {
        SQLWhere   => [ ],
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    my $Value;
    my @SQLWhere;

    # check params
    if ( !$Param{Filter} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Filter!",
        );
        return;
    }

    # map search attributes to table attributes
    my %AttributeMapping = (
        CreateTime             => 'st.create_time_unix',
        PendingTime            => 'st.until_time',
        LastChangeTime         => 'st.change_time',
        EscalationTime         => 'st.escalation_time',
        EscalationUpdateTime   => 'st.escalation_update_time',
        EscalationResponseTime => 'st.escalation_response_time',
        EscalationSolutionTime => 'st.escalation_solution_time',
    );

    # prepare value
    if ( $Param{Filter}->{Field} =~ /^(Pending|Escalation)/ ) {
        # convert to unix time
        $Value = $TimeObject->TimeStamp2SystemTime(
            String => $Param{Filter}->{Value},
        );
    }
    else {
        # handle value as string
        $Value = "'".Param{Filter}->{Value}."'";
    }

    # change and close time
    if ( $Param{Filter}->{Operation} eq 'EQ' ) {
        push( @SQLWhere, $AttributeMapping{$Param{Filter}->{Field}}.' = '.$Value );
    }
    elsif ( $Param{Filter}->{Operation} eq 'LT' ) {
        push( @SQLWhere, $AttributeMapping{$Param{Filter}->{Field}}.' < '.$Value );
    }
    elsif ( $Param{Filter}->{Operation} eq 'GT' ) {
        push( @SQLWhere, $AttributeMapping{$Param{Filter}->{Field}}.' > '.$Value );
    }
    elsif ( $Param{Filter}->{Operation} eq 'LTE' ) {
        push( @SQLWhere, $AttributeMapping{$Param{Filter}->{Field}}.' <= '.$Value );
    }
    elsif ( $Param{Filter}->{Operation} eq 'GTE' ) {
        push( @SQLWhere, $AttributeMapping{$Param{Filter}->{Field}}.' >= '.$Value );
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unsupported operation $Param{Filter}->{Operation}!",
        );
        return;
    }

    # some special handling
    if ( $Param{Filter}->{Field} =~ /^Escalation/ ) {
        # in case of escalation time search, exclude tickets without escalations
        push( @SQLWhere, $AttributeMapping{$Param{Filter}->{Field}}.' != 0' );
    }
    elsif ( $Param{Filter}->{Field} =~ /^Pending/ ) {
        # in case of pending time search, restrict states to pending states
        my @List = $Kernel::OM->Get('Kernel::System::State')->StateGetStatesByType(
            StateType => [ 'pending reminder', 'pending auto' ],
            Result    => 'ID',
        );
        if (@List) {
            push( @SQLWhere, 'st.ticket_state_id IN ('.(join(', ', sort @List)) );
        }
    }

    return {
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
