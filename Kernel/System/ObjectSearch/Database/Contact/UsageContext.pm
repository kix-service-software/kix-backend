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
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE'],
            ValueType      => 'NUMERIC'
        },
        IsCustomer => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE'],
            ValueType      => 'NUMERIC'
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

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
        IsAgent    => "$TableAlias.is_agent",
        IsCustomer => "$TableAlias.is_customer"
    );

    my %Attribute = (
        Column => $AttributeDefinition{ $Param{Attribute} },
        SQLDef => {
            Join => \@SQLJoin
        }
    );
    if ( $Param{PrepareType} eq 'Condition' ) {
        $Attribute{ConditionDef} = {
            ValueType => 'NUMERIC',
            NULLValue => 1,
        };
    }
    elsif ( $Param{PrepareType} eq 'Sort' ) {
        $Attribute{Column} = 'COALESCE(' . $Attribute{Column} . ',0)';
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
