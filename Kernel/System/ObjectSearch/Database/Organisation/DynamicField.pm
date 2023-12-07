# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Organisation::DynamicField;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::Common
);

our @ObjectDependencies = (
    'Config',
    'Log',
    'DynamicField',
    'DynamicField::Backend',
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::DynamicField - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Property => {
            IsSortable     => 0|1,
            IsSearchable => 0|1,
            Operators     => []
        },
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    # get all valid dynamic fields for object type ticket
    my $DynamicFieldList = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
        ObjectType => 'Organisation',
        Valid      => 1
    );

    # process fields
    for my $DynamicFieldConfig ( @{ $DynamicFieldList } ) {
        my $DFName = 'DynamicField_' . $DynamicFieldConfig->{Name};

        my $IsSearchable = $Kernel::OM->Get('DynamicField::Backend')->GetProperty(
            DynamicFieldConfig => $DynamicFieldConfig,
            Property           => 'IsSearchable'
        );
        my $Operators = [];
        my $ValueType = q{};
        if ( $IsSearchable ) {
            $Operators = $Kernel::OM->Get('DynamicField::Backend')->GetProperty(
                DynamicFieldConfig => $DynamicFieldConfig,
                Property           => 'SearchOperators'
            );
            $ValueType = $Kernel::OM->Get('DynamicField::Backend')->GetProperty(
                DynamicFieldConfig => $DynamicFieldConfig,
                Property           => 'SearchValueType'
            );
        }
        my $IsSortable = $Kernel::OM->Get('DynamicField::Backend')->GetProperty(
            DynamicFieldConfig => $DynamicFieldConfig,
            Property           => 'IsSortable'
        );

        $Self->{Supported}->{ $DFName } = {
            Operators    => $Operators    || [],
            IsSearchable => $IsSearchable || 0,
            IsSortable   => $IsSortable   || 0,
            ValueType    => $ValueType    || q{}
        };
    }

    return $Self->{Supported};
}


=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        BoolOperator => 'AND' | 'OR',
        Search       => {}
    );

    $Result = {
        Join    => [ ],
        Where   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my @SQLJoin;
    my @SQLWhere;

    # check params
    if ( !$Param{Search} ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    # validate operator
    my %OperatorMap = (
        'EQ'         => 'Equals',
        'LIKE'       => 'Like',
        'GT'         => 'GreaterThan',
        'GTE'        => 'GreaterThanEquals',
        'LT'         => 'SmallerThan',
        'LTE'        => 'SmallerThanEquals',
        'IN'         => 'Like',
        'CONTAINS'   => 'Like',
        'STARTSWITH' => 'StartsWith',
        'ENDSWITH'   => 'EndsWith',
    );
    if ( !$OperatorMap{$Param{Search}->{Operator}} ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unsupported Operator $Param{Search}->{Operator}!",
        );
        return;
    }

    if ( !$Self->{DynamicFields} ) {

        # get dynamic field object
        my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');

        # get all configured dynamic fields
        my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet();
        if ( !IsArrayRefWithData($DynamicFieldList) ) {
            # we don't have any  DFs
            return {
                Join  => [],
                Where => [],
            };
        }
        $Self->{DynamicFields} = { map { $_->{Name} => $_ } @{$DynamicFieldList} };
    }

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

    my $DFName = $Param{Search}->{Field};
    $DFName =~ s/DynamicField_//g;

    my $DynamicFieldConfig = $Self->{DynamicFields}->{$DFName};

    if ( !IsHashRefWithData($DynamicFieldConfig) ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "DynamicField '$DFName' doesn't exist or is disabled. Ignoring it.",
        );
        # return empty result
        return {
            Join  => [],
            Where => [],
        };
    }

    my $Value = $Param{Search}->{Value};
    if ( !IsArrayRefWithData($Value) ) {
        $Value = [ $Value ];
    }
    foreach my $ValueItem ( @{$Value} ) {
        $Value =~ s/\*/%/g;
    }

    # increase count
    my $Count = $Param{Flags}->{DynamicFieldJoinCounter}++;

    # join tables
    my $JoinTable = "dfv$Count";
    $Param{Flags}->{DynamicFieldJoin}->{$DFName} = $JoinTable;

    if ( $Param{BoolOperator} eq 'OR') {
        push(
            @SQLJoin,
            <<"END"
LEFT JOIN dynamic_field_value $JoinTable ON o.id = $JoinTable.object_id
    AND $JoinTable.field_id = $DynamicFieldConfig->{ID}
END
        );
    } else {
        push(
            @SQLJoin,
            <<"END"
INNER JOIN dynamic_field_value $JoinTable ON o.id = $JoinTable.object_id
    AND $JoinTable.field_id = $DynamicFieldConfig->{ID}
END
        );
    }

    my $DynamicFieldSQL;
    foreach my $ValueItem ( @{$Value} ) {
        # validate data type
        my $ValidateSuccess = $DynamicFieldBackendObject->ValueValidate(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $ValueItem,
            SearchValidation   => 1,
            UserID             => 1,
            Silent             => $Param{Silent} || 0
        );
        if ( !$ValidateSuccess ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  =>
                    "Search not executed due to invalid value '"
                    . $ValueItem
                    . "' on field '"
                    . $DFName
                    . q{'!},
            );
            return;
        }

        # get field specific SQL
        my $SQL = $DynamicFieldBackendObject->SearchSQLGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            TableAlias         => $JoinTable,
            Operator           => $OperatorMap{$Param{Search}->{Operator}},
            SearchTerm         => $ValueItem,
            Silent             => $Param{Silent} || 0
        );

        if ( $DynamicFieldSQL ) {
            $DynamicFieldSQL .= " OR ";
        }
        $DynamicFieldSQL .= "($SQL)";
    }

    # add field specific SQL
    push( @SQLWhere, "($DynamicFieldSQL)" );

    return {
        Join  => \@SQLJoin,
        Where => \@SQLWhere,
    };
}

=item Sort()

run this module and return the SQL extensions

    my $Result = $Object->Sort(
        Attribute => '...'      # required
    );

    $Result = {
        Select   => [ ],          # optional
        From    => [ ],          # optional
        OrderBy => [ ]           # optional
    };

=cut

sub Sort {
    my ( $Self, %Param ) = @_;
    my @SQLJoin;

    # check params
    return if ( !$Self->_CheckSortParams(%Param) );

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

    if ( !$Self->{DynamicFields} ) {

        # get all configured dynamic fields
        my $DynamicFieldList = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet();
        if ( !IsArrayRefWithData($DynamicFieldList) ) {
            # we don't have any  DFs
            return {
                Join  => [],
                Where => [],
            };
        }
        $Self->{DynamicFields} = { map { $_->{Name} => $_ } @{$DynamicFieldList} };
    }

    my $DFName = $Param{Attribute};
    $DFName =~ s/DynamicField_//g;

    my $DynamicFieldConfig = $Self->{DynamicFields}->{$DFName};

    # join tables
    my $JoinTable = $Param{Flags}->{DynamicFieldJoin}->{$DFName};
    if ( !$JoinTable ) {
        # increase count
        my $Count = $Param{Flags}->{DynamicFieldJoinCounter}++;

        $JoinTable = "dfv$Count";
        push(
            @SQLJoin,
            <<"END"
LEFT OUTER JOIN dynamic_field_value $JoinTable ON o.id = $JoinTable.object_id
AND $JoinTable.field_id = $DynamicFieldConfig->{ID}
AND $JoinTable.first_value = 1
END
        );
    }

    # get field specific SQL
    my $SQLOrderField = $DynamicFieldBackendObject->SearchSQLOrderFieldGet(
        DynamicFieldConfig => $DynamicFieldConfig,
        TableAlias         => $JoinTable,
    );

    return {
        Join  => \@SQLJoin,
        Select => [
            $SQLOrderField,
        ],
        OrderBy => [
            $SQLOrderField
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
