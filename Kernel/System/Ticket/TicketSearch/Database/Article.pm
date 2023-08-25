# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::Article;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Ticket::TicketSearch::Database::Common
);

our @ObjectDependencies = (
    'Config',
    'Log',
);

=head1 NAME

Kernel::System::Ticket::TicketSearch::Database::Article - attribute module for database ticket search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Search => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Search => [
            'ArticleID',
            'ChannelID',
            'SenderTypeID',
            'CustomerVisible',
            'From',
            'To',
            'Cc',
            'Subject',
            'Body',
            'ArticleCreateTime'
        ],
        Sort => [
            'ChannelID',
            'SenderTypeID',
            'CustomerVisible',
            'From',
            'To',
            'Cc',
            'Subject',
            'Body',
            'ArticleCreateTime'
        ]
    }
}

=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        BoolOperator => 'AND' | 'OR',
        Search       => {}
    );

    $Result = {
        SQLJoin    => [ ],
        SQLWhere   => [ ],
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
    if ( !$Self->{ModuleData}->{AlreadyJoined} || !$Self->{ModuleData}->{AlreadyJoined}->{$Param{BoolOperator}} ) {
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
        $Self->{ModuleData}->{AlreadyJoined}->{$Param{BoolOperator}} = 1;
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

        my %OperatorMap = (
            'EQ'  => '=',
            'LT'  => '<',
            'GT'  => '>',
            'LTE' => '<=',
            'GTE' => '>='
        );

        if ( !$OperatorMap{$Param{Search}->{Operator}} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unsupported Operator $Param{Search}->{Operator}!",
            );
            return;
        }

        if ( $Param{BoolOperator} eq 'OR') {
            push( @SQLWhere, 'art_left.incoming_time '.$OperatorMap{$Param{Search}->{Operator}}.' '.$Value );
        } else {
            push( @SQLWhere, 'art.incoming_time '.$OperatorMap{$Param{Search}->{Operator}}.' '.$Value );
        }
    }
    elsif ( $Param{Search}->{Field} =~ /ArticleID|ChannelID|SenderTypeID|CustomerVisible/ ) {

        my %OperatorMap = (
            'EQ'  => '=',
            'LT'  => '<',
            'GT'  => '>',
            'LTE' => '<=',
            'GTE' => '>=',
            'IN'  => 'IN',
        );

        if ( !$OperatorMap{$Param{Search}->{Operator}} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unsupported Operator $Param{Search}->{Operator}!",
            );
            return;
        }

        # prepare Value if needed
        my $Value = $Param{Search}->{Value};
        if ( $Param{Search}->{Operator} eq 'IN' ) {
            $Value = '('.(join(',', @{$Value})).')';
        } elsif ( $Param{Search}->{Operator} eq 'EQ' && IsArrayRefWithData($Value) ) {
            $Value = $Value->[0];
        }

        if ( $Param{BoolOperator} eq 'OR') {
            push( @SQLWhere, 'art_left.'.$AttributeMapping{$Param{Search}->{Field}}.' '.$OperatorMap{$Param{Search}->{Operator}}.' '.$Value );
        } else {
            push( @SQLWhere, 'art.'.$AttributeMapping{$Param{Search}->{Field}}.' '.$OperatorMap{$Param{Search}->{Operator}}.' '.$Value );
        }
    }
    else {
        my $Field      = $AttributeMapping{$Param{Search}->{Field}};
        my $FieldValue = $Param{Search}->{Value};

        if ( $Param{Search}->{Operator} eq 'EQ' ) {
            # no special handling
        }
        elsif ( $Param{Search}->{Operator} eq 'STARTSWITH' ) {
            $FieldValue = $FieldValue.'%';
        }
        elsif ( $Param{Search}->{Operator} eq 'ENDSWITH' ) {
            $FieldValue = '%'.$FieldValue;
        }
        elsif ( $Param{Search}->{Operator} eq 'CONTAINS' ) {
            $FieldValue = '%'.$FieldValue.'%';
        }
        elsif ( $Param{Search}->{Operator} eq 'LIKE' ) {
            $FieldValue =~ s/\*/%/g;
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unsupported Operator $Param{Search}->{Operator}!",
            );
            return;
        }

        if ( $Param{BoolOperator} eq 'OR') {
            my @Where = $Self->_prepareField(
                Field          => 'art_left.' . $Field,
                FieldValue     => $FieldValue,
                IsStaticSearch => $IsStaticSearch
            );

            my $FieldQuery = $Where[0] . ' LIKE ' . $Where[1];
            if ( $Param{UserType} eq 'Customer' ) {
                $FieldQuery = '(' . $Where[0] . ' LIKE ' . $Where[1] . ' AND art_left.customer_visible = 1)';
            }
            push( @SQLWhere, $FieldQuery );

        } else {
            my @Where = $Self->_prepareField(
                Field          => 'art.' . $Field,
                FieldValue     => $FieldValue,
                IsStaticSearch => $IsStaticSearch
            );

            my $FieldQuery = $Where[0] . ' LIKE ' . $Where[1];
            if ( $Param{UserType} eq 'Customer' ) {
                $FieldQuery = '(' . $Where[0] . ' LIKE ' . $Where[1] . ' AND art.customer_visible = 1)';
            }
            push( @SQLWhere, $FieldQuery );
        }
    }

    return {
        SQLJoin  => \@SQLJoin,
        SQLWhere => \@SQLWhere,
    };
}

=item Sort()

run this module and return the SQL extensions

    my $Result = $Object->Sort(
        Attribute => '...'      # required
    );

    $Result = {
        SQLAttrs   => [ ],          # optional
        SQLOrderBy => [ ]           # optional
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
    if ( !$Self->{ModuleData}->{AlreadyJoined} || !$Self->{ModuleData}->{AlreadyJoined}->{AND} ) {

        # use appropriate table for selected search index module
        my $ArticleSearchTable = 'article';
        my $SearchIndexModule = $Kernel::OM->Get('Config')->Get('Ticket::SearchIndexModule');
        if ( $SearchIndexModule =~ /::StaticDB$/ ) {
            $ArticleSearchTable = 'article_search';
        }

        push( @SQLJoin, 'INNER JOIN '.$ArticleSearchTable.' art ON st.id = art.ticket_id' );
    }

    return {
        SQLAttrs => [
            $AttributeMapping{$Param{Attribute}}
        ],
        SQLOrderBy => [
            $AttributeMapping{$Param{Attribute}}
        ],
        SQLJoin  => \@SQLJoin
    };
}

sub _prepareField {
    my ( $Self, %Param ) = @_;

    my $Field = $Param{Field};
    my $FieldValue = $Param{FieldValue};

    # check if database supports LIKE in large text types (in this case for body)
    if ( !$Param{IsStaticSearch} && $Self->{DBObject}->GetDatabaseFunction('CaseSensitive') ) {
        # lower attributes if we don't do a static search
        if ( $Self->{DBObject}->GetDatabaseFunction('LcaseLikeInLargeText') ) {
            $Field      = "LCASE($Field)";
            $FieldValue = "LCASE('$FieldValue')";
        } else {
            $Field      = "LOWER($Field)";
            $FieldValue = "LOWER('$FieldValue')";
        }
    } else {
        $FieldValue = "'$FieldValue'";
        if ( $Param{IsStaticSearch} ) {
            # lower search pattern if we use static search
            $FieldValue = lc($FieldValue);
        }
    }

    return ($Field, $FieldValue);
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
