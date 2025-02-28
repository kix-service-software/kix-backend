# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Organisation::Times;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Organisation::Times - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        CreateTime => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType    => 'DATETIME'
        },
        ChangeTime => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType    => 'DATETIME'
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # init mapping
    my %AttributeMapping = (
        CreateTime => 'o.create_time',
        ChangeTime => 'o.change_time',
    );

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator  => $Param{Search}->{Operator},
        Column    => $AttributeMapping{ $Param{Search}->{Field} },
        Value     => $Param{Search}->{Value},
        Silent    => $Param{Silent}
    );
    return if ( !$Condition );

    # return search def
    return {
        Where      => [ $Condition ],
        IsRelative => $Param{Search}->{IsRelative}
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSortParams(%Param) );

    # init mapping
    my %AttributeMapping = (
        CreateTime => 'o.create_time',
        ChangeTime => 'o.change_time',
    );

    # return sort def
    return {
        Select  => [ $AttributeMapping{ $Param{Attribute} } ],
        OrderBy => [ $AttributeMapping{ $Param{Attribute} } ]
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
