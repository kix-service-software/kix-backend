# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::TimeAccounting::Editor;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::TimeAccounting::Editor - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        CreateByID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        },
        CreateBy => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
## TODO: login based search instead of id
#            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ChangeByID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        },
        ChangeBy => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
## TODO: login based search instead of id
#            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # init Definition
    my %AttributeDefinition = (
        CreateByID => {
            Column       => 'ta.create_by',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        CreateBy   => {
            Column       => 'ta.create_by',
            SortColumn   => ['LOWER(crutac.lastname)','LOWER(crutac.firstname)','LOWER(cruta.login)'],
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
## TODO: login based search instead of id
#            Column          => 'cruta.login',
#            CaseInsensitive => 1
        },
        ChangeByID => {
            Column       => 'ta.change_by',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        ChangeBy   => {
            Column       => 'ta.change_by',
            SortColumn   => ['LOWER(chutac.lastname)','LOWER(chutac.firstname)','LOWER(chuta.login)'],
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
## TODO: login based search instead of id
#            Column          => 'chuta.login',
#            CaseInsensitive => 1
        }
    );

    my %Attribute = (
        Column => $AttributeDefinition{ $Param{Attribute} }->{ $Param{PrepareType} . 'Column' }
            || $AttributeDefinition{ $Param{Attribute} }->{Column},
    );
    if ( $Param{PrepareType} eq 'Condition' ) {
        $Attribute{ConditionDef} = $AttributeDefinition{ $Param{Attribute} }->{ConditionDef};
## TODO: login based search instead of id
#        # check for needed joins
#        my @SQLJoin = ();
#        if ( $Param{Attribute} eq 'CreateBy' ) {
#            if ( !$Param{Flags}->{JoinMap}->{TimeAccountingCreateBy} ) {
#                push( @SQLJoin, 'INNER JOIN users cruta ON cruta.id = ta.create_by' );
#
#                $Param{Flags}->{JoinMap}->{TimeAccountingCreateBy} = 1;
#            }
#        }
#        elsif ( $Param{Attribute} eq 'ChangeBy' ) {
#            if ( !$Param{Flags}->{JoinMap}->{TimeAccountingChangeBy} ) {
#                push( @SQLJoin, 'INNER JOIN users chuta ON chuta.id = ta.change_by' );
#
#                $Param{Flags}->{JoinMap}->{TimeAccountingChangeBy} = 1;
#            }
#        }
#
#        $Attribute{SQLDef}->{Join} = \@SQLJoin;
    }
    elsif ( $Param{PrepareType} eq 'Sort' ) {
        # check for needed joins
        my @SQLJoin = ();
        if ( $Param{Attribute} eq 'CreateBy' ) {
            if ( !$Param{Flags}->{JoinMap}->{TimeAccountingCreateBy} ) {
                push( @SQLJoin, 'INNER JOIN users cruta ON cruta.id = ta.create_by' );

                $Param{Flags}->{JoinMap}->{TimeAccountingCreateBy} = 1;
            }
            if ( !$Param{Flags}->{JoinMap}->{TimeAccountingCreateByContact} ) {
                push( @SQLJoin, 'LEFT OUTER JOIN contact crutac ON crutac.user_id = cruta.id' );

                $Param{Flags}->{JoinMap}->{TimeAccountingCreateByContact} = 1;
            }
        }
        if ( $Param{Attribute} eq 'ChangeBy' ) {
            if ( !$Param{Flags}->{JoinMap}->{TimeAccountingChangeBy} ) {
                push( @SQLJoin, 'INNER JOIN users chuta ON chuta.id = ta.change_by' );

                $Param{Flags}->{JoinMap}->{TimeAccountingChangeBy} = 1;
            }
            if ( !$Param{Flags}->{JoinMap}->{TimeAccountingChangeByContact} ) {
                push( @SQLJoin, 'LEFT OUTER JOIN contact chutac ON chutac.user_id = chuta.id' );

                $Param{Flags}->{JoinMap}->{TimeAccountingChangeByContact} = 1;
            }
        }

        $Attribute{SQLDef}->{Join} = \@SQLJoin;
    }

    return \%Attribute;
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
