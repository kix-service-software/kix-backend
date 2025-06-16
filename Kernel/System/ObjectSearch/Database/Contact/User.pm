# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Contact::User;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Contact::User - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        UserID => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN'],
            ValueType      => 'NUMERIC'
        },
        AssignedUserID => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN'],
            ValueType      => 'NUMERIC'
        },
        Login => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        UserLogin => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        }
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if !$Self->_CheckSortParams(%Param);

    my @SQLJoin;
    my $TableAlias = $Param{Flags}->{FlagMap}->{UserJoin} // 'u';
    if ( $Param{Attribute} =~ m/Login$/sm ){
        if ( !$Param{Flags}->{FlagMap}->{UserJoin} ) {
            my $Count = $Param{Flags}->{UserCounter}++;
            $TableAlias .= $Count;
            push(
                @SQLJoin,
                "LEFT JOIN users $TableAlias ON c.user_id = $TableAlias.id"
            );
            $Param{Flags}->{UserJoin} = $TableAlias;
        }
    }

    # map search attributes to table attributes
    my %AttributeDefinition = (
        UserID         => 'c.user_id',
        AssignedUserID => 'c.user_id',
        Login          => "$TableAlias.login",
        UserLogin      => "$TableAlias.login",
    );

    return {
        Select  => [$AttributeDefinition{$Param{Attribute}}],
        OrderBy => [$AttributeDefinition{$Param{Attribute}}],
        Join    => \@SQLJoin
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    if ( $Param{Search}->{Field} =~ m/Login$/sm ){
        my $TableAlias = $Param{Flags}->{FlagMap}->{UserJoin} // 'u';
        my @SQLJoin;
        if ( !$Param{Flags}->{FlagMap}->{UserJoin} ) {
            my $Count = $Param{Flags}->{UserCounter}++;
            $TableAlias .= $Count;
            push(
                @SQLJoin,
                "LEFT JOIN users $TableAlias ON c.user_id = $TableAlias.id"
            );
            $Param{Flags}->{UserJoin} = $TableAlias;
        }
        return {
            ConditionDef => {
                Column          => "$TableAlias.login",
                ValueType       => 'STRING',
                CaseInsensitive => 1,
                NULLValue       => 1
            },
            SQLDef => {
                Join => \@SQLJoin
            }
        };
    }

    return {
        ConditionDef => {
            Column    => 'c.user_id',
            ValueType => 'NUMERIC',
            NULLValue => 1
        }
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
