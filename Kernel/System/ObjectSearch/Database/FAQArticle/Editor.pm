# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
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

    # check for needed joins
    my @SQLJoin = ();
    if (
        $Param{Attribute} eq 'CreateBy'
        || $Param{Attribute} eq 'CreatedUserIDs'
    ) {
        if ( !$Param{Flags}->{JoinMap}->{FAQArticleCreateBy} ) {
            push( @SQLJoin, 'INNER JOIN users fcru ON fcru.id = f.created_by' );

            $Param{Flags}->{JoinMap}->{FAQArticleCreateBy} = 1;
        }
        if ( !$Param{Flags}->{JoinMap}->{FAQArticleCreateByContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact fcruc ON fcruc.user_id = fcru.id' );

            $Param{Flags}->{JoinMap}->{FAQArticleCreateByContact} = 1;
        }
    }
    if (
        $Param{Attribute} eq 'ChangeBy'
        || $Param{Attribute} eq 'LastChangedUserIDs'
    ) {
        if ( !$Param{Flags}->{JoinMap}->{FAQArticleChangeBy} ) {
            push( @SQLJoin, 'INNER JOIN users fchu ON fchu.id = f.changed_by' );

            $Param{Flags}->{JoinMap}->{FAQArticleChangeBy} = 1;
        }
        if ( !$Param{Flags}->{JoinMap}->{FAQArticleChangeByContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact fchuc ON fchuc.user_id = fchu.id' );

            $Param{Flags}->{JoinMap}->{FAQArticleChangeByContact} = 1;
        }
    }

    # init mapping
    my %AttributeMapping = (
        CreatedUserIDs => {
            Select  => ['fcruc.lastname','fcruc.firstname','fcru.login'],
            OrderBy => ['LOWER(fcruc.lastname)','LOWER(fcruc.firstname)','LOWER(fcru.login)']
        },
        CreateBy   => {
            Select  => ['fcruc.lastname','fcruc.firstname','fcru.login'],
            OrderBy => ['LOWER(fcruc.lastname)','LOWER(fcruc.firstname)','LOWER(fcru.login)']
        },
        LastChangedUserIDs => {
            Select  => ['fchuc.lastname','fchuc.firstname','fchu.login'],
            OrderBy => ['LOWER(fchuc.lastname)','LOWER(fchuc.firstname)','LOWER(fchu.login)']
        },
        ChangeBy   => {
            Select  => ['fchuc.lastname','fchuc.firstname','fchu.login'],
            OrderBy => ['LOWER(fchuc.lastname)','LOWER(fchuc.firstname)','LOWER(fchu.login)']
        }
    );

    # return sort def
    return {
        Join    => \@SQLJoin,
        Select  => $AttributeMapping{ $Param{Attribute} }->{Select},
        OrderBy => $AttributeMapping{ $Param{Attribute} }->{OrderBy}
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
