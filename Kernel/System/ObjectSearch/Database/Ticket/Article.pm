# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::Article;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Article - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        ArticleID         => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        ChannelID         => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        Channel           => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        SenderTypeID      => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        SenderType        => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        CustomerVisible   => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        From              => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        To                => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Cc                => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Subject           => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Body              => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ArticleCreateTime => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','LT','GT','LTE','GTE'],
            ValueType    => 'DATETIME'
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # check if search for ArticleID is used
    my $HasArticleIDSearch = 0;
    if ( IsArrayRefWithData( $Param{WholeSearch} ) ) {
        for my $SearchEntry ( @{ $Param{WholeSearch} } ) {
            if ($SearchEntry->{Field} eq 'ArticleID') {
                $HasArticleIDSearch = 1;

                last;
            }
        }
    }

    # check if static search should be used. Only if search for ArticleID is NOT used and static search index is active
    my $IsStaticSearch = 0;
    if ( !$HasArticleIDSearch ) {
        my $SearchIndexModule = $Kernel::OM->Get('Config')->Get('Ticket::SearchIndexModule');
        if ( $SearchIndexModule =~ /::StaticDB$/ ) {
            $IsStaticSearch = 1;
        }
    }

    # check for needed joins
    my @SQLJoin = ();
    my $TableAliasPrefix = '';
    if ( $IsStaticSearch ) {
        $TableAliasPrefix = 's_';
        if ( !$Param{Flags}->{JoinMap}->{StaticArticle} ) {
            my $JoinString = 'LEFT OUTER JOIN article_search s_ta ON s_ta.ticket_id = st.id';

            # restrict search from customers to customer visible articles
            if ( $Param{UserType} eq 'Customer' ) {
                $JoinString .= ' AND s_ta.customer_visible = 1';
            }
            push( @SQLJoin, $JoinString );

            $Param{Flags}->{JoinMap}->{StaticArticle} = 1;
        }
        if ( $Param{Search}->{Field} eq 'Channel' ) {
            if ( !$Param{Flags}->{JoinMap}->{StaticArticleChannel} ) {
                push( @SQLJoin, 'LEFT OUTER JOIN channel s_tac ON s_tac.id = s_ta.channel_id' );

                $Param{Flags}->{JoinMap}->{StaticArticleChannel} = 1;
            }
        }
        if ( $Param{Search}->{Field} eq 'SenderType' ) {
            if ( !$Param{Flags}->{JoinMap}->{StaticArticleSenderType} ) {
                push( @SQLJoin, 'LEFT OUTER JOIN article_sender_type s_tast ON s_tast.id = s_ta.article_sender_type_id' );

                $Param{Flags}->{JoinMap}->{StaticArticleSenderType} = 1;
            }
        }
    }
    else {
        if ( !$Param{Flags}->{JoinMap}->{Article} ) {
            my $JoinString = 'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id';

            # restrict search from customers to customer visible articles
            if ( $Param{UserType} eq 'Customer' ) {
                $JoinString .= ' AND ta.customer_visible = 1';
            }
            push( @SQLJoin, $JoinString );

            $Param{Flags}->{JoinMap}->{Article} = 1;
        }
        if ( $Param{Search}->{Field} eq 'Channel' ) {
            if ( !$Param{Flags}->{JoinMap}->{ArticleChannel} ) {
                push( @SQLJoin, 'LEFT OUTER JOIN channel tac ON tac.id = ta.channel_id' );

                $Param{Flags}->{JoinMap}->{ArticleChannel} = 1;
            }
        }
        if ( $Param{Search}->{Field} eq 'SenderType' ) {
            if ( !$Param{Flags}->{JoinMap}->{ArticleSenderType} ) {
                push( @SQLJoin, 'LEFT OUTER JOIN article_sender_type tast ON tast.id = ta.article_sender_type_id' );

                $Param{Flags}->{JoinMap}->{ArticleSenderType} = 1;
            }
        }
    }

    # init mapping
    my %AttributeMapping = (
        ArticleID         => {
            Column          => $TableAliasPrefix . 'ta.id',
            ValueType       => 'NUMERIC'
        },
        ChannelID         => {
            Column          => $TableAliasPrefix . 'ta.channel_id',
            ValueType       => 'NUMERIC'
        },
        Channel           => {
            Column          => $TableAliasPrefix . 'tac.name',
            CaseInsensitive => 1
        },
        SenderTypeID      => {
            Column          => $TableAliasPrefix . 'ta.article_sender_type_id',
            ValueType       => 'NUMERIC'
        },
        SenderType        => {
            Column          => $TableAliasPrefix . 'tast.name',
            CaseInsensitive => 1
        },
        CustomerVisible   => {
            Column          => $TableAliasPrefix . 'ta.customer_visible',
            ValueType       => 'NUMERIC'
        },
        From              => {
            Column          => $TableAliasPrefix . 'ta.a_from',
            CaseInsensitive => 1,
            IsStaticSearch  => $IsStaticSearch
        },
        To                => {
            Column          => $TableAliasPrefix . 'ta.a_to',
            CaseInsensitive => 1,
            IsStaticSearch  => $IsStaticSearch
        },
        Cc                => {
            Column          => $TableAliasPrefix . 'ta.a_cc',
            CaseInsensitive => 1,
            IsStaticSearch  => $IsStaticSearch
        },
        Subject           => {
            Column          => $TableAliasPrefix . 'ta.a_subject',
            CaseInsensitive => 1,
            IsStaticSearch  => $IsStaticSearch
        },
        Body              => {
            Column          => $TableAliasPrefix . 'ta.a_body',
            CaseInsensitive => 1,
            IsStaticSearch  => $IsStaticSearch
        },
        ArticleCreateTime => {
            Column          => $TableAliasPrefix . 'ta.incoming_time',
            ValueType       => 'NUMERIC'
        }
    );

    # prepare given values as array ref and convert if required
    my $Values = [];
    if ( !IsArrayRef( $Param{Search}->{Value} ) ) {
        push( @{ $Values },  $Param{Search}->{Value}  );
    }
    else {
        $Values =  $Param{Search}->{Value} ;
    }

    # special handling for ArticleCreateTime
    if ( $Param{Search}->{Field} eq 'ArticleCreateTime' ) {
        for my $Value ( @{ $Values } ) {
            $Value = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                String => $Value
            );
        }
    }

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator        => $Param{Search}->{Operator},
        Column          => $AttributeMapping{ $Param{Search}->{Field} }->{Column},
        ValueType       => $AttributeMapping{ $Param{Search}->{Field} }->{ValueType},
        CaseInsensitive => $AttributeMapping{ $Param{Search}->{Field} }->{CaseInsensitive},
        IsStaticSearch  => $AttributeMapping{ $Param{Search}->{Field} }->{IsStaticSearch},
        Value           => $Values,
        NULLValue       => 1,
        Silent          => $Param{Silent}
    );
    return if ( !$Condition );

    return {
        Join  => \@SQLJoin,
        Where => [ $Condition ]
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
