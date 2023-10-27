# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::DynamicField;

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
        Search => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    # NOTE: The supported operators come from the dynamic field types
    my %TypeOperators = (
        'Text'                    => ['EQ','GT','GTE','LT','LTE','LIKE','STARTWITH','ENDWITH'],
        'TextArea'                => ['EQ','GT','GTE','LT','LTE','LIKE','STARTWITH','ENDWITH'],
        'CheckList'               => ['EQ','GT','GTE','LT','LTE','LIKE','STARTWITH','ENDWITH'],
        'Table'                   => ['EQ','GT','GTE','LT','LTE','LIKE'],
        'Date'                    => ['EQ','GT','GTE','LT','LTE'],
        'DateTime'                => ['EQ','GT','GTE','LT','LTE'],
        'Multiselect'             => ['EQ','GT','GTE','LT','LTE','LIKE'],
        'TicketReference'         => ['EQ','GT','GTE','LT','LTE','LIKE'],
        'ITSMConfigItemReference' => ['EQ','GT','GTE','LT','LTE','LIKE'],
        'ContactReference'        => ['EQ','GT','GTE','LT','LTE','LIKE'],
        'OrganisationReference'   => ['EQ','GT','GTE','LT','LTE','LIKE'],
    );

    for my $Type ( qw(Search Sort) ) {
        my $Name = "Supported$Type";

        my $List = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
            Valid      => 1,
            ObjectType => 'Ticket',
            FieldType => [
                'Text', 'Textarea', 'Date', 'DateTime','Multiselect'
            ],
            ResultType => $Type eq 'Search' ? 'HASH' : 'ARRAY',
            IsSortable => $Type eq 'Sort' ? 1 : 0,
        );

        for my $Field ( @{$List} ) {
            my $DFName = "DynamicField_$Field->{Name}";
            if ( $Type eq 'Search' ) {
                $Self->{$Name}->{$DFName} = $TypeOperators{$Field->{FieldType}};
            }
            else {
                push ( @{$Self->{$Name}}, $DFName );
            }
        }
    }

    return {
        Search => $Self->{SupportedSearch},
        Sort   => $Self->{SupportedSort},
    };
}


=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        BoolOperator => 'AND' | 'OR',
        Search       => {}
    );

    $Result = {
        SQLJoin    => [ ],
        SQLWhere   => [ ],
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
                SQLJoin  => [],
                SQLWhere => [],
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
            SQLJoin  => [],
            SQLWhere => [],
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
    my $Count = $Self->{ModuleData}->{JoinCounter}++;

    # join tables
    my $JoinTable = "dfv$Count";
    $Self->{ModuleData}->{JoinTables}->{$DFName} = $JoinTable;

    if ( $DynamicFieldConfig->{ObjectType} eq 'Ticket' ) {
        if ( $Param{BoolOperator} eq 'OR') {
            push(
                @SQLJoin,
                <<"END"
LEFT JOIN dynamic_field_value $JoinTable ON st.id = $JoinTable.object_id
    AND $JoinTable.field_id = $DynamicFieldConfig->{ID}
END
            );
        } else {
            push(
                @SQLJoin,
                <<"END"
INNER JOIN dynamic_field_value $JoinTable ON st.id = $JoinTable.object_id
    AND $JoinTable.field_id = $DynamicFieldConfig->{ID}
END
            );
        }
    }
    elsif ( $DynamicFieldConfig->{ObjectType} eq 'Article' ) {
        if ( $Param{BoolOperator} eq 'OR') {
            if ( !$Self->{ModuleData}->{ArticleTableJoined} ) {
                push( @SQLJoin, "LEFT OUTER JOIN article artdfjoin_left ON st.id = artdfjoin_left.ticket_id");
                # FIXME: maybe unnecessary?
                push( @SQLJoin, "RIGHT OUTER JOIN article artdfjoin_right ON st.id = artdfjoin_right.ticket_id");
                $Self->{ModuleData}->{ArticleTableJoined} = 1;
            }
            # FIXME: maybe LEFT JOIN necessary?
            push(
                @SQLJoin,
                <<"END"
INNER JOIN dynamic_field_value $JoinTable ON (
    artdfjoin_left.id = $JoinTable.object_id
        OR artdfjoin_right.id = $JoinTable.object_id
    ) AND $JoinTable.field_id = $DynamicFieldConfig->{ID}
END
            );
        } else {
            if ( !$Self->{ModuleData}->{ArticleTableJoined} ) {
                push( @SQLJoin, "INNER JOIN article artdfjoin ON st.id = artdfjoin.ticket_id");
                $Self->{ModuleData}->{ArticleTableJoined} = 1;
            }
            push(
                @SQLJoin,
                <<"END"
INNER JOIN dynamic_field_value $JoinTable ON artdfjoin.id) = $JoinTable.object_id
    AND $JoinTable.field_id = $DynamicFieldConfig->{ID}
END
            );
        }
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
        SQLJoin  => \@SQLJoin,
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
        SQLFrom    => [ ],          # optional
        SQLOrderBy => [ ]           # optional
    };

=cut

sub Sort {
    my ( $Self, %Param ) = @_;
    my @SQLJoin;

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

    if ( !$Self->{DynamicFields} ) {

        # get all configured dynamic fields
        my $DynamicFieldList = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet();
        if ( !IsArrayRefWithData($DynamicFieldList) ) {
            # we don't have any  DFs
            return {
                SQLJoin  => [],
                SQLWhere => [],
            };
        }
        $Self->{DynamicFields} = { map { $_->{Name} => $_ } @{$DynamicFieldList} };
    }

    my $DFName = $Param{Attribute};
    $DFName =~ s/DynamicField_//g;

    my $DynamicFieldConfig = $Self->{DynamicFields}->{$DFName};

    # increase count
    my $Count = $Self->{ModuleData}->{SortJoinCounter}++;

    # join tables
    my $JoinTable = $Self->{ModuleData}->{JoinTables}->{$DFName};
    if ( !$JoinTable ) {
        $JoinTable = "dfvsort$Count";
        if ( $DynamicFieldConfig->{ObjectType} eq 'Ticket' ) {
            push(
                @SQLJoin,
                <<"END"
LEFT OUTER JOIN dynamic_field_value $JoinTable ON st.id = $JoinTable.object_id
    AND $JoinTable.field_id = $DynamicFieldConfig->{ID}
    AND $JoinTable.first_value = 1
END
            );
        }
        elsif ( $DynamicFieldConfig->{ObjectType} eq 'Article' ) {
            if ( !$Self->{ModuleData}->{ArticleTableJoined} ) {
                push( @SQLJoin, "INNER JOIN article artdfjoin ON st.id = artdfjoin.ticket_id");
                $Self->{ModuleData}->{ArticleTableJoined} = 1;
            }
            push(
                @SQLJoin,
                <<"END"
LEFT OUTER JOIN dynamic_field_value $JoinTable ON artdfjoin.id =$JoinTable.object_id
    AND $JoinTable.field_id = $DynamicFieldConfig->{ID}
    AND $JoinTable.first_value = 1
END
            );
        }
    }

    # get field specific SQL
    my $SQLOrderField = $DynamicFieldBackendObject->SearchSQLOrderFieldGet(
        DynamicFieldConfig => $DynamicFieldConfig,
        TableAlias         => $JoinTable,
    );

    return {
        SQLJoin  => \@SQLJoin,
        SQLAttrs => [
            $SQLOrderField,
        ],
        SQLOrderBy => [
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
