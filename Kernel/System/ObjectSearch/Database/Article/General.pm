# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ObjectSearch::Database::Article::General;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Article::General - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        CustomerVisible   => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        From              => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        To                => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Cc                => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Subject           => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Body              => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # init mapping
    my %AttributeMapping = (
        CustomerVisible   => {
            Column          => 'a.customer_visible',
            ValueType       => 'NUMERIC'
        },
        From              => {
            Column          => 'a.a_from',
            CaseInsensitive => 1
        },
        To                => {
            Column          => 'a.a_to',
            CaseInsensitive => 1
        },
        Cc                => {
            Column          => 'a.a_cc',
            CaseInsensitive => 1
        },
        Subject           => {
            Column          => 'a.a_subject',
            CaseInsensitive => 1
        },
        Body              => {
            Column          => 'a.a_body',
            CaseInsensitive => 1
        }
    );

    # prepare given values as array ref and convert if required
    my $Values = [];
    if ( !IsArrayRef( $Param{Search}->{Value} ) ) {
        push( @{ $Values },  $Param{Search}->{Value}  );
    }
    else {
        $Values =  $Param{Search}->{Value} ;
    }

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator        => $Param{Search}->{Operator},
        Column          => $AttributeMapping{ $Param{Search}->{Field} }->{Column},
        ValueType       => $AttributeMapping{ $Param{Search}->{Field} }->{ValueType},
        CaseInsensitive => $AttributeMapping{ $Param{Search}->{Field} }->{CaseInsensitive},
        Value           => $Values,
        NULLValue       => 1,
        Silent          => $Param{Silent}
    );
    return if ( !$Condition );

    return {
        Where => [ $Condition ]
    };
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
