# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        State       => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        StateTypeID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        StateType   => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # init Definition
    my %AttributeDefinition = (
        StateID     => {
            Column       => 'st.ticket_state_id',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        State       => {
            Column       => 'ts.name',
            ConditionDef => {}
        },
        StateTypeID => {
            Column       => 'ts.type_id',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        StateType   => {
            Column       => 'tst.name',
            ConditionDef => {}
        }
    );

    # check for needed joins
    my $TableAliasTLP = 'tlp' . ( $Param{Flags}->{JoinMap}->{TranslationTicketState} // '' );
    my $TableAliasTL  = 'tl' . ( $Param{Flags}->{JoinMap}->{TranslationTicketState} // '' );
    my @SQLJoin = ();
    if ( $Param{Attribute} eq 'State' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketState} ) {
            push( @SQLJoin, 'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id' );

            $Param{Flags}->{JoinMap}->{TicketState} = 1;
        }

        if ( $Param{PrepareType} eq 'Sort' ) {
            if ( !defined( $Param{Flags}->{JoinMap}->{TranslationTicketState} ) ) {
                my $Count = $Param{Flags}->{TranslationJoinCounter}++;
                $TableAliasTLP .= $Count;
                $TableAliasTL  .= $Count;

                push( @SQLJoin, "LEFT OUTER JOIN translation_pattern $TableAliasTLP ON $TableAliasTLP.value = ts.name" );
                push( @SQLJoin, "LEFT OUTER JOIN translation_language $TableAliasTL ON $TableAliasTL.pattern_id = $TableAliasTLP.id AND $TableAliasTL.language = '$Param{Language}'" );

                $Param{Flags}->{JoinMap}->{TranslationTicketState} = $Count;
            }
        }
    }
    elsif ( $Param{Attribute} eq 'StateTypeID' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketState} ) {
            push( @SQLJoin, 'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id' );

            $Param{Flags}->{JoinMap}->{TicketState} = 1;
        }
    }
    elsif ( $Param{Attribute} eq 'StateType' ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketState} ) {
            push( @SQLJoin, 'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id' );

            $Param{Flags}->{JoinMap}->{TicketState} = 1;
        }

        if ( !$Param{Flags}->{JoinMap}->{TicketStateType} ) {
            push( @SQLJoin, 'INNER JOIN ticket_state_type tst ON tst.id = ts.type_id' );

            $Param{Flags}->{JoinMap}->{TicketStateType} = 1;
        }
    }

    my %Attribute = (
        Column => $AttributeDefinition{ $Param{Attribute} }->{Column},
        SQLDef => {
            Join => \@SQLJoin,
        }
    );
    if ( $Param{PrepareType} eq 'Condition' ) {
        $Attribute{ConditionDef} = $AttributeDefinition{ $Param{Attribute} }->{ConditionDef};
    }
    elsif ( $Param{PrepareType} eq 'Sort' ) {
        if ( $Param{Attribute} eq 'State' ) {
            $Attribute{Column} = 'LOWER(COALESCE(' . $TableAliasTL . '.value, ts.name))';
        }
    }

    return \%Attribute;
}

sub Search {
    my ( $Self, %Param ) = @_;

    if (
        ref( $Param{Search} ) eq 'HASH'
        && $Param{Search}->{Field}
        && $Param{Search}->{Field} eq 'StateType'
    ) {
        # check params
        return if ( !$Self->_CheckSearchParams( %Param ) );

        # special handling for StateType 'Open' and 'Closed'
        my @RegularValues = ();
        my @Conditions    = ();

        # convert value to array for handling
        my @PreValues;
        if ( IsArrayRef( $Param{Search}->{Value} ) ) {
            @PreValues = @{ $Param{Search}->{Value} };
        }
        else {
            @PreValues = ( $Param{Search}->{Value} );
        }
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
            # keep other values for regular handling
            else {
                push( @RegularValues, $Value );
            }
        }

        # check if regular handling is still needed
        my @SQLJoin = ();
        if (
            !scalar( @Conditions )
            || scalar( @RegularValues )
        ) {
            if ( $Param{Search}->{Field} eq 'StateType' ) {
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
                Column    => 'tst.name',
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

        return if ( !$Condition );

        # return search def
        return {
            Join  => \@SQLJoin,
            Where => [ $Condition ],
        };
    }
    else {
        return $Self->SUPER::Search(%Param);
    }
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
