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
    Kernel::System::ObjectSearch::Database::Common
);

our @ObjectDependencies = qw(
    Config
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Article - attribute module for database object search

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
    $Self->{Supported} = {
        'ArticleID'         => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','LT','GT','LTE','GTE','IN','!IN','NE']
        },
        'ChannelID'         => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','LT','GT','LTE','GTE','IN','!IN','NE']
        },
        'SenderTypeID'      => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','LT','GT','LTE','GTE','IN','!IN','NE']
        },
        'CustomerVisible'   => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','LT','GT','LTE','GTE','IN','!IN','NE']
        },
        'From'              => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        'To'                => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        'Cc'                => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        'Subject'           => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        'Body'              => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        'ArticleCreateTime' => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','LT','GT','LTE','GTE']
        },
    };

    return $Self->{Supported};
}

=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        BoolOperator => 'AND' | 'OR',
        Search       => {}
    );

    $Result = {
        Join    => [ ],
        Where   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my @SQLJoin;
    my @SQLWhere;

    # check params
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    # map search attributes to table attributes
    my %AttributeMapping = (
        'ArticleID'         => 'id',
        'ChannelID'         => 'channel_id',
        'SenderTypeID'      => 'article_sender_type_id',
        'CustomerVisible'   => 'customer_visible',
        'From'              => 'a_from',
        'To'                => 'a_to',
        'Cc'                => 'a_cc',
        'Subject'           => 'a_subject',
        'Body'              => 'a_body',
    );

    my $HasArticleIDSearch = 0;
    if (IsArrayRefWithData($Param{WholeSearch})) {
        foreach my $Search ( @{$Param{WholeSearch}} ) {
            if ($Search->{Field} eq 'ArticleID') {
                $HasArticleIDSearch = 1;
                last;
            }
        }
    }

    my $IsStaticSearch = 0;

    # if no articl ID is search is given, use static search (if active),
    # else use all data (e.g. to match articles with very short bodies, too (WordLengthMin for article index))
    if (!$HasArticleIDSearch) {
        my $SearchIndexModule = $Kernel::OM->Get('Config')->Get('Ticket::SearchIndexModule');
        if ( $SearchIndexModule =~ /::StaticDB$/ ) {
            $IsStaticSearch = 1;
        }
    }

    # check if we have to add a join
    if (
        !$Param{Flags}->{ArticleJoined}
        || !$Param{Flags}->{ArticleJoined}->{$Param{BoolOperator}}
    ) {
        # use appropriate table for selected search index module
        my $ArticleSearchTable = 'article';
        if ( $IsStaticSearch ) {
            $ArticleSearchTable = 'article_search';
        }
        if ( $Param{BoolOperator} eq 'OR') {
            push( @SQLJoin, 'LEFT OUTER JOIN '.$ArticleSearchTable.' art_left ON st.id = art_left.ticket_id ' );
        } else {
            push( @SQLJoin, 'INNER JOIN '.$ArticleSearchTable.' art ON st.id = art.ticket_id ' );
        }
        $Param{Flags}->{ArticleJoined}->{$Param{BoolOperator}} = 1;
    }

    if ( $Param{Search}->{Field} =~ /ArticleCreateTime/ ) {
        # convert to unix time
        my $Value = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
            String => $Param{Search}->{Value},
            Silent => 1,
        );
        if ( !$Value ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "Invalid Date '$Param{Search}->{Value}'!",
            );

            return;
        }

        my @Where = $Self->GetOperation(
            Operator  => $Param{Search}->{Operator},
            Column    => $Param{BoolOperator} eq 'OR' ? 'rt_left.incoming_time' : 'art.incoming_time',
            Value     => $Param{Search}->{Value},
            Supported => $Self->{Supported}->{$Param{Search}->{Field}}->{Operators}
        );

        return if !@Where;

        push( @SQLWhere, @Where);
    }
    elsif ( $Param{Search}->{Field} =~ /ArticleID|ChannelID|SenderTypeID|CustomerVisible/ ) {
        my $Column = 'art.';
        if ( $Param{BoolOperator} eq 'OR') {
            $Column = 'art_left.';
        }
        $Column .= $AttributeMapping{$Param{Search}->{Field}};

        my @Where = $Self->GetOperation(
            Operator  => $Param{Search}->{Operator},
            Column    => $Column,
            Value     => $Param{Search}->{Value},
            Supported => $Self->{Supported}->{$Param{Search}->{Field}}->{Operators}
        );

        return if !@Where;

        push( @SQLWhere, @Where);
    }
    else {
        my $Field      = $AttributeMapping{$Param{Search}->{Field}};
        my $FieldValue = $Param{Search}->{Value};
        my $Prefix;
        my $Supplement;

        if ( $Param{BoolOperator} eq 'OR') {
            $Prefix = 'art_left.';
            if ( $Param{UserType} eq 'Customer' ) {
                $Supplement = [
                    'AND art_left.customer_visible = 1'
                ];
            }
        } else {
            $Prefix = 'art.';
            if ( $Param{UserType} eq 'Customer' ) {
                $Supplement = [
                    'AND art.customer_visible = 1'
                ];
            }
        }

        my @Where = $Self->GetOperation(
            Operator       => $Param{Search}->{Operator},
            Column         => $Prefix.$Field,
            Value          => $FieldValue,
            Prepare        => 1,
            Supported      => $Self->{Supported}->{$Param{Search}->{Field}}->{Operators},
            Supplement     => $Supplement,
            IsStaticSearch => $IsStaticSearch
        );

        return if !@Where;

        push( @SQLWhere, @Where);
    }

    return {
        Join  => \@SQLJoin,
        Where => \@SQLWhere,
    };
}

=item Sort()

run this module and return the SQL extensions

    my $Result = $Object->Sort(
        Attribute => '...'      # required
    );

    $Result = {
        Select   => [ ],          # optional
        OrderBy => [ ]           # optional
    };

=cut

sub Sort {
    my ( $Self, %Param ) = @_;

    # map search attributes to table attributes
    my %AttributeMapping = (
        'ArticleID'         => 'art.id',
        'ChannelID'         => 'art.channel_id',
        'SenderTypeID'      => 'art.sender_type_id',
        'CustomerVisible'   => 'art.customer_visible',
        'From'              => 'art.a_from',
        'To'                => 'art.a_to',
        'Cc'                => 'art.a_cc',
        'Subject'           => 'art.a_subject',
        'Body'              => 'art.a_body',
        'ArticleCreateTime' => 'art.incoming_time',
    );

    # check if we have to add a join
    my @SQLJoin;
    if (
        !$Param{Flags}->{ArticleJoined}
        || !$Param{Flags}->{ArticleJoined}->{AND}
    ) {

        # use appropriate table for selected search index module
        my $ArticleSearchTable = 'article';
        my $SearchIndexModule = $Kernel::OM->Get('Config')->Get('Ticket::SearchIndexModule');
        if ( $SearchIndexModule =~ /::StaticDB$/ ) {
            $ArticleSearchTable = 'article_search';
        }

        push( @SQLJoin, 'INNER JOIN '.$ArticleSearchTable.' art ON st.id = art.ticket_id' );
    }

    return {
        Select => [
            $AttributeMapping{$Param{Attribute}}
        ],
        OrderBy => [
            $AttributeMapping{$Param{Attribute}}
        ],
        Join  => \@SQLJoin
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
