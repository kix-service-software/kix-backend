# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::FAQArticle::Editor;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::FAQArticle::Editor - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        CreateBy => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        },
        CreatedUserIDs => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        },
        ChangeBy => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        },
        LastChangedUserIDs => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    my %AttributeMapping = (
        CreateBy           => 'f.created_by',
        CreatedUserIDs     => 'f.created_by',
        ChangeBy           => 'f.changed_by',
        LastChangedUserIDs => 'f.changed_by',
    );

    my $Condition = $Self->_GetCondition(
        Operator  => $Param{Search}->{Operator},
        Column    => $AttributeMapping{$Param{Search}->{Field}},
        ValueType => 'NUMERIC',
        Value     => $Param{Search}->{Value}
    );

    return if ( !$Condition );

    return {
        Where => [ $Condition ]
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSortParams( %Param ) );

    my %Join;
    my $TableAlias = $Param{Flags}->{FlagMap}->{ContactJoin} // 'c';
    if (
        $Param{Attribute} =~ m/^Create(?:By|dUserIDs)$/sm
        && !$Param{Flags}->{FlagMap}->{ContactJoin}
    ) {
        my $Count = $Param{Flags}->{ContactJoinCounter}++;
        $TableAlias .= $Count;

        $Join{Join} = [
            "INNER JOIN contact $TableAlias ON $TableAlias.user_id = f.created_by"
        ];
        $Param{Flags}->{FlagMap}->{ContactJoin} = $TableAlias;
    }
    elsif (
        $Param{Attribute} =~ m/^(?:Last|)Change(?:By|dUserIDs)$/sm
        && !$Param{Flags}->{FlagMap}->{ContactJoin}
    ) {
        my $Count = $Param{Flags}->{ContactJoinCounter}++;
        $TableAlias .= $Count;

        $Join{Join} = [
            "INNER JOIN contact $TableAlias ON $TableAlias.user_id = f.changed_by"
        ];
        $Param{Flags}->{FlagMap}->{ContactJoin} = $TableAlias;
    }

    my %AttributeMapping = (
        CreateBy           => ["$TableAlias.lastname", "$TableAlias.firstname"],
        CreatedUserIDs     => ["$TableAlias.lastname", "$TableAlias.firstname"],
        ChangeBy           => ["$TableAlias.lastname", "$TableAlias.firstname"],
        LastChangedUserIDs => ["$TableAlias.lastname", "$TableAlias.firstname"],
    );

    return {
        Select   => $AttributeMapping{$Param{Attribute}},
        OrderBy  => $AttributeMapping{$Param{Attribute}},
        %Join
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
