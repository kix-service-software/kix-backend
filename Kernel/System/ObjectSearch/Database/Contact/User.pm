# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        },
        AssignedUserID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        },
        Login => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        UserLogin => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;
    my @SQLJoin;

    # check params
    return if !$Self->_CheckSearchParams(%Param);

    my %GetParams = (
        Column    => 'c.user_id',
        ValueType => 'NUMERIC'
    );

    my $TableAlias = $Param{Flags}->{UserJoin} // 'u';
    if ( $Param{Search}->{Field} =~ m/Login$/sm ){
        if ( !$Param{Flags}->{UserJoin} ) {
            my $Count = $Param{Flags}->{UserCounter}++;
            $TableAlias .= $Count;
            push(
                @SQLJoin,
                "LEFT JOIN users $TableAlias ON c.user_id = $TableAlias.id"
            );
            $Param{Flags}->{UserJoin} = $TableAlias;
        }
        %GetParams = (
            Column          => "$TableAlias.login",
            ValueType       => 'STRING',
            CaseInsensitive => 1,
        );
    }

    my $Condition = $Self->_GetCondition(
        Operator  => $Param{Search}->{Operator},
        Value     => $Param{Search}->{Value},
        NULLValue => 1,
        %GetParams
    );

    return if ( !$Condition );

    return {
        Join  => \@SQLJoin,
        Where => [ $Condition ]
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if !$Self->_CheckSortParams(%Param);

    my @SQLJoin;
    my $TableAlias = $Param{Flags}->{UserJoin} // 'u';
    if ( $Param{Attribute} =~ m/Login$/sm ){
        if ( !$Param{Flags}->{UserJoin} ) {
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
    my %AttributeMapping = (
        UserID         => 'c.user_id',
        AssignedUserID => 'c.user_id',
        Login          => "$TableAlias.login",
        UserLogin      => "$TableAlias.login",
    );

    return {
        Select  => [$AttributeMapping{$Param{Attribute}}],
        OrderBy => [$AttributeMapping{$Param{Attribute}}],
        Join    => \@SQLJoin
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
