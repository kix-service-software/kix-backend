# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Organisation::Editor;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Organisation::Editor - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        CreateByID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        CreateBy => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
## TODO: login based search instead of id
#            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ChangeByID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        ChangeBy => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
## TODO: login based search instead of id
#            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # init mapping
    my %AttributeMapping = (
        CreateByID => {
            Column          => 'o.create_by',
            ValueType       => 'NUMERIC'
        },
        CreateBy   => {
            Column          => 'o.create_by',
            ValueType       => 'NUMERIC'
## TODO: login based search instead of id
#            Column          => 'ocru.login',
#            CaseInsensitive => 1
        },
        ChangeByID => {
            Column          => 'o.change_by',
            ValueType       => 'NUMERIC'
        },
        ChangeBy   => {
            Column          => 'o.change_by',
            ValueType       => 'NUMERIC'
## TODO: login based search instead of id
#            Column    => 'ochu.login',
#            CaseInsensitive => 1
        }
    );

## TODO: login based search instead of id
#    # check for needed joins
#    my @SQLJoin = ();
#    if ( $Param{Search}->{Field} eq 'CreateBy' ) {
#        if ( !$Param{Flags}->{JoinMap}->{OrganisationCreateBy} ) {
#            push( @SQLJoin, 'INNER JOIN users ocru ON ocru.id = o.create_by' );
#
#            $Param{Flags}->{JoinMap}->{OrganisationCreateBy} = 1;
#        }
#    }
#    elsif ( $Param{Search}->{Field} eq 'ChangeBy' ) {
#        if ( !$Param{Flags}->{JoinMap}->{OrganisationChangeBy} ) {
#            push( @SQLJoin, 'INNER JOIN users ochu ON ochu.id = o.change_by' );
#
#            $Param{Flags}->{JoinMap}->{OrganisationChangeBy} = 1;
#        }
#    }

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator        => $Param{Search}->{Operator},
        Column          => $AttributeMapping{ $Param{Search}->{Field} }->{Column},
        ValueType       => $AttributeMapping{ $Param{Search}->{Field} }->{ValueType},
## TODO: login based search instead of id
#        CaseInsensitive => $AttributeMapping{ $Param{Search}->{Field} }->{CaseInsensitive},
        Value           => $Param{Search}->{Value},
        Silent          => $Param{Silent}
    );
    return if ( !$Condition );

    # return search def
    return {
## TODO: login based search instead of id
#        Join  => \@SQLJoin,
        Where => [ $Condition ]
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSortParams( %Param ) );

    # check for needed joins
    my @SQLJoin = ();
    if ( $Param{Attribute} eq 'CreateBy' ) {
        if ( !$Param{Flags}->{JoinMap}->{OrganisationCreateBy} ) {
            push( @SQLJoin, 'INNER JOIN users ocru ON ocru.id = o.create_by' );

            $Param{Flags}->{JoinMap}->{OrganisationCreateBy} = 1;
        }
        if ( !$Param{Flags}->{JoinMap}->{OrganisationCreateByContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact ocruc ON ocruc.user_id = ocru.id' );

            $Param{Flags}->{JoinMap}->{OrganisationCreateByContact} = 1;
        }
    }
    if ( $Param{Attribute} eq 'ChangeBy' ) {
        if ( !$Param{Flags}->{JoinMap}->{OrganisationChangeBy} ) {
            push( @SQLJoin, 'INNER JOIN users ochu ON ochu.id = o.change_by' );

            $Param{Flags}->{JoinMap}->{OrganisationChangeBy} = 1;
        }
        if ( !$Param{Flags}->{JoinMap}->{OrganisationChangeByContact} ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact ochuc ON ochuc.user_id = ochu.id' );

            $Param{Flags}->{JoinMap}->{OrganisationChangeByContact} = 1;
        }
    }

    # init mapping
    my %AttributeMapping = (
        CreateByID => {
            Select  => ['o.create_by'],
            OrderBy => ['o.create_by']
        },
        CreateBy   => {
            Select  => ['ocruc.lastname','ocruc.firstname','ocru.login'],
            OrderBy => ['LOWER(ocruc.lastname)','LOWER(ocruc.firstname)','LOWER(ocru.login)']
        },
        ChangeByID => {
            Select  => ['o.change_by'],
            OrderBy => ['o.change_by']
        },
        ChangeBy   => {
            Select  => ['ochuc.lastname','ochuc.firstname','ochu.login'],
            OrderBy => ['LOWER(ochuc.lastname)','LOWER(ochuc.firstname)','LOWER(ochu.login)']
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
