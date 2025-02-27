# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
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

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Property => {
            IsSortable     => 0|1,
            IsSearchable => 0|1,
            Operators     => []
        },
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        IsAgent => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE'],
            ValueType    => 'NUMERIC'
        },
        IsCustomer => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE'],
            ValueType    => 'NUMERIC'
        }
    };
}


=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        Search => {}
    );

    $Result = {
        Where   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if !$Self->_CheckSearchParams(%Param);

    my $TableAlias = $Param{Flags}->{JoinMap}->{UserJoin} // 'u';
    my @SQLJoin;
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
    my %AttributeMapping = (
        IsAgent    => "$TableAlias.is_agent",
        IsCustomer => "$TableAlias.is_customer"
    );

    my $Condition = $Self->_GetCondition(
        Operator  => $Param{Search}->{Operator},
        Column    => $AttributeMapping{$Param{Search}->{Field}},
        Value     => $Param{Search}->{Value},
        ValueType => 'NUMERIC',
        NULLValue => 1
    );
    return if ( !$Condition );

    return {
        Join  => \@SQLJoin,
        Where => [ $Condition ]
    };
}

=item Sort()

run this module and return the SQL extensions

    my $Result = $Object->Sort(
        Attribute => '...'      # required
    );

    $Result = {
        Select  => [ ],          # optional
        OrderBy => [ ]           # optional
    };

=cut

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
    my %AttributeMapping = (
        IsAgent    => "COALESCE($TableAlias.is_agent,0) AS isagent",
        IsCustomer => "COALESCE($TableAlias.is_customer,0) AS iscustomer"
    );

    # map search attributes to table attributes
    my %AttributeOrderMapping = (
        IsAgent    => 'isagent',
        IsCustomer => 'iscustomer'
    );

    return {
        Select  => [$AttributeMapping{$Param{Attribute}}],
        OrderBy => [$AttributeOrderMapping{$Param{Attribute}}],
        Join    => \@SQLJoin
    };
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
