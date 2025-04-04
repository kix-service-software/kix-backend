# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Article::SenderType;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Article::SenderType - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        SenderTypeID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        SenderType   => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    my @Join;
    if (
        $Param{Search}->{Field} eq 'SenderType'
        && !$Param{Flags}->{JoinMap}->{ArticleSenderType}
    ) {
        push( @Join, 'LEFT OUTER JOIN article_sender_type ast ON ast.id = a.article_sender_type_id' );

        $Param{Flags}->{JoinMap}->{ArticleSenderType} = 1;
    }

    # init mapping
    my %AttributeMapping = (
        SenderTypeID => {
            Column          => 'a.article_sender_type_id',
            ValueType       => 'NUMERIC'
        },
        SenderType   => {
            Column          => 'ast.name',
            CaseInsensitive => 1
        }
    );

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator        => $Param{Search}->{Operator},
        Column          => $AttributeMapping{ $Param{Search}->{Field} }->{Column},
        ValueType       => $AttributeMapping{ $Param{Search}->{Field} }->{ValueType},
        CaseInsensitive => $AttributeMapping{ $Param{Search}->{Field} }->{CaseInsensitive},
        Value           => $Param{Search}->{Value},
        Silent          => $Param{Silent}
    );
    return if ( !$Condition );

    return {
        Join  => \@Join,
        Where => [ $Condition ]
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if !$Self->_CheckSortParams( %Param );

    # check for needed joins
    my @Join;
    if (
        $Param{Attribute} eq 'SenderType'
        && !$Param{Flags}->{JoinMap}->{ArticleSenderType}
    ) {
        push( @Join, 'LEFT OUTER JOIN article_sender_type ast ON ast.id = a.article_sender_type_id' );

        $Param{Flags}->{JoinMap}->{ArticleSenderType} = 1;
    }

    # map search attributes to table attributes
    my %AttributeMapping = (
        SenderTypeID => 'a.article_sender_type_id',
        SenderType   => 'ast.name'
    );

    return {
        Select  => [ $AttributeMapping{ $Param{Attribute} } ],
        OrderBy => [ $AttributeMapping{ $Param{Attribute} } ],
        Join    => \@Join
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
