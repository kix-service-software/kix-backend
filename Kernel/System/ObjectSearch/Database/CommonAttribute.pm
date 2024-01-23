# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::CommonAttribute;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::CommonAttribute - base attribute module for object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        'Property' => {
            IsSearchable => 0|1,
            IsSortable   => 0|1,
            Operators    => [...],
            ValueType    => 'NUMERIC|TEXTUAL|DATE|DATETIME'
        }
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {};
}

=item Search()

provides required sql search definition

    my $Result = $Object->Search(
        Search => {                   # required
            Field    => '...',        # required
            Operator => '...',        # required
            Value    => '...'         # required
        },
        BoolOperator => '...',        # required
        UserID       => '...'         # required
    );

    $Result = {
        Select  => [],
        From    => [],
        Join    => [],
        Where   => [],
        GroupBy => [],
        Having  => [],
        OrderBy => []
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    return;
}

=item Sort()

provides required sql sort definition

    my $Result = $Object->Sort(
        Attribute => '...'      # required
    );

    $Result = {
        Select  => [],
        From    => [],
        Join    => [],
        Where   => [],
        GroupBy => [],
        Having  => [],
        OrderBy => []
    };

=cut

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSortParams( %Param ) );

    return;
}

=begin Internal:

=cut

sub _GetCondition {
    my ( $Self, %Param ) = @_;

    # check needed parameter
    for my $Needed ( qw(Column Value Operator) ) {
        if ( !defined( $Param{ $Needed } ) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!",
                );
            }
            return;
        }
    }

    # check Operator
    my $Function = "_Operation$Param{Operator}";
    if ( $Param{Operator} eq '!IN' ) {
        $Function = "_OperationNOTIN";
    }
    if ( !$Self->can( $Function ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unsupported Operator '$Param{Operator}'!"
            );
        }
        return;
    }

    return $Self->$Function(
        %Param
    );
}

sub _OperationEQ {
    my ( $Self, %Param ) = @_;

    # prepare columns and values
    my $Columns = [];
    my $Values  = [];
    my $Success = $Self->_PrepareColumnAndValue(
        %Param,
        ColumnRef => $Columns,
        ValueRef  => $Values
    );
    return if ( !$Success );

    # prepare conditions
    my @Conditions;
    for my $Column ( @{ $Columns } ) {
        for my $Value ( @{ $Values } ) {
            push( @Conditions, ( $Column . ' = ' . $Value ) );

            if ( $Param{NULLValue} ) {
                # add 'IS NULL' for empty search string or zero
                if (
                    $Value eq q{''}
                    || $Value eq q{0}
                    || $Value eq q{'0'}
                ) {
                    # remove 'LOWER()' from column string for CaseInsensitive
                    my $NULLColumn = $Column;
                    if ( $Param{CaseInsensitive} ) {
                        $NULLColumn =~ s/^LOWER\((.+)\)$/$1/;
                    }

                    push( @Conditions, ( $NULLColumn . ' IS NULL' ) );
                }
            }
        }
    }

    # join conditions
    my $Condition = $Self->_JoinConditions(
        Conditions => \@Conditions
    );

    # add supplement to condition
    return $Self->_AddSupplement(
        %Param,
        Condition => $Condition
    );
}

sub _OperationNE {
    my ( $Self, %Param ) = @_;

    # prepare columns and values
    my $Columns = [];
    my $Values  = [];
    my $Success = $Self->_PrepareColumnAndValue(
        %Param,
        ColumnRef => $Columns,
        ValueRef  => $Values
    );
    return if ( !$Success );

    # prepare conditions
    my @Conditions;
    for my $Column ( @{ $Columns } ) {
        for my $Value ( @{ $Values } ) {
            if (
                $Param{ValueType}
                && $Param{ValueType} eq 'NUMERIC'
            ) {
                push( @Conditions, ( $Column . ' <> ' . $Value ) );
            }
            else {
                push( @Conditions, ( $Column . ' != ' . $Value ) );
            }

            if ( $Param{NULLValue} ) {
                # remove 'LOWER()' from column string for CaseInsensitive
                my $NULLColumn = $Column;
                if ( $Param{CaseInsensitive} ) {
                    $NULLColumn =~ s/^LOWER\((.+)\)$/$1/;
                }

                # add 'IS NULL' when not empty search string or zero
                if (
                    $Value ne q{''}
                    && $Value ne q{0}
                    && $Value ne q{'0'}
                ) {
                    push( @Conditions, ( $NULLColumn . ' IS NULL' ) );
                }
            }
        }
    }

    # join conditions
    my $Condition = $Self->_JoinConditions(
        Conditions => \@Conditions
    );

    # add supplement to condition
    return $Self->_AddSupplement(
        %Param,
        Condition => $Condition
    );
}

sub _OperationLT {
    my ( $Self, %Param ) = @_;

    # prepare columns and values
    my $Columns = [];
    my $Values  = [];
    my $Success = $Self->_PrepareColumnAndValue(
        %Param,
        ColumnRef => $Columns,
        ValueRef  => $Values
    );
    return if ( !$Success );

    # prepare conditions
    my @Conditions;
    for my $Column ( @{ $Columns } ) {
        for my $Value ( @{ $Values } ) {
            push( @Conditions, ( $Column . ' < ' . $Value ) );
        }
    }

    # join conditions
    my $Condition = $Self->_JoinConditions(
        Conditions => \@Conditions
    );

    # add supplement to condition
    return $Self->_AddSupplement(
        %Param,
        Condition => $Condition
    );
}

sub _OperationLTE {
    my ( $Self, %Param ) = @_;

    # prepare columns and values
    my $Columns = [];
    my $Values  = [];
    my $Success = $Self->_PrepareColumnAndValue(
        %Param,
        ColumnRef => $Columns,
        ValueRef  => $Values
    );
    return if ( !$Success );

    # prepare conditions
    my @Conditions;
    for my $Column ( @{ $Columns } ) {
        for my $Value ( @{ $Values } ) {
            push( @Conditions, ( $Column . ' <= ' . $Value ) );
        }
    }

    # join conditions
    my $Condition = $Self->_JoinConditions(
        Conditions => \@Conditions
    );

    # add supplement to condition
    return $Self->_AddSupplement(
        %Param,
        Condition => $Condition
    );
}

sub _OperationGT {
    my ( $Self, %Param ) = @_;

    # prepare columns and values
    my $Columns = [];
    my $Values  = [];
    my $Success = $Self->_PrepareColumnAndValue(
        %Param,
        ColumnRef => $Columns,
        ValueRef  => $Values
    );
    return if ( !$Success );

    # prepare conditions
    my @Conditions;
    for my $Column ( @{ $Columns } ) {
        for my $Value ( @{ $Values } ) {
            push( @Conditions, ( $Column . ' > ' . $Value ) );
        }
    }

    # join conditions
    my $Condition = $Self->_JoinConditions(
        Conditions => \@Conditions
    );

    # add supplement to condition
    return $Self->_AddSupplement(
        %Param,
        Condition => $Condition
    );
}

sub _OperationGTE {
    my ( $Self, %Param ) = @_;

    # prepare columns and values
    my $Columns = [];
    my $Values  = [];
    my $Success = $Self->_PrepareColumnAndValue(
        %Param,
        ColumnRef => $Columns,
        ValueRef  => $Values
    );
    return if ( !$Success );

    # prepare conditions
    my @Conditions;
    for my $Column ( @{ $Columns } ) {
        for my $Value ( @{ $Values } ) {
            push( @Conditions, ( $Column . ' >= ' . $Value ) );
        }
    }

    # join conditions
    my $Condition = $Self->_JoinConditions(
        Conditions => \@Conditions
    );

    # add supplement to condition
    return $Self->_AddSupplement(
        %Param,
        Condition => $Condition
    );
}

sub _OperationSTARTSWITH {
    my ( $Self, %Param ) = @_;

    # prepare columns and values
    my $Columns = [];
    my $Values  = [];
    my $Success = $Self->_PrepareColumnAndValue(
        %Param,
        ColumnRef    => $Columns,
        ValueRef     => $Values,
        OperatorType => 'LIKE',
        ValueSuffix  => '%'
    );
    return if ( !$Success );

    # prepare conditions
    my @Conditions;
    for my $Column ( @{ $Columns } ) {
        for my $Value ( @{ $Values } ) {
            push( @Conditions, ( $Column . ' LIKE ' . $Value ) );
        }
    }

    # join conditions
    my $Condition = $Self->_JoinConditions(
        Conditions => \@Conditions
    );

    # add supplement to condition
    return $Self->_AddSupplement(
        %Param,
        Condition => $Condition
    );
}

sub _OperationENDSWITH {
    my ( $Self, %Param ) = @_;

    # prepare columns and values
    my $Columns = [];
    my $Values  = [];
    my $Success = $Self->_PrepareColumnAndValue(
        %Param,
        ColumnRef    => $Columns,
        ValueRef     => $Values,
        OperatorType => 'LIKE',
        ValuePrefix  => '%'
    );
    return if ( !$Success );

    # prepare conditions
    my @Conditions;
    for my $Column ( @{ $Columns } ) {
        for my $Value ( @{ $Values } ) {
            push( @Conditions, ( $Column . ' LIKE ' . $Value ) );
        }
    }

    # join conditions
    my $Condition = $Self->_JoinConditions(
        Conditions => \@Conditions
    );

    # add supplement to condition
    return $Self->_AddSupplement(
        %Param,
        Condition => $Condition
    );
}

sub _OperationCONTAINS {
    my ( $Self, %Param ) = @_;

    # prepare columns and values
    my $Columns = [];
    my $Values  = [];
    my $Success = $Self->_PrepareColumnAndValue(
        %Param,
        ColumnRef    => $Columns,
        ValueRef     => $Values,
        OperatorType => 'LIKE',
        ValuePrefix  => '%',
        ValueSuffix  => '%'
    );
    return if ( !$Success );

    # prepare conditions
    my @Conditions;
    for my $Column ( @{ $Columns } ) {
        for my $Value ( @{ $Values } ) {
            push( @Conditions, ( $Column . ' LIKE ' . $Value ) );
        }
    }

    # join conditions
    my $Condition = $Self->_JoinConditions(
        Conditions => \@Conditions
    );

    # add supplement to condition
    return $Self->_AddSupplement(
        %Param,
        Condition => $Condition
    );
}

sub _OperationLIKE {
    my ( $Self, %Param ) = @_;

    # prepare columns and values
    my $Columns = [];
    my $Values  = [];
    my $Success = $Self->_PrepareColumnAndValue(
        %Param,
        ColumnRef       => $Columns,
        ValueRef        => $Values,
        OperatorType    => 'LIKE',
        ReplaceWildcard => 1
    );
    return if ( !$Success );

    # prepare conditions
    my @Conditions;
    for my $Column ( @{ $Columns } ) {
        for my $Value ( @{ $Values } ) {
            push( @Conditions, ( $Column . ' LIKE ' . $Value ) );
        }
    }

    # join conditions
    my $Condition = $Self->_JoinConditions(
        Conditions => \@Conditions
    );

    # add supplement to condition
    return $Self->_AddSupplement(
        %Param,
        Condition => $Condition
    );
}

sub _OperationIN {
    my ( $Self, %Param ) = @_;

    # prepare columns and values
    my $Columns = [];
    my $Values  = [];
    my $Success = $Self->_PrepareColumnAndValue(
        %Param,
        ColumnRef => $Columns,
        ValueRef  => $Values
    );
    return if ( !$Success );

    my @Conditions;
    for my $Column ( @{ $Columns } ) {
        if ( @{ $Values } ) {
            # split IN statement with more than 900 elements in more statements combined with OR
            # because Oracle doesn't support more than 1000 elements for one IN statement.
            my @Values = @{ $Values };
            while ( @Values ) {
                # remove section in the array
                my @ValuesPart = splice( @Values, 0, 900 );

                # add condition part
                push( @Conditions, ( $Column . ' IN (' . join( ',', @ValuesPart ) . ')' ) );
            }
        }
        else {
            push( @Conditions, '1=0' );

            last;
        }
    }

    # join conditions
    my $Condition = $Self->_JoinConditions(
        Conditions => \@Conditions
    );

    # add supplement to condition
    return $Self->_AddSupplement(
        %Param,
        Condition => $Condition
    );
}

sub _OperationNOTIN {
    my ( $Self, %Param ) = @_;

    # prepare columns and values
    my $Columns = [];
    my $Values  = [];
    my $Success = $Self->_PrepareColumnAndValue(
        %Param,
        ColumnRef => $Columns,
        ValueRef  => $Values
    );
    return if ( !$Success );

    my @Conditions;
    for my $Column ( @{ $Columns } ) {
        if ( @{ $Values } ) {
            # split IN statement with more than 900 elements in more statements combined with OR
            # because Oracle doesn't support more than 1000 elements for one IN statement.
            my @ConditionParts;
            my @Values = @{ $Values };
            while ( @Values ) {
                # remove section in the array
                my @ValuesPart = splice( @Values, 0, 900 );

                # add condition part
                push( @ConditionParts, ( $Column . ' NOT IN (' . join( ',', @ValuesPart ) . ')' ) );
            }

            # combine condition parts with AND
            if ( @ConditionParts > 1 ) {
                push( @Conditions, ( '(' . join( ' AND ', @ConditionParts ) . ')' ) );
            }
            else {
                push( @Conditions, $ConditionParts[0] );
            }
        }
        else {
            push( @Conditions, '1=1' );

            last;
        }
    }

    # join conditions
    my $Condition = $Self->_JoinConditions(
        Conditions => \@Conditions
    );

    # add supplement to condition
    return $Self->_AddSupplement(
        %Param,
        Condition => $Condition
    );
}

sub _PrepareColumnAndValue {
    my ( $Self, %Param ) = @_;

    # prepare columns
    if ( IsArrayRef( $Param{Column} ) ) {
        if ( !@{ $Param{Column} } ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Invalid parameter Column!'
                );
            }
            return;
        }
        for my $Column ( @{ $Param{Column} } ) {
            if ( !$Column ) {
                if ( !$Param{Silent} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => 'Invalid parameter Column!'
                    );
                }
                return;
            }

            push( @{ $Param{ColumnRef} }, $Column );
        }
    }
    else {
        if ( !$Param{Column} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Invalid parameter Column!'
                );
            }
            return;
        }

        push( @{ $Param{ColumnRef} }, $Param{Column} );
    }
    for my $Column ( @{ $Param{ColumnRef} } ) {
        # cast numeric to varchar for like-operations
        if (
            $Param{OperatorType}
            && $Param{OperatorType} eq 'LIKE'
            && $Param{ValueType}
            && $Param{ValueType} eq 'NUMERIC'
        ) {
            $Column = 'CAST(' . $Column . ' AS CHAR(20))';
        }

        # cast lower for case insensitive searches, if its not a static search
        if (
            !$Param{IsStaticSearch}
            && $Param{CaseInsensitive}
        ) {
            if ( $Kernel::OM->Get('DB')->GetDatabaseFunction('CaseSensitive') ) {
                if ( $Kernel::OM->Get('DB')->GetDatabaseFunction('LcaseLikeInLargeText') ) {
                    $Column = 'LCASE(' . $Column . ')';
                }
                else {
                    $Column = 'LOWER(' . $Column . ')';
                }
            }
        }
    }

    if ( IsArrayRef( $Param{Value} ) ) {
        for my $Value ( @{ $Param{Value} } ) {
            if ( !defined( $Value ) ) {
                if ( !$Param{Silent} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => 'Invalid parameter Value!'
                    );
                }
                return;
            }

            push( @{ $Param{ValueRef} }, $Value );
        }
    }
    else {
        push( @{ $Param{ValueRef} }, $Param{Value} );
    }
    for my $Value ( @{ $Param{ValueRef} } ) {
        # make value lower case for IsStaticSearch or CaseInsensitive
        if (
            $Param{IsStaticSearch}
            || $Param{CaseInsensitive}
        ) {
            $Value = lc( $Value );
        }

        # quote given value
        if (
            $Param{ValueType}
            && $Param{ValueType} eq 'NUMERIC'
        ) {
            $Value = $Kernel::OM->Get('DB')->Quote( $Value, 'Integer', $Param{Silent} );
        }
        elsif(
            $Param{OperatorType}
            && $Param{OperatorType} eq 'LIKE'
        ) {
            $Value = $Kernel::OM->Get('DB')->Quote( $Value, 'Like', $Param{Silent} );
        }
        else {
            $Value = $Kernel::OM->Get('DB')->Quote( $Value, undef, $Param{Silent} );
        }
        if ( !defined( $Value ) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Invalid parameter Value!'
                );
            }
            return;
        }

        # preparations for LIKE-operations
        if(
            $Param{OperatorType}
            && $Param{OperatorType} eq 'LIKE'
        ) {
            if ( $Param{ReplaceWildcard} ) {
                $Value =~ s/\*/%/g;
            }
            if ( $Param{ValuePrefix} ) {
                $Value = $Param{ValuePrefix} . $Value;
            }
            if ( $Param{ValueSuffix} ) {
                $Value = $Value . $Param{ValueSuffix};
            }

            $Value =~ s/%+/%/g;
        }

        # add quotation
        if (
            !$Param{ValueType}
            || $Param{ValueType} ne 'NUMERIC'
            || (
                $Param{OperatorType}
                && $Param{OperatorType} eq 'LIKE'
            )
        ) {
            $Value = q{'} . $Value . q{'};
        }
    }

    return 1;
}

sub _JoinConditions {
    my ($Self, %Param) = @_;

    if ( @{ $Param{Conditions} } > 1 ) {
        return '(' . join( ' OR ', @{ $Param{Conditions} } ) . ')';
    }
    else {
        return $Param{Conditions}->[0];
    }
}

sub _AddSupplement {
    my ($Self, %Param) = @_;

    my $Condition = $Param{Condition};
    # Adds additional SQL clauses to the condition
    if ( IsArrayRefWithData( $Param{Supplement} ) ) {
        my @Conditions = (
            $Condition,
            @{ $Param{Supplement} }
        );
        $Condition = '(' . join( ' AND ', @Conditions ) . ')';
    }

    return $Condition;
}

sub _CheckSearchParams {
    my ($Self, %Param) = @_;

    # check required search parameter
    if (
        ref( $Param{Search} ) ne 'HASH'
        || !defined( $Param{Search}->{Field} )
        || !defined( $Param{Search}->{Operator} )
        || !defined( $Param{Search}->{Value} )
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Invalid Search!',
            );
        }
        return;
    }

    # check required parameter
    if ( !$Param{UserID} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Invalid UserID!',
            );
        }
        return;
    }

    # get supported attributes of backend
    my $AttributeList = $Self->GetSupportedAttributes();

    # check for supported attribute
    if (
        !defined( $AttributeList->{ $Param{Search}->{Field} } )
        || !$AttributeList->{ $Param{Search}->{Field} }->{IsSearchable}
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Invalid search field "' . $Param{Search}->{Field} . '"!'
            );
        }
        return;
    }

    # check supported boolean operator
    if (
        !$Param{BoolOperator}
        || (
            $Param{BoolOperator} ne 'AND'
            && $Param{BoolOperator} ne 'OR'
        )
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Invalid BoolOperator "' . $Param{BoolOperator} . '"!'
            );
        }
        return;
    }

    # check supported operator
    my %Operators = map { $_ => 1 } @{ $AttributeList->{ $Param{Search}->{Field} }->{Operators} };
    if ( !$Operators{ $Param{Search}->{Operator} } ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Invalid operator "' . $Param{Search}->{Operator}
                          . '" for search field "' . $Param{Search}->{Field} . '"!'
            );
        }
        return;
    }

    # check value type
    if ( IsArrayRef( $Param{Search}->{Value} ) ) {
        for my $Value ( @{ $Param{Search}->{Value} } ) {
            $Value = $Self->_ValidateValueType(
                Field         => $Param{Search}->{Field},
                Value         => $Value,
                AttributeList => $AttributeList,
                Silent        => $Param{Silent}
            );
            return if ( !defined( $Value ) );
        }
    }
    else {
        $Param{Search}->{Value} = $Self->_ValidateValueType(
            Field         => $Param{Search}->{Field},
            Value         => $Param{Search}->{Value},
            AttributeList => $AttributeList,
            Silent        => $Param{Silent}
        );
        return if ( !defined( $Param{Search}->{Value} ) );
    }

    return 1;
}

sub _ValidateValueType {
    my ($Self, %Param) = @_;

    if ( !defined( $Param{Value} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Undefined value for search field "' . $Param{Field} . '"!'
            );
        }
        return;
    }
    elsif (
        $Param{AttributeList}->{ $Param{Field} }->{ValueType}
        && $Param{AttributeList}->{ $Param{Field} }->{ValueType} eq 'NUMERIC'
        && $Param{Value} !~ m/^-?\d+$/
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Invalid value "' . $Param{Value}
                          . '" for valuetype "' . $Param{AttributeList}->{ $Param{Field} }->{ValueType}
                          . '" for search field "' . $Param{Field} . '"!'
            );
        }
        return;
    }
    # special handling for date without time. append begin of day
    elsif (
        $Param{AttributeList}->{ $Param{Field} }->{ValueType}
        && $Param{AttributeList}->{ $Param{Field} }->{ValueType} eq 'DATE'
        && $Param{Value} =~ m/^\d{4}-\d{2}-\d{2}$/
    ) {
        $Param{Value} = $Param{Value} . ' 00:00:00';
    }
    elsif (
        $Param{AttributeList}->{ $Param{Field} }->{ValueType}
        && (
            $Param{AttributeList}->{ $Param{Field} }->{ValueType} eq 'DATE'
            || $Param{AttributeList}->{ $Param{Field} }->{ValueType} eq 'DATETIME'
        )
    ) {
        # convert to unix time and check
        my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
            String => $Param{Value},
            Silent => 1,
        );
        if ( !$SystemTime ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Invalid value "' . $Param{Value}
                              . '" for valuetype "' . $Param{AttributeList}->{ $Param{Search}->{Field} }->{ValueType}
                              . '" for search field "' . $Param{Search}->{Field} . '"!'
                );
            }
            return;
        }

        # convert back to timestamp (relative calculations have been done above)
        $Param{Value} = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
            SystemTime => $SystemTime
        );
    }

    return $Param{Value};
}

sub _CheckSortParams {
    my ($Self, %Param) = @_;

    for my $Needed ( qw(Attribute Language) ) {
        if ( !$Param{ $Needed } ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Need ' . $Needed . '!',
                );
            }
            return;
        }
    }

    # get supported attributes of backend
    my $AttributeList = $Self->GetSupportedAttributes();

    if (
        !defined( $AttributeList->{ $Param{Attribute} } )
        || !$AttributeList->{ $Param{Attribute} }->{IsSortable}
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Invalid sort attribute "' . $Param{Attribute} . '"!'
            );
        }
        return;
    }

    return 1;
}

=end Internal:

=cut

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
