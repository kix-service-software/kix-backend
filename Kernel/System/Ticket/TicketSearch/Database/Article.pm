# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
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
        'From'              => 'a_from',
        'To'                => 'a_to',
        'Cc'                => 'a_cc',
        'Subject'           => 'a_subject',
        'Body'              => 'a_body',
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
        if ( $Param{BoolOperator} eq 'OR') {
            push( @SQLJoin, 'LEFT OUTER JOIN '.$ArticleSearchTable.' art_left ON st.id = art_left.ticket_id' );
            push( @SQLJoin, 'RIGHT OUTER JOIN '.$ArticleSearchTable.' art_right ON st.id = art_right.ticket_id' );
        } else {
            push( @SQLJoin, 'INNER JOIN '.$ArticleSearchTable.' art ON st.id = art.ticket_id' );
        }
        $Self->{ModuleData}->{AlreadyJoined} = 1;
    }

    if ( $Param{Search}->{Field} =~ /ArticleCreateTime/ ) {
        # convert to unix time
        my $Value = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
            String => $Param{Search}->{Value},
        );

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

        if ( $Param{BoolOperator} eq 'OR') {
            push( @SQLWhere, 'art_left.incoming_time '.$OperatorMap{$Param{Search}->{Operator}}.' '.$Value );
            push( @SQLWhere, 'art_right.incoming_time '.$OperatorMap{$Param{Search}->{Operator}}.' '.$Value );
        } else {
            push( @SQLWhere, 'art.incoming_time '.$OperatorMap{$Param{Search}->{Operator}}.' '.$Value );
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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
            push( @SQLWhere, $Where[0] . ' LIKE ' . $Where[1] );
            @Where = $Self->_prepareField(
                Field          => 'art_right.' . $Field,
                FieldValue     => $FieldValue,
                IsStaticSearch => $IsStaticSearch
            );
            push( @SQLWhere, $Where[0] . ' LIKE ' . $Where[1] );
        } else {
            my @Where = $Self->_prepareField(
                Field          => 'art.' . $Field,
                FieldValue     => $FieldValue,
                IsStaticSearch => $IsStaticSearch
            );
            push( @SQLWhere, $Where[0] . ' LIKE ' . $Where[1] );
        }
    }
    
    # restrict search from customers to only customer articles
    if ( $Param{UserType} eq 'Customer' ) {
        if ( $Param{BoolOperator} eq 'OR') {
            push( @SQLWhere, 'art_left.customer_visible = 1' );
            push( @SQLWhere, 'art_right.customer_visible = 1' );
        } else {
            push( @SQLWhere, 'art.customer_visible = 1' );
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
