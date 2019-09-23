# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::DynamicField;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Ticket::TicketSearch::Database::Common
);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Ticket::TicketSearch::Database::DynamicField - attribute module for database ticket search

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
        Search => [ 'DynamicField_\w+' ],
        Sort   => [ 'DynamicField_\w+' ]
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    # validate operator
    my %OperatorMap = (
        'EQ'    => 'Equals',
        'LIKE'  => 'Like',
        'GT'    => 'GreaterThan',
        'GTE'   => 'GreaterThanEquals',
        'LT'    => 'SmallerThan',
        'LTE'   => 'SmallerThanEquals',
        'IN'    => 'Like'
    );
    if ( !$OperatorMap{$Param{Search}->{Operator}} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unsupported Operator $Param{Search}->{Operator}!",
        );
        return;
    }

    if ( !$Self->{DynamicFields} ) {

        # get dynamic field object
        my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

        # get all configured dynamic fields
        my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet();
        if ( !IsArrayRefWithData($DynamicFieldList) ) {
            # we don't have any DFs
            return;
        }
        $Self->{DynamicFields} = { map { $_->{Name} => $_ } @{$DynamicFieldList} };
    }

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    my $DFName = $Param{Search}->{Field};
    $DFName =~ s/DynamicField_//g;

    my $DynamicFieldConfig = $Self->{DynamicFields}->{$DFName};

    if ( !IsHashRefWithData($DynamicFieldConfig) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unknown DynamicField '$DFName'!",
        );
        return;
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

    my $DynamicFieldSQL;
    foreach my $ValueItem ( @{$Value} ) {
        # validate data type
        my $ValidateSuccess = $DynamicFieldBackendObject->ValueValidate(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $ValueItem,
            UserID             => 1,
        );
        if ( !$ValidateSuccess ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  =>
                    "Search not executed due to invalid value '"
                    . $ValueItem
                    . "' on field '"
                    . $DFName
                    . "'!",
            );
            return;
        }

        # get field specific SQL
        my $SQL = $DynamicFieldBackendObject->SearchSQLGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            TableAlias         => "dfv$Count",
            Operator           => $OperatorMap{$Param{Search}->{Operator}},
            SearchTerm         => $ValueItem,
        );

        if ( $DynamicFieldSQL ) {
            $DynamicFieldSQL .= " OR ";
        }
        $DynamicFieldSQL .= $SQL;
    }

    # join tables
    my $JoinTable = "dfv$Count";
    $Self->{ModuleData}->{JoinTables}->{$DFName} = $JoinTable;

    if ( $DynamicFieldConfig->{ObjectType} eq 'Ticket' ) {
        if ( $Param{BoolOperator} eq 'OR') {
            push( @SQLJoin, "LEFT OUTER JOIN dynamic_field_value $JoinTable\_left ON (CAST(st.id AS char(255)) = CAST($JoinTable\_left.object_id AS char(255)) AND $JoinTable\_left.field_id = " . $DynamicFieldConfig->{ID} . ") " );
            push( @SQLJoin, "RIGHT OUTER JOIN dynamic_field_value $JoinTable\_right ON (CAST(st.id AS char(255)) = CAST($JoinTable\_right.object_id AS char(255)) AND $JoinTable\_right.field_id = " . $DynamicFieldConfig->{ID} . ") " );
        } else {
            push( @SQLJoin, "INNER JOIN dynamic_field_value $JoinTable ON (CAST(st.id AS char(255)) = CAST($JoinTable.object_id AS char(255)) AND $JoinTable.field_id = " . $DynamicFieldConfig->{ID} . ") " );
        }
    } 
    elsif ( $DynamicFieldConfig->{ObjectType} eq 'Article' ) {
        if ( $Param{BoolOperator} eq 'OR') {
            if ( !$Self->{ModuleData}->{ArticleTableJoined} ) {
                push( @SQLJoin, "LEFT OUTER JOIN article artdfjoin_left ON st.id = artdfjoin_left.ticket_id");
                push( @SQLJoin, "RIGHT OUTER JOIN article artdfjoin_right ON st.id = artdfjoin_right.ticket_id");
                $Self->{ModuleData}->{ArticleTableJoined} = 1;
            }
            push( @SQLJoin, "INNER JOIN dynamic_field_value $JoinTable ON ((CAST(artdfjoin_left.id AS char(255)) = CAST($JoinTable.object_id AS char(255)) OR (CAST(artdfjoin_right.id AS char(255)) = CAST($JoinTable.object_id AS char(255))) AND $JoinTable.field_id = " . $DynamicFieldConfig->{ID} . ") " );
        } else {
            if ( !$Self->{ModuleData}->{ArticleTableJoined} ) {
                push( @SQLJoin, "INNER JOIN article artdfjoin ON st.id = artdfjoin.ticket_id");
                $Self->{ModuleData}->{ArticleTableJoined} = 1;
            }
            push( @SQLJoin, "INNER JOIN dynamic_field_value $JoinTable ON (CAST(artdfjoin.id AS char(255)) = CAST($JoinTable.object_id AS char(255)) AND $JoinTable.field_id = " . $DynamicFieldConfig->{ID} . ") " );
        }
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
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

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
            push( @SQLJoin, "LEFT OUTER JOIN dynamic_field_value $JoinTable ON (CAST(st.id AS char(255)) = CAST($JoinTable.object_id AS char(255)) AND $JoinTable.field_id = " . $DynamicFieldConfig->{ID} . ") " );
        } 
        elsif ( $DynamicFieldConfig->{ObjectType} eq 'Article' ) {         
            push( @SQLJoin, "LEFT OUTER JOIN dynamic_field_value $JoinTable ON (CAST(artdfjoin.id AS char(255)) = CAST($JoinTable.object_id AS char(255)) AND $JoinTable.field_id = " . $DynamicFieldConfig->{ID} . ") " );
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
