# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Automation::JobRun::Editor;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Automation::JobRun::Editor - attribute module for database object search

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
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # init Definition
    my %AttributeDefinition = (
        CreateByID => {
            Column       => 'ajr.create_by',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        CreateBy   => {
            Column       => 'ajr.create_by',
            SortColumn   => ['LOWER(ajrcruc.lastname)','LOWER(ajrcruc.firstname)','LOWER(ajrcru.login)'],
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
## TODO: login based search instead of id
#            Column          => 'ccru.login',
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
#            if ( !$Param{Flags}->{JoinMap}->{JobRunCreateBy} ) {
#                push( @SQLJoin, 'INNER JOIN users ajrcru ON ajrcru.id = ajr.create_by' );
#
#                $Param{Flags}->{JoinMap}->{JobRunCreateBy} = 1;
#            }
#        }
#        elsif ( $Param{Attribute} eq 'ChangeBy' ) {
#            if ( !$Param{Flags}->{JoinMap}->{JobRunChangeBy} ) {
#                push( @SQLJoin, 'INNER JOIN users ajrchu ON ajrchu.id = ajr.change_by' );
#
#                $Param{Flags}->{JoinMap}->{JobRunChangeBy} = 1;
#            }
#        }
#
#        $Attribute{SQLDef}->{Join} = \@SQLJoin;
    }
    elsif ( $Param{PrepareType} eq 'Sort' ) {
        # check for needed joins
        my @SQLJoin = ();
        if ( $Param{Attribute} eq 'CreateBy' ) {
            if ( !$Param{Flags}->{JoinMap}->{JobRunCreateBy} ) {
                push( @SQLJoin, 'INNER JOIN users ajrcru ON ajrcru.id = ajr.create_by' );

                $Param{Flags}->{JoinMap}->{JobRunCreateBy} = 1;
            }
            if ( !$Param{Flags}->{JoinMap}->{JobRunCreateByContact} ) {
                push( @SQLJoin, 'LEFT OUTER JOIN contact ajrcruc ON ajrcruc.user_id = ajrcru.id' );

                $Param{Flags}->{JoinMap}->{JobRunCreateByContact} = 1;
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
