# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::Article;

use strict;
use warnings;

use base qw(
    Kernel::System::Ticket::TicketSearch::Database::Common
);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
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
            'From',
            'To',
            'Cc',
            'Subject',
            'Body',
            'ArticleCreateTime'
        ],
        Sort => [
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    # map search attributes to table attributes
    my %AttributeMapping = (
        'From'              => 'art.a_from',
        'To'                => 'art.a_to',
        'Cc'                => 'art.a_cc',
        'Subject'           => 'art.a_subject',
        'Body'              => 'art.a_body',
    );

    my %JoinType = (
        'AND' => 'INNER',
        'OR'  => 'FULL OUTER'
    );

    my $IsStaticSearch = 0;
    my $SearchIndexModule = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::SearchIndexModule');
    if ( $SearchIndexModule =~ /::StaticDB$/ ) {
        $IsStaticSearch = 1;
    }

    # check if we have to add a join
    if ( !$Self->{ModuleData}->{AlreadyJoined} ) {
        # use appropriate table for selected search index module
        my $ArticleSearchTable = 'article';
        if ( $IsStaticSearch ) {
            $ArticleSearchTable = 'article_search';
        }
        push( @SQLJoin, $JoinType{$Param{BoolOperator}}.' JOIN '.$ArticleSearchTable.' art ON st.id = art.ticket_id' );
        $Self->{ModuleData}->{AlreadyJoined} = 1;
    }

    if ( $Param{Search}->{Field} =~ /ArticleCreateTime/ ) {
        # convert to unix time
        my $Value = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
            String => $Param{Search}->{Value},
        );

        if ( !$Value || $Value > $Kernel::OM->Get('Kernel::System::Time')->SystemTime() ) {
            # return in case of some format error or if the date is in the future
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Unsupported Operator $Param{Search}->{Operator}!",
            );
            return;
        }

        push( @SQLWhere, 'art.incoming_time '.$OperatorMap{$Param{Search}->{Operator}}.' '.$Value );
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Unsupported Operator $Param{Search}->{Operator}!",
            );
            return;
        }

        # check if database supports LIKE in large text types (in this case for body)
        if ( !$IsStaticSearch && $Self->{DBObject}->GetDatabaseFunction('CaseSensitive') ) {
            # lower attributes if we don't do a static search
            if ( $Self->{DBObject}->GetDatabaseFunction('LcaseLikeInLargeText') ) {
                $Field      = "LCASE($Field)";
                $FieldValue = "LCASE('$FieldValue')";
            }
            else {
                $Field      = "LOWER($Field)";
                $FieldValue = "LOWER('$FieldValue')";
            }
        }
        else {
            $FieldValue = "'$FieldValue'";
            if ( $IsStaticSearch ) {
                # lower search pattern if we use static search
                $FieldValue = lc($FieldValue);
            }
        }

        push( @SQLWhere, $Field.' LIKE '.$FieldValue );
    }
    
    # restrict search from customers to only customer articles
    if ( $Param{UserType} eq 'Customer' ) {
        my %CustomerArticleTypes = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleTypeList(
            Result => 'HASH',
            Type   => 'Customer',
        );
        my @CustomerArticleTypeIDs = keys %CustomerArticleTypes;

        if ( @CustomerArticleTypeIDs ) {
            push( @SQLWhere, 'art.article_type_id IN ('.(join(', ', sort @CustomerArticleTypeIDs)).')' );
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
        'From'              => 'art.a_from',
        'To'                => 'art.a_to',
        'Cc'                => 'art.a_cc',
        'Subject'           => 'art.a_subject',
        'Body'              => 'art.a_body',
        'ArticleCreateTime' => 'art.incoming_time',
    );

    return {
        SQLAttrs => [
            $AttributeMapping{$Param{Attribute}}
        ],
        SQLOrderBy => [
            $AttributeMapping{$Param{Attribute}}
        ],
    };       
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
