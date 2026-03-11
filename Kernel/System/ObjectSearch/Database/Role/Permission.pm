# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Role::Permission;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Role::Permission - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        'Permissions.Target' => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        'Permissions.Type' => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        'Permissions.TypeID' => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        },
        'Permissions.Value' => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    my %JoinData = $Self->_JoinGet(
        Flags     => $Param{Flags},
        Attribute => $Param{Attribute}
    );

    # map search attributes to table attributes
    my %AttributeDefinition = (
        'Permissions.Target' => {
            Column       => "$JoinData{RPAlias}.target",
            ConditionDef => {
                ValueType       => "STRING",
                CaseInsensitive => 1
            }
        },
        'Permissions.Type' => {
            Column       => "$JoinData{PTAlias}.name",
            ConditionDef => {
                ValueType       => "STRING",
                CaseInsensitive => 1
            }
        },
        'Permissions.TypeID' => {
            Column       => "$JoinData{RPAlias}.type_id",
            ConditionDef => {
                ValueType => 'NUMERIC',
            }
        },
        'Permissions.Value'  => {
            Column       => "$JoinData{RPAlias}.value",
            ConditionDef => {
                ValueType => 'NUMERIC',
            }
        }
    );

    my %Attribute = (
        Column => $AttributeDefinition{ $Param{Attribute} }->{Column},
        SQLDef => {
            Join => $JoinData{Join},
        }
    );
    if ( $Param{PrepareType} eq 'Condition' ) {
        $Attribute{ConditionDef} = $AttributeDefinition{ $Param{Attribute} }->{ConditionDef};
    }

    return \%Attribute;
}

sub _JoinGet {
    my ( $Self, %Param ) = @_;

    my @SQLJoin;

    my $RPTableAlias = $Param{Flags}->{JoinMap}->{RolePermissionJoin} // 'rp';
    if ( !$Param{Flags}->{JoinMap}->{RolePermissionJoin} ) {
        my $Count = $Param{Flags}->{RolePermissionJoinCounter}++;
        $RPTableAlias .= $Count;

        push(
            @SQLJoin,
            "LEFT JOIN role_permission $RPTableAlias ON $RPTableAlias.role_id = r.id",
        );

        $Param{Flags}->{JoinMap}->{RolePermissionJoin} = $RPTableAlias;
    }

    my $PTTableAlias = $Param{Flags}->{JoinMap}->{PermissionTypeJoin} // 'pt';
    if ( !$Param{Flags}->{JoinMap}->{PermissionTypeJoin} && $Param{Attribute} eq 'Permissions.Type' ) {
        my $Count = $Param{Flags}->{PermissionTypeJoinCounter}++;
        $PTTableAlias .= $Count;

        push(
            @SQLJoin,
            "LEFT JOIN permission_type $PTTableAlias ON $RPTableAlias.type_id = $PTTableAlias.id",
        );

        $Param{Flags}->{JoinMap}->{PermissionTypeJoin} = $PTTableAlias;
    }

    return (
        Join    => \@SQLJoin,
        RPAlias => $RPTableAlias,
        PTAlias => $PTTableAlias,
    );
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
