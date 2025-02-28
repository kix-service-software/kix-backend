# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Contact::Valid;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our @ObjectDependencies = qw(
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Contact::Valid - attribute module for database object search

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

    return {
        Valid => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        },
        ValidID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'NUMERIC'
        }
    };
}

=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        Search => {}
    );

    $Result = {
        Where   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my @SQLJoin;

    # check params
    return if !$Self->_CheckSearchParams(%Param);

    # map search attributes to table attributes
    my %AttributeMapping = (
        ValidID => {
            Column    => 'c.valid_id',
            ValueType => 'NUMERIC'
        },
        Valid   => {
            Column    => 'cv.name'
        }
    );

    if (
        $Param{Search}->{Field} eq 'Valid'
        && !$Param{Flags}->{JoinMap}->{ContactValid}
    ) {
        push( @SQLJoin, 'INNER JOIN valid cv ON cv.id = c.valid_id' );
        $Param{Flags}->{JoinMap}->{ContactValid} = 1;
    }

    my $Condition = $Self->_GetCondition(
        Operator  => $Param{Search}->{Operator},
        Column    => $AttributeMapping{$Param{Search}->{Field}}->{Column},
        ValueType => $AttributeMapping{$Param{Search}->{Field}}->{ValueType},
        Value     => $Param{Search}->{Value},
        Silent    => $Param{Silent}
    );

    return if ( !$Condition );

    return {
        Join  => \@SQLJoin,
        Where => [ $Condition ]
    };
}

=item Sort()

run this module and return the SQL extensions

    my $Result = $Object->Sort(
        Attribute => '...'      # required
    );

    $Result = {
        Select   => [ ],          # optional
        OrderBy  => [ ]           # optional
    };

=cut

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if !$Self->_CheckSortParams(%Param);

    # check for needed joins
    my $TableAliasTLP = 'tlp' . ( $Param{Flags}->{JoinMap}->{TranslationContactValid} // '' );
    my $TableAliasTL  = 'tl' . ( $Param{Flags}->{JoinMap}->{TranslationContactValid} // '' );
    my @SQLJoin = ();
    if ( $Param{Attribute} eq 'Valid' ) {
        if ( !$Param{Flags}->{JoinMap}->{ContactValid} ) {
            push( @SQLJoin, 'INNER JOIN valid cv ON cv.id = c.valid_id' );

            $Param{Flags}->{JoinMap}->{ContactValid} = 1;
        }

        if ( !defined( $Param{Flags}->{JoinMap}->{TranslationContactValid} ) ) {
            my $Count = $Param{Flags}->{TranslationJoinCounter}++;
            $TableAliasTLP .= $Count;
            $TableAliasTL  .= $Count;

            push( @SQLJoin, "LEFT OUTER JOIN translation_pattern $TableAliasTLP ON $TableAliasTLP.value = cv.name" );
            push( @SQLJoin, "LEFT OUTER JOIN translation_language $TableAliasTL ON $TableAliasTL.pattern_id = $TableAliasTLP.id AND $TableAliasTL.language = '$Param{Language}'" );

            $Param{Flags}->{JoinMap}->{TranslationContactValid} = $Count;
        }
    }

    # init mapping
    my %AttributeMapping = (
        ValidID => {
            Select  => ['c.valid_id'],
            OrderBy => ['c.valid_id']
        },
        Valid   => {
            Select  => ["LOWER(COALESCE($TableAliasTL.value, cv.name)) AS TranslateValid"],
            OrderBy => ['TranslateValid']
        }
    );

    # return sort def
    return {
        Join    => \@SQLJoin,
        Select  => $AttributeMapping{ $Param{Attribute} }->{Select},
        OrderBy => $AttributeMapping{ $Param{Attribute} }->{OrderBy}
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
