# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::State;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Ticket::TicketSearch::Database::Common
);

our @ObjectDependencies = (
    'Config',
    'Log',
);

=head1 NAME

Kernel::System::Ticket::TicketSearch::Database::State - attribute module for database ticket search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Search => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Search => [
            'StateID',
            'StateType',
            'StateTypeID',
        ],
        Sort => [
            'StateID',
        ]
    };
}


=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        Search => {}
    );

    $Result = {
        SQLWhere   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my @SQLWhere;

    # check params
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    my $Operator = $Param{Search}->{Operator};
    my $Value    = $Param{Search}->{Value};
    my @StateIDs;

    # special handling for StateType
    if ( $Param{Search}->{Field} eq 'StateType' ) {

        # get all StateIDs for the given StateTypes
        my @StateTypes = ( $Value );
        if ( IsArrayRefWithData($Value) ) {
            @StateTypes = @{$Value};
        }

        foreach my $StateType ( @StateTypes ) {

            if ( $StateType eq 'Open' ) {
                # get all viewable states
                my @ViewableStateIDs = $Kernel::OM->Get('State')->StateGetStatesByType(
                    Type   => 'Viewable',
                    Result => 'ID',
                );
                push(@StateIDs, @ViewableStateIDs);
            }
            elsif ( $StateType eq 'Closed' ) {
                # get all non-viewable states
                my %AllStateIDs = $Kernel::OM->Get('State')->StateList(
                    UserID => 1,
                );
                my %ViewableStateIDs = $Kernel::OM->Get('State')->StateGetStatesByType(
                    Type   => 'Viewable',
                    Result => 'HASH',
                );
                foreach my $StateID ( sort keys %AllStateIDs ) {
                    next if $ViewableStateIDs{$StateID};
                    push(@StateIDs, $StateID);
                }
            }
            else {
                my @StateTypeStateIDs = $Kernel::OM->Get('State')->StateGetStatesByType(
                    StateType => $StateType,
                    Result    => 'ID',
                );
                if ( !@StateTypeStateIDs ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "No states found for StateType $StateType!",
                    );
                } else {
                    push(@StateIDs, @StateTypeStateIDs);
                }
            }
        }

        if (!@StateIDs) {
            # we need to restrict to something
            push(@StateIDs, -1);
        }

        # we have to do an IN seasrch in this case
        $Operator = 'IN';
    }
    elsif ( $Param{Search}->{Field} eq 'StateTypeID' ) {

        # get all StateIDs for the given StateTypeIDs
        my @StateTypeIDs = ( $Value );
        if ( IsArrayRefWithData($Value) ) {
            @StateTypeIDs = @{$Value};
        }

        foreach my $StateTypeID ( @StateTypeIDs ) {
            my $StateType = $Kernel::OM->Get('State')->StateTypeLookup(
                StateTypeID => $StateTypeID,
            );
            if ( !$StateType ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No StateType with ID $StateTypeID!",
                );
                return;
            }
            my @StateTypeStateIDs = $Kernel::OM->Get('State')->StateGetStatesByType(
                StateType => $StateType,
                Result    => 'ID',
            );

            push(@StateIDs, @StateTypeStateIDs);
        }

        if (!@StateIDs) {
            # we need to restrict to something
            push(@StateIDs, -1);
        }

        # we have to do an IN seasrch in this case
        $Operator = 'IN';
    }
    elsif ( $Param{Search}->{Field} eq 'State' ) {
        my @StateList = ( $Param{Search}->{Value} );
        if ( IsArrayRefWithData($Param{Search}->{Value}) ) {
            @StateList = @{$Param{Search}->{Value}}
        }
        foreach my $State ( @StateList ) {
            my $StateID = $Kernel::OM->Get('State')->StateLookup(
                State => $State,
            );
            if ( !$StateID ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown state $State!",
                );
                return;
            }

            push( @StateIDs, $StateID );
        }
    }
    else {
        @StateIDs = ( $Param{Search}->{Value} );
        if ( IsArrayRefWithData($Param{Search}->{Value}) ) {
            @StateIDs = @{$Param{Search}->{Value}}
        }
    }

    if ( $Operator eq 'EQ' ) {
        push( @SQLWhere, 'st.ticket_state_id = '.$StateIDs[0] );
    }
    elsif ( $Param{Search}->{Operator} eq 'NE' ) {
        push( @SQLWhere, 'st.ticket_state_id != '.$StateIDs[0] );
    }
    elsif ( $Param{Search}->{Operator} eq 'LT' ) {
        push( @SQLWhere, 'st.ticket_state_id < '.$StateIDs[0] );
    }
    elsif ( $Param{Search}->{Operator} eq 'LTE' ) {
        push( @SQLWhere, 'st.ticket_state_id <= '.$StateIDs[0] );
    }
    elsif ( $Param{Search}->{Operator} eq 'GT' ) {
        push( @SQLWhere, 'st.ticket_state_id > '.$StateIDs[0] );
    }
    elsif ( $Param{Search}->{Operator} eq 'GTE' ) {
        push( @SQLWhere, 'st.ticket_state_id >= '.$StateIDs[0] );
    }
    elsif ( $Param{Search}->{Operator} eq 'IN' && $Param{Search}->{Not} ) {
        push( @SQLWhere, 'st.ticket_state_id NOT IN ('.(join(',', @StateIDs)).')' );
    }
    elsif ( $Operator eq 'IN' ) {
        push( @SQLWhere, 'st.ticket_state_id IN ('.(join(',', @StateIDs)).')' );
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unsupported Operator $Param{Search}->{Operator}!",
        );
        return;
    }

    return {
        SQLWhere => \@SQLWhere,
    };
}

=item Sort()

run this module and return the SQL extensions

    my $Result = $Object->Sort(
        Attribute => '...'      # required
    );

    $Result = {
        SQLAttrs   => [ ],          # optional
        SQLOrderBy => [ ]           # optional
    };

=cut

sub Sort {
    my ( $Self, %Param ) = @_;

    return {
        SQLAttrs => [
            'st.ticket_state_id'
        ],
        SQLOrderBy => [
            'st.ticket_state_id'
        ],
    };
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
