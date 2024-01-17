# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::FAQArticle::Vote;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::FAQArticle::Vote - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Votes => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        Rating => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    my @SQLJoin;
    my @SQLGroupBy;
    my @SQLHaving;

    my $TableAlias = $Param{Flags}->{FlagMap}->{VoteJoin} // 'fv';
    if ( !$Param{Flags}->{FlagMap}->{VoteJoin} ) {
        my $Count = $Param{Flags}->{VoteJoinCounter}++;
        $TableAlias .= $Count;

        push(
            @SQLJoin,
            "LEFT JOIN faq_voting $TableAlias ON $TableAlias.item_id = f.id"
        );

        push(
            @SQLGroupBy,
            'f.id'
        );

        $Param{Flags}->{FlagMap}->{VoteJoin} = $TableAlias;
    }

    my %AttributeMapping = (
        Rating => "AVG(COALESCE($TableAlias.rate,-1))",
        Votes  => "COUNT($TableAlias.item_id)"
    );

    my @Having = $Self->_GetCondition(
        Operator  => $Param{Search}->{Operator},
        Column    => $AttributeMapping{$Param{Search}->{Field}},
        Value     => $Param{Search}->{Value},
        ValueType => 'NUMERIC'
    );

    return if !@Having;

    push( @SQLHaving, @Having );

    return {
        Join    => \@SQLJoin,
        GroupBy => \@SQLGroupBy,
        Having  => \@SQLHaving
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSortParams( %Param ) );

    my @SQLJoin;
    my @SQLGroupBy;

    my $TableAlias = $Param{Flags}->{FlagMap}->{VoteJoin} // 'fv';
    if ( !$Param{Flags}->{FlagMap}->{VoteJoin} ) {
        my $Count = $Param{Flags}->{VoteJoinCounter}++;
        $TableAlias .= $Count;

        push(
            @SQLJoin,
            "LEFT JOIN faq_voting $TableAlias ON $TableAlias.item_id = f.id"
        );

        push(
            @SQLGroupBy,
            'f.id'
        );

        $Param{Flags}->{FlagMap}->{VoteJoin} = $TableAlias;
    }

    my %AttributeMapping = (
        Rating => ["AVG(COALESCE($TableAlias.rate,-1)) AS rates"],
        Votes  => ["COUNT($TableAlias.item_id) AS votes"],
    );

    my %AttributeOrderMapping = (
        Rating => ['rates'],
        Votes  => ['votes']
    );

    return {
        Select  => $AttributeMapping{$Param{Attribute}},
        OrderBy => $AttributeOrderMapping{$Param{Attribute}},
        Join    => \@SQLJoin,
        GroupBy => \@SQLGroupBy
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
