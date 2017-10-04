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

Kernel::System::Ticket::TicketSearch::Database::History - attribute module for database ticket search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my @AttributeList = $Object->GetSupportedAttributes();

    $Result = [
        ...
    ];

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return (
        'From',
        'To',
        'Cc',
        'Subject',
        'Body',
        'AttachmentName',
        'ArticleCreateTime'
    );
}


=item Run()

run this module and return the SQL extensions

    my $Result = $Object->Run(
        Filter => {}
    );

    $Result = {
        SQLJoin    => [ ],
        SQLWhere   => [ ],
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    my @SQLJoin;
    my @SQLWhere;

    # check params
    if ( !$Param{Filter} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Filter!",
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

    # check if we have to add a join
    if ( !$Self->{AlreadyJoined} ) {
        my $SearchIndexModule = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::SearchIndexModule');
        my $ArticleSearchTable = 'article';
        if ( $SearchIndexModule =~ /::StaticDB$/ ) {
            $ArticleSearchTable = 'article_search';
        }
        push( @SQLJoin, 'INNER JOIN '.$ArticleSearchTable.' art ON st.id = art.ticket_id' );
        $Self->{AlreadyJoined} = 1;
    }

    if ( $Param{Filter}->{Field} =~ /ArticleCreateTime/ ) {
        my %OperatorMap = (
            'EQ'  => '=',
            'LT'  => '<',
            'GT'  => '>',
            'LTE' => '<=',
            'GTE' => '>='
        );

        if ( !$OperatorMap{$Param{Filter}->{Operation}} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Unsupported operation $Param{Filter}->{Operation}!",
            );
            return;
        }

        # convert to unix time
        my $Value = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
            String => $Param{Filter}->{Value},
        );

        push( @SQLWhere, 'art.incoming_time '.$OperatorMap{$Param{Filter}->{Operation}}.' '.$Value );
    }
    else {
        my $Field      = $AttributeMapping{$Param{Filter}->{Field}};
        my $FieldValue = $Param{Filter}->{Value};

        if ( $Param{Filter}->{Operation} eq 'EQ' ) {
            # no special handling
        }
        elsif ( $Param{Filter}->{Operation} eq 'STARTSWITH' ) {
            $FieldValue = $FieldValue.'%';
        }
        elsif ( $Param{Filter}->{Operation} eq 'ENDSWITH' ) {
            $FieldValue = '%'.$FieldValue;
        }
        elsif ( $Param{Filter}->{Operation} eq 'CONTAINS' ) {
            $FieldValue = '%'.$FieldValue.'%';
        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Unsupported operation $Param{Filter}->{Operation}!",
            );
            return;
        }

        # check if database supports LIKE in large text types (in this case for body)
        if ( $Self->{DBObject}->GetDatabaseFunction('CaseSensitive') ) {
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
        }

        push( @SQLWhere, $Field.' LIKE '.$FieldValue );
    }
    
    return {
        SQLJoin  => \@SQLJoin,
        SQLWhere => \@SQLWhere,
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
