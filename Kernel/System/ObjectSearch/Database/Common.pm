# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Common;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Common - base attribute module for object search

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

empty method to be overridden by specific attribute module

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Search => { },
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {};
}

=item Search()

empty method to be overridden by specific attribute module

    my $Result = $Object->Search(
        Search => {}
    );

    $Result = {
        Select   => [ ],          # optional
        From    => [ ],          # optional
        Join    => [ ],          # optional
        Where   => [ ],          # optional
        OrderBy => [ ]           # optional
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if !$Self->_CheckSearchParams(%Param);

    return;
}

=item Sort()

empty method to be overridden by specific attribute module

    my $Result = $Object->Sort(
        Attribute => '...'      # required
    );

    $Result = {
        Select   => [ ],          # optional
        OrderBy => [ ]           # optional
    };

=cut

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if !$Self->_CheckSortParams(%Param);

    return;
}

=begin Internal:

=cut


sub PrepareFieldAndValue {
    my ( $Self, %Param ) = @_;

    my $Field = $Param{Field};
    my $Value = $Param{Value};

    # check if database supports LIKE in large text types
    if ( $Kernel::OM->Get('DB')->GetDatabaseFunction('CaseSensitive') ) {
        if ( $Kernel::OM->Get('DB')->GetDatabaseFunction('LcaseLikeInLargeText') ) {
            $Field = "LCASE($Field)";
            $Value = "LCASE('$Value')";
        }
        else {
            $Field = "LOWER($Field)";
            $Value = "LOWER('$Value')";
        }
    }
    else {
        $Value = "'$Value'";

        if ( $Param{IsStaticSearch} ) {
            # lower search pattern if we use static search
            $Value = lc($Value);
        }
    }

    return ($Field, $Value);
}


=item GetOperation()

Generate sql statements for specific object type attributes.

    my $Statements = $Self->GetOperation(
        Column           => 'st.title'         # (required) - table column for statement
                                               #              can be given as string or array ref
        Value            => '123'              # (optional) - table column value for statement
                                               #              can be given as string or array ref
                                               #              If the operator is “EQ” or “NE” and the number of values is greater than 1,
                                               #              then the operator changes to “IN” or “!IN”.
        Supplement       => []                 # (optional) - an array ref of additional statements that will be add to the generated statement
        Operator         => '!IN',             # (required) - operation for the statement
        CaseSensitive    =>  0,                # (optional) - (1|0) enables the case sensitive, not related to "Prepare"
        Prepare          => 1,                 # (optional) - (1|0) enables the preparation of string values
        Supported        => [LT,NE,EQ]         # (required) - list of supported operations of the object attributes
        Type             => 'NUMERIC'          # (optional) - sets the quoting of the values in the sql statements basend on the given type
        ColumnValueIndex => 1                  # (optional) - sets the assignment of column to value, if active then the value is assigned to the column based on the index.
                                               #              If disabled, all values are assigned to each column.
    );

Returns array ref of statements.

    $Statements = [
        'column LIKE \'value%\'',
        ...
    ];

=cut

sub GetOperation {
    my ( $Self, %Param ) = @_;

    return if !$Self->_CheckOperators(%Param);

    if ( !$Param{Column} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No given column!",
            );
        }
        return;
    }

    my $Columns = $Param{Column};
    if ( ref $Param{Column} ne 'ARRAY' ) {
        push( @{$Columns}, $Param{Column} );
    }

    my $Values = $Param{Value};
    if ( ref $Param{Value} ne 'ARRAY' ) {
        push( @{$Values}, $Param{Value} );
    }

    my $Function = "_Operation$Param{Operator}";
    if ( $Param{Operator} eq '!IN' ) {
        $Function = "_OperationNOTIN";
    }

    if (
        IsArrayRef($Param{Value})
        && scalar(@{$Param{Value}}) > 1
        && $Param{Operator} =~ /^(?:EQ|NE)$/sm
    ) {
        $Function = $Param{Operator} eq 'EQ' ? '_OperationIN' : '_OperationNOTIN';
    }

    my @Statements;
    for my $Index ( keys @{$Columns} ) {

        my $Value = $Values;
        if ( $Param{ColumnValueIndex} ) {
            $Value = $Values->[$Index];
        }

        my $Statement = $Self->$Function(
            %Param,
            Value  => $Value,
            Column => $Columns->[$Index],
            Quotes => $Self->_GetQuotes(%Param)
        );

        $Statement = $Self->_SetSupplement(
            %Param,
            Statement => $Statement
        );

        push( @Statements, $Statement);
    }

    return @Statements;
}

=item _CheckOperators()

Checks whether the specified operator is supported by the attribute.

    my $Statements = $Self->GetOperation(
        Operator  => '!IN',             # (required) - operation for the statement
        Supported => [LT,NE,EQ]         # (required) - list of supported operations of the object attributes
    );

Returns boolean.

=cut
sub _CheckOperators {
    my ( $Self, %Param ) = @_;

    # All supported operators are initially disabled.
    # The operators are activated using the “Supported” operators provided.
    my %Operators = (
        'EQ'         => 0,
        'NE'         => 0,
        'STARTSWITH' => 0,
        'ENDSWITH'   => 0,
        'CONTAINS'   => 0,
        'LIKE'       => 0,
        'IN'         => 0,
        '!IN'        => 0,
        'LT'         => 0,
        'GT'         => 0,
        'LTE'        => 0,
        'GTE'        => 0,
    );

    my $Supported = $Param{Supported} || [];
    if ( IsArrayRefWithData($Supported) ) {
        for my $Operator ( @{$Supported} ) {
            if ( !defined $Operators{$Operator} ) {
                if ( !$Param{Silent} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Unsupported Operator $Param{Operator}!",
                    );
                }
                return;
            }
            $Operators{$Operator} = 1;
        }
    }

    return if !%Operators;

    if ( !$Operators{$Param{Operator}} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unsupported Operator $Param{Operator}!",
            );
        }
        return;
    }

    return 1;
}

sub _OperationEQ {
    my ( $Self, %Param ) = @_;

    my $Value = $Param{Value}->[0] || q{};

    if ( $Value ) {

        my $Str = $Param{Quotes}->{SQL}
            . $Value
            . $Param{Quotes}->{SQL};

        if ( $Param{CaseSensitive} ) {
            return "LOWER($Param{Column}) = LOWER($Str)";
        }
        else {
            return "$Param{Column} = $Str";
        }
    }

    return "$Param{Column} IS NULL";
}

sub _OperationNE {
    my ( $Self, %Param ) = @_;

    my $Value = $Param{Value}->[0] || q{};

    if ( $Value ) {

        my $Str = $Param{Quotes}->{SQL}
            . $Value
            . $Param{Quotes}->{SQL};

        if ( $Param{CaseSensitive} ) {
            return "LOWER($Param{Column}) != LOWER($Str)";
        }
        elsif (
            defined $Param{Type}
            && $Param{Type} eq 'NUMERIC'
        ) {
            return "$Param{Column} <> $Str";
        }
        else {
            return "$Param{Column} != $Str";
        }

    }

    return "$Param{Column} IS NOT NULL";
}

sub _OperationSTARTSWITH {
    my ( $Self, %Param ) = @_;

    my $Column = $Param{Column};
    my $Value  = $Param{Value};

    if ( scalar(@{$Value}) ) {

        my @SQL;
        for my $Val ( @{$Value}) {
            my $Str = $Param{Quotes}->{SQL}
                . $Val
                . $Param{Quotes}->{SQL};

            if ( $Param{Prepare} ) {
                my ($Col, $PreVal) = $Self->PrepareFieldAndValue(
                    Field          => $Column,
                    Value          => $Val . q{%},
                    IsStaticSearch => $Param{IsStaticSearch}
                );
                push(
                    @SQL,
                    "$Col LIKE $PreVal"
                );
            }

            elsif ( $Param{CaseSensitive} ) {
                push(
                    @SQL,
                    "LOWER($Column) LIKE LOWER('$Val%')"
                );
            }
            else {
                push(
                    @SQL,
                    "$Column LIKE '$Val%'"
                );
            }
        }

        my $Statement = join(q{ OR }, (@SQL || () ) );
        if ( $Statement ) {
            return $Self->_MaskStatement(
                Count     => scalar(@SQL),
                Statement => $Statement
            );
        }
    }

    return '1=0';
}

sub _OperationENDSWITH {
    my ( $Self, %Param ) = @_;

    my $Column = $Param{Column};
    my $Value  = $Param{Value};

    if ( scalar(@{$Value}) ) {

        my @SQL;
        for my $Val ( @{$Value}) {
            my $Str = $Param{Quotes}->{SQL}
                . $Val
                . $Param{Quotes}->{SQL};

            if ( $Param{Prepare} ) {
                my ($Col, $PreVal) = $Self->PrepareFieldAndValue(
                    Field          => $Column,
                    Value          => q{%} . $Val,
                    IsStaticSearch => $Param{IsStaticSearch}
                );
                push(
                    @SQL,
                    "$Col LIKE $PreVal"
                );
            }

            elsif ( $Param{CaseSensitive} ) {
                push(
                    @SQL,
                    "LOWER($Column) LIKE LOWER('%$Val')"
                );
            }
            else {
                push(
                    @SQL,
                    "$Column LIKE '%$Val'"
                );
            }
        }

        my $Statement = join(q{ OR }, (@SQL || () ) );
        if ( $Statement ) {
            return $Self->_MaskStatement(
                Count     => scalar(@SQL),
                Statement => $Statement
            );
        }
    }

    return '1=0';
}

sub _OperationCONTAINS {
    my ( $Self, %Param ) = @_;

    my $Column = $Param{Column};
    my $Value  = $Param{Value};

    if ( scalar(@{$Value}) ) {

        my @SQL;
        for my $Val ( @{$Value}) {
            my $Str = $Param{Quotes}->{SQL}
                . $Val
                . $Param{Quotes}->{SQL};

            if ( $Param{Prepare} ) {
                my ($Col, $PreVal) = $Self->PrepareFieldAndValue(
                    Field          => $Column,
                    Value          => q{%} . $Val . q{%},
                    IsStaticSearch => $Param{IsStaticSearch}
                );
                push(
                    @SQL,
                    "$Col LIKE $PreVal"
                );
            }

            elsif ( $Param{CaseSensitive} ) {
                push(
                    @SQL,
                    "LOWER($Column) LIKE LOWER('%$Val%')"
                );
            }
            else {
                push(
                    @SQL,
                    "$Column LIKE '%$Val%'"
                );
            }
        }

        my $Statement = join(q{ OR }, (@SQL || () ) );
        if ( $Statement ) {
            return $Self->_MaskStatement(
                Count     => scalar(@SQL),
                Statement => $Statement
            );
        }
    }

    return '1=0';
}

sub _OperationLIKE {
    my ( $Self, %Param ) = @_;

    my $Column = $Param{Column};
    my $Value  = $Param{Value};

    if ( scalar(@{$Value}) ) {

        my @SQL;
        for my $Val ( @{$Value}) {
            $Val =~ s/[*]/%/gms;

            my $Str = $Param{Quotes}->{SQL}
                . $Val
                . $Param{Quotes}->{SQL};

            if ( $Param{Prepare} ) {
                my ($Col, $PreVal) = $Self->PrepareFieldAndValue(
                    Field          => $Column,
                    Value          => $Val,
                    IsStaticSearch => $Param{IsStaticSearch}
                );
                push(
                    @SQL,
                    "$Col LIKE $PreVal"
                );
            }

            elsif ( $Param{CaseSensitive} ) {
                push(
                    @SQL,
                    "LOWER($Column) LIKE LOWER('$Val')"
                );
            }
            elsif ( $Param{LikeEscapeString} ) {
                my $LikeEscapeString = $Kernel::OM->Get('DB')->GetDatabaseFunction('LikeEscapeString');
                $Val = $Kernel::OM->Get('DB')->Quote( $Val, 'Like' );

                push(
                    @SQL,
                    "$Column LIKE '" . $Val ."' $LikeEscapeString"
                );
            }
            else {
                push(
                    @SQL,
                    "$Column LIKE '$Val'"
                );
            }
        }

        my $Statement = join(q{ OR }, (@SQL || () ) );
        if ( $Statement ) {
            return $Self->_MaskStatement(
                Count     => scalar(@SQL),
                Statement => $Statement
            );
        }
    }

    return '1=0';
}

sub _OperationIN {
    my ( $Self, %Param ) = @_;

    if (IsArrayRefWithData($Param{Value})) {

        my $Value = $Param{Quotes}->{SQL}
            . join($Param{Quotes}->{Join}, @{$Param{Value}})
            . $Param{Quotes}->{SQL};

        return "$Param{Column} IN ($Value)";
    }

    return '1=0' ;

}

sub _OperationNOTIN {
    my ( $Self, %Param ) = @_;

    if (IsArrayRefWithData($Param{Value})) {

        my $Value = $Param{Quotes}->{SQL}
            . join($Param{Quotes}->{Join}, @{$Param{Value}})
            . $Param{Quotes}->{SQL};

        return "$Param{Column} NOT IN ($Value)";
    }

    return '1=1' ;
}

sub _OperationLT {
    my ( $Self, %Param ) = @_;

    if ( scalar(@{$Param{Value}}) ) {

        my @SQL;
        for my $Value ( @{$Param{Value}}) {
            $Value = $Param{Quotes}->{SQL}
                . $Value
                . $Param{Quotes}->{SQL};

            push(
                @SQL,
                "$Param{Column} < $Value"
            );
        }

        my $Statement = join(q{ OR }, (@SQL || () ) );
        if ( $Statement ) {
            return $Self->_MaskStatement(
                Count     => scalar(@SQL),
                Statement => $Statement
            );
        }
    }

    return "$Param{Column} IS NOT NULL";
}

sub _OperationLTE {
    my ( $Self, %Param ) = @_;

    if ( scalar(@{$Param{Value}}) ) {

        my @SQL;
        for my $Value ( @{$Param{Value}}) {
            $Value = $Param{Quotes}->{SQL}
                . $Value
                . $Param{Quotes}->{SQL};

            push(
                @SQL,
                "$Param{Column} <= $Value"
            );
        }

        my $Statement = join(q{ OR }, (@SQL || () ) );
        if ( $Statement ) {
            return $Self->_MaskStatement(
                Count     => scalar(@SQL),
                Statement => $Statement
            );
        }
    }

    return "$Param{Column} IS NOT NULL";
}

sub _OperationGT {
    my ( $Self, %Param ) = @_;

    if ( scalar(@{$Param{Value}}) ) {

        my @SQL;
        for my $Value ( @{$Param{Value}}) {
            $Value = $Param{Quotes}->{SQL}
                . $Value
                . $Param{Quotes}->{SQL};

            push(
                @SQL,
                "$Param{Column} > $Value"
            );
        }

        my $Statement = join(q{ OR }, (@SQL || () ) );
        if ( $Statement ) {
            return $Self->_MaskStatement(
                Count     => scalar(@SQL),
                Statement => $Statement
            );
        }
    }

    return "$Param{Column} IS NOT NULL";
}

sub _OperationGTE {
    my ( $Self, %Param ) = @_;

    if ( scalar(@{$Param{Value}}) ) {

        my @SQL;
        for my $Value ( @{$Param{Value}}) {
            $Value = $Param{Quotes}->{SQL}
                . $Value
                . $Param{Quotes}->{SQL};

            push(
                @SQL,
                "$Param{Column} => $Value"
            );
        }

        my $Statement = join(q{ OR }, (@SQL || () ) );
        if ( $Statement ) {
            return $Self->_MaskStatement(
                Count     => scalar(@SQL),
                Statement => $Statement
            );
        }
    }

    return "$Param{Column} IS NOT NULL";
}

sub _GetQuotes {
    my ($Self, %Param) = @_;

    if (
        defined $Param{Type}
        && $Param{Type} eq 'NUMERIC'
    ) {
        return {
            SQL  => q{},
            Join => q{,}
        };
    }

    return {
        SQL  => q{'},
        Join => q{','}
    };
}

sub _MaskStatement {
    my ($Self, %Param) = @_;

    my $Statement = $Param{Statement};
    # Adds additional SQL clauses to the statement
    if (
        $Statement
        && $Param{Count} > 1
    ) {
        $Statement = q{(}
            . $Statement
            . q{)};
    }

    return $Statement;
}

sub _SetSupplement {
    my ($Self, %Param) = @_;

    my $Statement = $Param{Statement};
    # Adds additional SQL clauses to the statement
    if (
        $Statement
        && IsArrayRefWithData($Param{Supplement})
    ) {
        $Statement = q{( }
            . $Statement
            . q{ }
            . join( q{ }, @{$Param{Supplement}})
            . q{ )};
    }

    return $Statement;
}

sub _CheckSearchParams {
    my ($Self, %Param) = @_;

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

    if (
        !defined( $Self->{Supported}->{$Param{Search}->{Field}} )
        || !$Self->{Supported}->{$Param{Search}->{Field}}->{IsSearchable}
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Invalid search field "' . $Param{Search}->{Field} . q{"!},
            );
        }
        return;
    }

    return 1;
}

sub _CheckSortParams {
    my ($Self, %Param) = @_;

    if ( !defined( $Param{Attribute} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Need Attribute!',
            );
        }
        return;
    }

    if (
        !defined( $Self->{Supported}->{ $Param{Attribute} } )
        || !$Self->{Supported}->{ $Param{Attribute} }->{IsSortable}
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Invalid sort attribute "' . $Param{Attribute} . q{"!},
            );
        }
        return;
    }

    return 1;
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
