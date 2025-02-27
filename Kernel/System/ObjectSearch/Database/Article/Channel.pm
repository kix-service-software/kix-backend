# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Article::Channel;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Article::Channel - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        ChannelID         => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        Channel           => {
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

    # check for needed joins
    my @SQLJoin = ();
    if (
        $Param{Search}->{Field} eq 'Channel'
        && !$Param{Flags}->{JoinMap}->{ArticleChannel}
    ) {
        push( @SQLJoin, 'LEFT OUTER JOIN channel ac ON ac.id = a.channel_id' );

        $Param{Flags}->{JoinMap}->{ArticleChannel} = 1;
    }

    # init mapping
    my %AttributeMapping = (
        ChannelID         => {
            Column          => 'a.channel_id',
            ValueType       => 'NUMERIC'
        },
        Channel           => {
            Column          => 'ac.name',
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
        Join  => \@SQLJoin,
        Where => [ $Condition ]
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if !$Self->_CheckSortParams( %Param );

    # check for needed joins
    my @SQLJoin = ();
    if (
        $Param{Attribute} eq 'Channel'
        && !$Param{Flags}->{JoinMap}->{ArticleChannel}
    ) {
        push( @SQLJoin, 'LEFT OUTER JOIN channel ac ON ac.id = a.channel_id' );

        $Param{Flags}->{JoinMap}->{ArticleChannel} = 1;
    }

    # map search attributes to table attributes
    my %AttributeMapping = (
        ChannelID => 'a.channel_id',
        Channel   => 'ac.name'
    );

    return {
        Select  => [ $AttributeMapping{ $Param{Attribute} } ],
        OrderBy => [ $AttributeMapping{ $Param{Attribute} } ],
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
