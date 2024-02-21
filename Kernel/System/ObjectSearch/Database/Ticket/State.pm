# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::State;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::State - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        StateID     => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType    => 'NUMERIC'
        },
        State       => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        StateTypeID => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType    => 'NUMERIC'
        },
        StateType   => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # init mapping
    my %AttributeMapping = (
        StateID     => {
            Column    => 'st.ticket_state_id',
            ValueType => 'NUMERIC'
        },
        State       => {
            Column    => 'ts.name'
        },
        StateTypeID => {
            Column    => 'ts.type_id',
            ValueType => 'NUMERIC'
        },
        StateType   => {
            Column    => 'tst.name'
        }
    );

    # convert value to array for handling
    my @PreValues;
    if ( IsArrayRef( $Param{Search}->{Value} ) ) {
        @PreValues = @{ $Param{Search}->{Value} };
    }
    else {
        @PreValues = ( $Param{Search}->{Value} );
    }

    # special handling for StateType 'Open' and 'Closed'
    my @RegularValues = ();
    my @Conditions    = ();
    if ( $Param{Search}->{Field} eq 'StateType' ) {
        # process values
        for my $Value ( @PreValues ) {
            # handle 'Open' and 'Closed'
            if (
                $Value eq 'Open'
                || $Value eq 'Closed'
            ) {
                # get viewable state ids
                my @ViewableStateIDs = $Kernel::OM->Get('State')->StateGetStatesByType(
                    Type   => 'Viewable',
                    Result => 'ID',
                );

                # determine if positive or negative opterator is needed
                my $OperatorLogic = 1;
                if ( $Value eq 'Closed' ) {
                    $OperatorLogic *= -1;
                }
                if (
                    $Param{Search}->{Operator} eq 'NE'
                    || $Param{Search}->{Operator} eq '!IN'
                ) {
                    $OperatorLogic *= -1;
                }

                # positive operator
                my $Condition;
                if ( $OperatorLogic == 1 ) {
                    $Condition = $Self->_GetCondition(
                        Operator  => 'IN',
                        Column    => 'st.ticket_state_id',
                        ValueType => 'NUMERIC',
                        Value     => \@ViewableStateIDs,
                        Silent    => $Param{Silent}
                    );
                }
                # negative operator
                else {
                    $Condition = $Self->_GetCondition(
                        Operator  => '!IN',
                        Column    => 'st.ticket_state_id',
                        ValueType => 'NUMERIC',
                        Value     => \@ViewableStateIDs,
                        Silent    => $Param{Silent}
                    );
                }
                return if ( !$Condition );

                # add special condition
                push( @Conditions, $Condition );
            }
            # handle 'Closed'
            elsif( $Value eq 'Closed' ) {
            }
            # keep other values for regular handling
            else {
                push( @RegularValues, $Value );
            }
        }
    }
    # default handling
    else {
        @RegularValues = @PreValues;
    }

    # check if regular handling is still needed
    my @SQLJoin = ();
    if (
        !scalar( @Conditions )
        || scalar( @RegularValues )
    ) {
        # check for needed joins
        if ( $Param{Search}->{Field} eq 'State' ) {
            if ( !$Param{Flags}->{JoinMap}->{TicketState} ) {
                push( @SQLJoin, 'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id' );

                $Param{Flags}->{JoinMap}->{TicketState} = 1;
            }
        }
        elsif ( $Param{Search}->{Field} eq 'StateTypeID' ) {
            if ( !$Param{Flags}->{JoinMap}->{TicketState} ) {
                push( @SQLJoin, 'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id' );

                $Param{Flags}->{JoinMap}->{TicketState} = 1;
            }
        }
        elsif ( $Param{Search}->{Field} eq 'StateType' ) {
            if ( !$Param{Flags}->{JoinMap}->{TicketState} ) {
                push( @SQLJoin, 'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id' );

                $Param{Flags}->{JoinMap}->{TicketState} = 1;
            }

            if ( !$Param{Flags}->{JoinMap}->{TicketStateType} ) {
                push( @SQLJoin, 'INNER JOIN ticket_state_type tst ON tst.id = ts.type_id' );

                $Param{Flags}->{JoinMap}->{TicketStateType} = 1;
            }
        }

        # prepare condition
        my $Condition = $Self->_GetCondition(
            Operator  => $Param{Search}->{Operator},
            Column    => $AttributeMapping{ $Param{Search}->{Field} }->{Column},
            ValueType => $AttributeMapping{ $Param{Search}->{Field} }->{ValueType},
            Value     => \@RegularValues,
            Silent    => $Param{Silent}
        );
        return if ( !$Condition );

        push( @Conditions, $Condition );
    }

    my $Condition;
    if ( scalar( @Conditions ) > 1 ) {
        $Condition = '(' . join( ' OR ', @Conditions ) . ')';
    }
    else {
        $Condition = $Conditions[0];
    }

    # return search def
    return {
        Join  => \@SQLJoin,
        Where => [ $Condition ],
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSortParams( %Param ) );

    # check for needed joins
    my $TableAliasTLP = 'tlp' . ( $Param{Flags}->{JoinMap}->{TranslationTicketState} // '' );
    my $TableAliasTL  = 'tl' . ( $Param{Flags}->{JoinMap}->{TranslationTicketState} // '' );
    my @SQLJoin = ();
    if ( $Param{Attribute} eq 'State' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketState} ) {
            push( @SQLJoin, 'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id' );

            $Param{Flags}->{JoinMap}->{TicketState} = 1;
        }

        if ( !defined( $Param{Flags}->{JoinMap}->{TranslationTicketState} ) ) {
            my $Count = $Param{Flags}->{TranslationJoinCounter}++;
            $TableAliasTLP .= $Count;
            $TableAliasTL  .= $Count;

            push( @SQLJoin, "LEFT OUTER JOIN translation_pattern $TableAliasTLP ON $TableAliasTLP.value = ts.name" );
            push( @SQLJoin, "LEFT OUTER JOIN translation_language $TableAliasTL ON $TableAliasTL.pattern_id = $TableAliasTLP.id AND $TableAliasTL.language = '$Param{Language}'" );

            $Param{Flags}->{JoinMap}->{TranslationTicketState} = $Count;
        }
    }

    # init mapping
    my %AttributeMapping = (
        StateID => {
            Select  => ['st.ticket_state_id'],
            OrderBy => ['st.ticket_state_id']
        },
        State   => {
            Select  => ["LOWER(COALESCE($TableAliasTL.value, ts.name)) AS TranslateState"],
            OrderBy => ['TranslateState']
        }
    );

    # return sort def
    return {
        Join    => \@SQLJoin,
        Select  => $AttributeMapping{ $Param{Attribute} }->{Select},
        OrderBy => $AttributeMapping{ $Param{Attribute} }->{OrderBy}
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
