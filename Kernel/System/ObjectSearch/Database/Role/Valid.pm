# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Role::Valid;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Role::Valid - attribute module for database object search

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
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN']
        },
        ValidID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN'],
            ValueType      => 'NUMERIC'
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # check for needed joins
    my $TableAliasTLP = 'tlp' . ( $Param{Flags}->{JoinMap}->{TranslationRoleValid} // '' );
    my $TableAliasTL  = 'tl' . ( $Param{Flags}->{JoinMap}->{TranslationRoleValid} // '' );
    my @SQLJoin = ();
    if ( $Param{Attribute} eq 'Valid' ) {
        if ( !$Param{Flags}->{JoinMap}->{RoleValid} ) {
            push( @SQLJoin, 'INNER JOIN valid rv ON rv.id = r.valid_id' );
            $Param{Flags}->{JoinMap}->{RoleValid} = 1;
        }

        if ( $Param{PrepareType} eq 'Sort' ) {
            if ( !defined( $Param{Flags}->{JoinMap}->{TranslationRoleValid} ) ) {
                my $Count = $Param{Flags}->{TranslationJoinCounter}++;
                $TableAliasTLP .= $Count;
                $TableAliasTL  .= $Count;

                push( @SQLJoin, "LEFT OUTER JOIN translation_pattern $TableAliasTLP ON $TableAliasTLP.value = rv.name" );
                push( @SQLJoin, "LEFT OUTER JOIN translation_language $TableAliasTL ON $TableAliasTL.pattern_id = $TableAliasTLP.id AND $TableAliasTL.language = '$Param{Language}'" );

                $Param{Flags}->{JoinMap}->{TranslationRoleValid} = $Count;
            }
        }
    }

    # init Definition
    my %AttributeDefinition = (
        ValidID         => {
            Column       => 'r.valid_id',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        Valid => {
            Column       => 'rv.name',
            ConditionDef => {
                ValueType => 'STRING'
            }
        }
    );
    
    my %Attribute = (
        Column => $AttributeDefinition{ $Param{Attribute} }->{Column},
        SQLDef => {
            Join => \@SQLJoin
        }
    );
    if ( $Param{PrepareType} eq 'Condition' ) {
        $Attribute{ConditionDef} = $AttributeDefinition{ $Param{Attribute} }->{ConditionDef};
    }
    elsif ( $Param{PrepareType} eq 'Sort' ) {
        if ( $Param{Attribute} eq 'Valid' ) {
            $Attribute{Column} = 'LOWER(COALESCE(' . $TableAliasTL . '.value, rv.name))';
        }
    }

    return \%Attribute;
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
