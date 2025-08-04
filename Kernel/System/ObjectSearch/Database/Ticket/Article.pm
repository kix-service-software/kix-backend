# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        },
        ChannelID         => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        },
        Channel           => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        SenderTypeID      => {
            IsSelectable => 0,
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        SenderType        => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        CustomerVisible   => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        },
        From              => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        To                => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Cc                => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Subject           => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Body              => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ArticleCreateTime => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ','LT','GT','LTE','GTE'],
            ValueType      => 'DATETIME'
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # check if search for ArticleID is used
    my $HasArticleIDSearch = 0;
    if (
        $Param{PrepareType} eq 'Condition'
        && IsArrayRefWithData( $Param{WholeSearch} )
    ) {
        for my $SearchEntry ( @{ $Param{WholeSearch} } ) {
            if ($SearchEntry->{Field} eq 'ArticleID') {
                $HasArticleIDSearch = 1;

                last;
            }
        }
    }

    # check if static search should be used. Only if search for ArticleID is NOT used and static search index is active
    my $IsStaticSearch = 0;
    if (
        $Param{PrepareType} eq 'Condition'
        && !$HasArticleIDSearch
    ) {
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
        if ( $Param{Attribute} eq 'Channel' ) {
            if ( !$Param{Flags}->{JoinMap}->{StaticArticleChannel} ) {
                push( @SQLJoin, 'LEFT OUTER JOIN channel s_tac ON s_tac.id = s_ta.channel_id' );

                $Param{Flags}->{JoinMap}->{StaticArticleChannel} = 1;
            }
        }
        if ( $Param{Attribute} eq 'SenderType' ) {
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
        if ( $Param{Attribute} eq 'Channel' ) {
            if ( !$Param{Flags}->{JoinMap}->{ArticleChannel} ) {
                push( @SQLJoin, 'LEFT OUTER JOIN channel tac ON tac.id = ta.channel_id' );

                $Param{Flags}->{JoinMap}->{ArticleChannel} = 1;
            }
        }
        if ( $Param{Attribute} eq 'SenderType' ) {
            if ( !$Param{Flags}->{JoinMap}->{ArticleSenderType} ) {
                push( @SQLJoin, 'LEFT OUTER JOIN article_sender_type tast ON tast.id = ta.article_sender_type_id' );

                $Param{Flags}->{JoinMap}->{ArticleSenderType} = 1;
            }
        }
    }

    # init mapping
    my %AttributeDefinition = (
        ArticleID         => {
            Column       => $TableAliasPrefix . 'ta.id',
            ConditionDef => {
                ValueType => 'NUMERIC',
                NULLValue => 1
            }
        },
        ChannelID         => {
            Column       => $TableAliasPrefix . 'ta.channel_id',
            ConditionDef => {
                ValueType => 'NUMERIC',
                NULLValue => 1
            }
        },
        Channel           => {
            Column       => $TableAliasPrefix . 'tac.name',
            ConditionDef => {
                CaseInsensitive => 1,
                NULLValue       => 1
            }
        },
        SenderTypeID      => {
            Column       => $TableAliasPrefix . 'ta.article_sender_type_id',
            ConditionDef => {
                ValueType => 'NUMERIC',
                NULLValue => 1
            }
        },
        SenderType        => {
            Column       => $TableAliasPrefix . 'tast.name',
            ConditionDef => {
                CaseInsensitive => 1,
                NULLValue       => 1
            }
        },
        CustomerVisible   => {
            Column       => $TableAliasPrefix . 'ta.customer_visible',
            ConditionDef => {
                ValueType => 'NUMERIC',
                NULLValue => 1
            }
        },
        From              => {
            Column       => $TableAliasPrefix . 'ta.a_from',
            ConditionDef => {
                CaseInsensitive => 1,
                IsStaticSearch  => $IsStaticSearch,
                NULLValue       => 1
            }
        },
        To                => {
            Column       => $TableAliasPrefix . 'ta.a_to',
            ConditionDef => {
                CaseInsensitive => 1,
                IsStaticSearch  => $IsStaticSearch,
                NULLValue       => 1
            }
        },
        Cc                => {
            Column       => $TableAliasPrefix . 'ta.a_cc',
            ConditionDef => {
                CaseInsensitive => 1,
                IsStaticSearch  => $IsStaticSearch,
                NULLValue       => 1
            }
        },
        Subject           => {
            Column       => $TableAliasPrefix . 'ta.a_subject',
            ConditionDef => {
                CaseInsensitive => 1,
                IsStaticSearch  => $IsStaticSearch,
                NULLValue       => 1
            }
        },
        Body              => {
            Column       => $TableAliasPrefix . 'ta.a_body',
            ConditionDef => {
                CaseInsensitive => 1,
                IsStaticSearch  => $IsStaticSearch,
                NULLValue       => 1
            }
        },
        ArticleCreateTime => {
            Column       => $TableAliasPrefix . 'ta.incoming_time',
            ConditionDef => {
                ValueType => 'NUMERIC',
                NULLValue => 1
            }
        }
    );

    my %Attribute = (
        Column => $AttributeDefinition{ $Param{Attribute} }->{Column},
        SQLDef => {
            Join => \@SQLJoin,
        }
    );
    if ( $Param{PrepareType} eq 'Condition' ) {
        $Attribute{ConditionDef} = $AttributeDefinition{ $Param{Attribute} }->{ConditionDef};
    }

    return \%Attribute;
}

sub ValuePrepare {
    my ($Self, %Param) = @_;

    return $Param{Search}->{Value} if (
        $Param{Search}->{Field} ne 'ArticleCreateTime'
    );

    # prepare given values as array ref and convert if required
    my $Values = [];
    if ( !IsArrayRef( $Param{Search}->{Value} ) ) {
        push( @{ $Values }, $Param{Search}->{Value} );
    }
    else {
        $Values =  $Param{Search}->{Value} ;
    }

    # convert timestamp to system time
    for my $Value ( @{ $Values } ) {
        $Value = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
            String => $Value
        );
        if ( !$Value ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid date format found in parameter $Param{Search}->{Field}!",
            );
            return;
        }

        $Value = $Kernel::OM->Get('DB')->Quote( $Value );
    }

    return $Values;
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
