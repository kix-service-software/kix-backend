# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Contact::UsageContext;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our @ObjectDependencies = qw(
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Contact::UsageContext - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        IsAgent => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE'],
            ValueType      => 'NUMERIC'
        },
        IsCustomer => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE'],
            ValueType      => 'NUMERIC'
        }
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if !$Self->_CheckSortParams(%Param);

    my @SQLJoin;
    my $TableAlias = $Param{Flags}->{JoinMap}->{UserJoin} // 'u';
    if ( !$Param{Flags}->{JoinMap}->{UserJoin} ) {
        my $Count = $Param{Flags}->{UserCounter}++;
        $TableAlias .= $Count;
        push(
            @SQLJoin,
            "LEFT JOIN users $TableAlias ON c.user_id = $TableAlias.id"
        );
        $Param{Flags}->{JoinMap}->{UserJoin} = $TableAlias;
    }

    # map search attributes to table attributes
    my %AttributeDefinition = (
        IsAgent    => "COALESCE($TableAlias.is_agent,0) AS isagent",
        IsCustomer => "COALESCE($TableAlias.is_customer,0) AS iscustomer"
    );

    # map search attributes to table attributes
    my %AttributeOrderDefinition = (
        IsAgent    => 'isagent',
        IsCustomer => 'iscustomer'
    );

    return {
        Select  => [$AttributeDefinition{$Param{Attribute}}],
        OrderBy => [$AttributeOrderDefinition{$Param{Attribute}}],
        Join    => \@SQLJoin
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    my @Join;
    my $TableAlias = $Param{Flags}->{JoinMap}->{UserJoin} // 'u';
    if ( !$Param{Flags}->{JoinMap}->{UserJoin} ) {
        my $Count = $Param{Flags}->{UserCounter}++;
        $TableAlias .= $Count;
        push(
            @Join,
            "LEFT JOIN users $TableAlias ON c.user_id = $TableAlias.id"
        );
        $Param{Flags}->{JoinMap}->{UserJoin} = $TableAlias;
    }

    # map search attributes to table attributes
    my %Attributes = (
        IsAgent    => "$TableAlias.is_agent",
        IsCustomer => "$TableAlias.is_customer"
    );

    return {
        ConditionDef => {
            Column    => $Attributes{$Param{Search}->{Field}},
            ValueType => 'NUMERIC',
            NULLValue => 1,
        },
        SQLDef => {
            Join => \@Join
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
