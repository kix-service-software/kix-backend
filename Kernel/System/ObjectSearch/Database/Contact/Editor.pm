# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Contact::Editor;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Contact::Editor - attribute module for database object search

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
            Column       => 'c.create_by',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        CreateBy   => {
            Column       => 'c.create_by',
            SortColumn   => ['LOWER(ccruc.lastname)','LOWER(ccruc.firstname)','LOWER(ccru.login)'],
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
## TODO: login based search instead of id
#            Column          => 'ccru.login',
#            CaseInsensitive => 1
        },
        ChangeByID => {
            Column       => 'c.change_by',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        ChangeBy   => {
            Column       => 'c.change_by',
            SortColumn   => ['LOWER(cchuc.lastname)','LOWER(cchuc.firstname)','LOWER(cchu.login)'],
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
## TODO: login based search instead of id
#            Column          => 'cchu.login',
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
#            if ( !$Param{Flags}->{JoinMap}->{ContactCreateBy} ) {
#                push( @SQLJoin, 'INNER JOIN users ccru ON ccru.id = c.create_by' );
#
#                $Param{Flags}->{JoinMap}->{ContactCreateBy} = 1;
#            }
#        }
#        elsif ( $Param{Attribute} eq 'ChangeBy' ) {
#            if ( !$Param{Flags}->{JoinMap}->{ContactChangeBy} ) {
#                push( @SQLJoin, 'INNER JOIN users cchu ON cchu.id = c.change_by' );
#
#                $Param{Flags}->{JoinMap}->{ContactChangeBy} = 1;
#            }
#        }
#
#        $Attribute{SQLDef}->{Join} = \@SQLJoin;
    }
    elsif ( $Param{PrepareType} eq 'Sort' ) {
        # check for needed joins
        my @SQLJoin = ();
        if ( $Param{Attribute} eq 'CreateBy' ) {
            if ( !$Param{Flags}->{JoinMap}->{ContactCreateBy} ) {
                push( @SQLJoin, 'INNER JOIN users ccru ON ccru.id = c.create_by' );

                $Param{Flags}->{JoinMap}->{ContactCreateBy} = 1;
            }
            if ( !$Param{Flags}->{JoinMap}->{ContactCreateByContact} ) {
                push( @SQLJoin, 'LEFT OUTER JOIN contact ccruc ON ccruc.user_id = ccru.id' );

                $Param{Flags}->{JoinMap}->{ContactCreateByContact} = 1;
            }
        }
        if ( $Param{Attribute} eq 'ChangeBy' ) {
            if ( !$Param{Flags}->{JoinMap}->{ContactChangeBy} ) {
                push( @SQLJoin, 'INNER JOIN users cchu ON cchu.id = c.change_by' );

                $Param{Flags}->{JoinMap}->{ContactChangeBy} = 1;
            }
            if ( !$Param{Flags}->{JoinMap}->{ContactChangeByContact} ) {
                push( @SQLJoin, 'LEFT OUTER JOIN contact cchuc ON cchuc.user_id = cchu.id' );

                $Param{Flags}->{JoinMap}->{ContactChangeByContact} = 1;
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
