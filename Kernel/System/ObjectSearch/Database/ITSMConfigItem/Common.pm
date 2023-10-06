# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::ITSMConfigItem::Common;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    DB
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::ITSMConfigItem::Common - base attribute module for object search

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
        Search => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Search => [],
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

sub _PrepareFieldAndValue {
    my ( $Self, %Param ) = @_;

    my $Field = $Param{Field};
    my $Value = $Param{Value};

    # check if database supports LIKE in large text types
    if ( $Self->{DBObject}->GetDatabaseFunction('CaseSensitive') ) {
        if ( $Self->{DBObject}->GetDatabaseFunction('LcaseLikeInLargeText') ) {
            $Field = "LCASE(ci.name)";
            $Value = "LCASE('$Value')";
        }
        else {
            $Field = "LOWER(ci.name)";
            $Value = "LOWER('$Value')";
        }
    }
    else {
        $Value = "'$Value'";
    }

    return ($Field, $Value);
}

sub GetOperation {
    my ( $Self, %Param ) = @_;

    my %Operators = (
        'EQ'         => 1,
        'NE'         => 1,
        'STARTSWITH' => 1,
        'ENDSWITH'   => 1,
        'CONTAINS'   => 1,
        'LIKE'       => 1,
        'IN'         => 1,
        'LT'         => 1,
        'GT'         => 1,
        'LTE'        => 1,
        'GTE'        => 1,
    );

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

    my $Function = "_Operation$Param{Operator}";

    return $Self->$Function(
        %Param
    );
}

sub _OperationEQ {
    my ( $Self, %Param ) = @_;

    if ( $Param{Value} ) {

        if ( $Param{CaseSensitive} ) {
            return "LOWER($Param{Column}) = LOWER('$Param{Value}')";
        }

        return "$Param{Column} = '$Param{Value}'";
    } else {
        return "$Param{Column} IS NULL";
    }
}

sub _OperationNE {
    my ( $Self, %Param ) = @_;

    if ( $Param{Value} ) {

        if ( $Param{CaseSensitive} ) {
            return "LOWER($Param{Column}) != LOWER('$Param{Value}')";
        }

        return "$Param{Column} != '$Param{Value}'";
    } else {
        return "$Param{Column} IS NOT NULL";
    }
}

sub _OperationSTARTWITH {
    my ( $Self, %Param ) = @_;

    if ( $Param{CaseSensitive} ) {
        return "LOWER($Param{Column}) LIKE LOWER('$Param{Value}%')";
    }

    return "$Param{Column} LIKE '$Param{Value}%'";
}

sub _OperationENDSWITH {
    my ( $Self, %Param ) = @_;

    if ( $Param{CaseSensitive} ) {
        return "LOWER($Param{Column}) LIKE LOWER('%$Param{Value}')";
    }

    return "$Param{Column} LIKE '%$Param{Value}'";
}

sub _OperationCONTAINS {
    my ( $Self, %Param ) = @_;

    if ( $Param{CaseSensitive} ) {
        return "LOWER($Param{Column}) LIKE LOWER('%$Param{Value}%')";
    }

    return "$Param{Column} LIKE '%$Param{Value}%'";
}

sub _OperationLIKE {
    my ( $Self, %Param ) = @_;

    my $Value = $Param{Value};
    $Value =~ s/[*]/%/gms;

    if ( $Param{CaseSensitive} ) {
        return "LOWER($Param{Column}) LIKE LOWER('$Value')";
    }

    return "$Param{Column} LIKE '$Value'";
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

sub _OperationLT {
    my ( $Self, %Param ) = @_;

    return "$Param{Column} < '$Param{Value}'";
}

sub _OperationLTE {
    my ( $Self, %Param ) = @_;

    return "$Param{Column} <= '$Param{Value}'";
}

sub _OperationGT {
    my ( $Self, %Param ) = @_;

    return "$Param{Column} > '$Param{Value}'";

}

sub _OperationGTE {
    my ( $Self, %Param ) = @_;

    return "$Param{Column} >= '$Param{Value}'";
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
