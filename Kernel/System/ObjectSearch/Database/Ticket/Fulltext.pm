# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::Fulltext;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Fulltext - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Fulltext => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );


    # check if static search should be used. Only if search for ArticleID is NOT used and static search index is active
    my $IsStaticSearch = 0;
    my $SearchIndexModule = $Kernel::OM->Get('Config')->Get('Ticket::SearchIndexModule');
    if ( $SearchIndexModule =~ /::StaticDB$/ ) {
        $IsStaticSearch = 1;
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
    }

    # fixed search in the  following columns:
    # Ticketnumber and Title
    # inlcudes related columns of other tables:
    # table article: To, Cc, From, Body and Subject
    my $Condition = $Self->_FulltextCondition(
        Operator       => $Param{Search}->{Operator},
        Value          => $Param{Search}->{Value},
        Columns        => [
            'st.tn', 'st.title', $TableAliasPrefix . 'ta.a_to', $TableAliasPrefix . 'ta.a_cc',
            $TableAliasPrefix . 'ta.a_from', $TableAliasPrefix . 'ta.a_body',
            $TableAliasPrefix . 'ta.a_subject'
        ],
        Silent         => $Param{Silent},
        IsStaticSearch => $IsStaticSearch
    );

    return if ( !$Condition );

    return {
        Join  => \@SQLJoin,
        Where => [$Condition]
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
