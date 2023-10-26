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

our @ObjectDependencies = qw(
    DB
    Log
);

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

    $Self->{DBObject} = $Kernel::OM->Get('DB');

    return $Self;
}

=item Init()

empty method to be overridden by specific attribute module if necessary

    $Object->Init();

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    # reset module data
    $Self->{ModuleData} = {};

    return;
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

    return {
        Search => {},
        Sort   => []
    };
}

=item Search()

empty method to be overridden by specific attribute module

    my $Result = $Object->Search(
        Search => {}
    );

    $Result = {
        SQLAttrs   => [ ],          # optional
        SQLFrom    => [ ],          # optional
        SQLJoin    => [ ],          # optional
        SQLWhere   => [ ],          # optional
        SQLOrderBy => [ ]           # optional
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    return;
}

=item Sort()

empty method to be overridden by specific attribute module

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

    return;
}

=begin Internal:

=cut


sub PrepareFieldAndValue {
    my ( $Self, %Param ) = @_;

    my $Field = $Param{Field};
    my $Value = $Param{Value};

    # check if database supports LIKE in large text types
    if ( $Self->{DBObject}->GetDatabaseFunction('CaseSensitive') ) {
        if ( $Self->{DBObject}->GetDatabaseFunction('LcaseLikeInLargeText') ) {
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
        Column        => 'st.title'         # (required) - table column for statement
                                            #              can be given as string or array ref
        Value         => '123'              # (optional) - table column value for statement
                                            #              can be given as string or array ref
        Supplement    => []                 # (optional) - an array ref of additional statements that will be add to the generated statement
        Operator      => '!IN',             # (required) - operation for the statement
        CaseSensitive =>  0,                # (optional) - (1|0) enables the case sensitive, not related to "Prepare"
        Prepare       => 1,                 # (optional) - (1|0) enables the preparation of string values
        Supported     => [LT,NE,EQ]         # (required) - list of supported operations of the object attributes
    );

Returns array ref of statements.

    $Statements = [
        'column LIKE \'value%\'',
        ...
    ];

=cut

sub GetOperation {
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
            if ( !$Operators{$Operator} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unsupported Operator $Param{Operator}!",
                );
                return;
            }
            $Operators{$Operator} = 1;
        }
    }

    return if !%Operators;

    if ( !$Operators{$Param{Operator}} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unsupported Operator $Param{Operator}!",
        );
        return;
    }

    if ( !$Param{Column} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No given column!",
        );
        return;
    }

    my @Columns;
    my $OneColumn = 1;
    if ( ref $Param{Column} ne 'ARRAY' ) {
        push( @Columns, $Param{Column} );
    }
    else {
        @Columns   = @{$Param{Column}};
        $OneColumn = 0 if ( scalar(@Columns) > 1 );
    }

    my @Values;
    my $FirstValue = 1;
    if ( ref $Param{Value} ne 'ARRAY' ) {
        push( @Values, $Param{Value} );
    }
    else {
        @Values     = @{$Param{Value}};
        $FirstValue = 0 if ( scalar(@Values) > 1 );
    }

    my $Function = "_Operation$Param{Operator}";

    my @Statements;
    for my $Index ( keys @Columns ) {

        my $Value;
        if ( $OneColumn ) {
            $Value = \@Values;
        }
        elsif ( $FirstValue ){
            $Value = $Values[0];
        }
        else {
            $Value = $Values[$Index];
        }

        my $Statement = $Self->$Function(
            %Param,
            Value  => $Value,
            Column => $Columns[$Index]
        );

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
        push( @Statements, $Statement);
    }

    return \@Statements;
}

sub _OperationEQ {
    my ( $Self, %Param ) = @_;

    my $Value = $Param{Value};

    if (IsArrayRefWithData($Value)) {
        $Value = $Value->[0];
    }

    if ( $Value ) {

        if ( $Param{CaseSensitive} ) {
            return "LOWER($Param{Column}) = LOWER('$Value')";
        }

        return "$Param{Column} = '$Value'";
    } else {
        return "$Param{Column} IS NULL";
    }
}

sub _OperationNE {
    my ( $Self, %Param ) = @_;

    my $Value = $Param{Value};

    if (IsArrayRefWithData($Value)) {
        $Value = $Value->[0];
    }

    if ( $Value ) {

        if ( $Param{CaseSensitive} ) {
            return "LOWER($Param{Column}) != LOWER('$Value')";
        }

        return "$Param{Column} != '$Value'";
    } else {
        return "$Param{Column} IS NOT NULL";
    }
}

sub _OperationSTARTWITH {
    my ( $Self, %Param ) = @_;

    my $Column = $Param{Column};
    my $Value = $Param{Value};

    if (IsArrayRefWithData($Value)) {
        $Value = $Value->[0];
    }

    if ( $Param{Prepare} ) {
        ($Column, $Value) = $Self->PrepareFieldAndValue(
            Field          => $Column,
            Value          => $Value . q{%},
            IsStaticSearch => $Param{IsStaticSearch}
        );
        return "$Column LIKE $Value";
    }

    elsif ( $Param{CaseSensitive} ) {
        return "LOWER($Column) LIKE LOWER('$Value%')";
    }

    return "$Column LIKE '$Value%'";
}

sub _OperationENDSWITH {
    my ( $Self, %Param ) = @_;

    my $Column = $Param{Column};
    my $Value = $Param{Value};

    if (IsArrayRefWithData($Value)) {
        $Value = $Value->[0];
    }

    if ( $Param{Prepare} ) {
        ($Column, $Value) = $Self->PrepareFieldAndValue(
            Field          => $Column,
            Value          => q{%} . $Value,
            IsStaticSearch => $Param{IsStaticSearch}
        );
        return "$Column LIKE $Value";
    }

    elsif ( $Param{CaseSensitive} ) {
        return "LOWER($Column) LIKE LOWER('%$Value')";
    }

    return "$Column LIKE '%$Value'";
}

sub _OperationCONTAINS {
    my ( $Self, %Param ) = @_;

    my $Column = $Param{Column};
    my $Value  = $Param{Value};

    if (IsArrayRefWithData($Value)) {
        $Value = $Value->[0];
    }

    if ( $Param{Prepare} ) {
        ($Column, $Value) = $Self->PrepareFieldAndValue(
            Field          => $Column,
            Value          => q{%} . $Value . q{%},
            IsStaticSearch => $Param{IsStaticSearch}
        );
        return "$Column LIKE $Value";
    }

    elsif ( $Param{CaseSensitive} ) {
        return "LOWER($Column) LIKE LOWER('%$Value%')";
    }

    return "$Column LIKE '%$Value%'";
}

sub _OperationLIKE {
    my ( $Self, %Param ) = @_;

    my $Column = $Param{Column};
    my $Value  = $Param{Value};

    if (IsArrayRefWithData($Value)) {
        $Value = $Value->[0];
    }

    $Value =~ s/[*]/%/gms;

    if ( $Param{Prepare} ) {
        ($Column, $Value) = $Self->PrepareFieldAndValue(
            Field          => $Column,
            Value          => $Value . q{%},
            IsStaticSearch => $Param{IsStaticSearch}
        );
        return "$Column LIKE $Value";
    }

    elsif ( $Param{CaseSensitive} ) {
        return "LOWER($Column) LIKE LOWER('$Value')";
    }

    return "$Column LIKE '$Value'";
}

sub _OperationIN {
    my ( $Self, %Param ) = @_;

    if (IsArrayRefWithData($Param{Value})) {

        my $Value = join(q{','}, @{$Param{Value}});

        return "$Param{Column} IN ('$Value')";
    }
    else {
        return '1=0' ;
    }
}

sub _OperationNOTIN {
    my ( $Self, %Param ) = @_;

    if (IsArrayRefWithData($Param{Value})) {

        my $Value = join(q{','}, @{$Param{Value}});

        return "$Param{Column} NOT IN ('$Value')";
    }
    else {
        return '1=0' ;
    }
}

sub _OperationLT {
    my ( $Self, %Param ) = @_;

    my $Value = $Param{Value};

    if (IsArrayRefWithData($Value)) {
        $Value = $Value->[0];
    }

    if ( $Value ) {
        return "$Param{Column} < '$Value'";
    } else {
        return "$Param{Column} IS NOT NULL";
    }
}

sub _OperationLTE {
    my ( $Self, %Param ) = @_;

    my $Value = $Param{Value};

    if (IsArrayRefWithData($Value)) {
        $Value = $Value->[0];
    }

    if ( $Value ) {
        return "$Param{Column} <= '$Value'";
    } else {
        return "$Param{Column} IS NOT NULL";
    }
}

sub _OperationGT {
    my ( $Self, %Param ) = @_;

    my $Value = $Param{Value};

    if (IsArrayRefWithData($Value)) {
        $Value = $Value->[0];
    }

    if ( $Value ) {
        return "$Param{Column} > '$Value'";
    } else {
        return "$Param{Column} IS NOT NULL";
    }
}

sub _OperationGTE {
    my ( $Self, %Param ) = @_;

    my $Value = $Param{Value};

    if (IsArrayRefWithData($Value)) {
        $Value = $Value->[0];
    }

    if ( $Value ) {
        return "$Param{Column} >= '$Value'";
    } else {
        return "$Param{Column} IS NOT NULL";
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
