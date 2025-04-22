# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::FAQArticle::Visibility;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::FAQArticle::Valid - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        CustomerVisible => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE'],
            ValueType    => 'NUMERIC'
        },
        Visibility => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    if ( $Param{Search}->{Field} eq 'CustomerVisible' ) {
        my $Value = ['internal' ];
        if ( $Param{Search}->{Value} ) {
            $Value = ['external','public' ];
        }

        return {
            Search => {
                AND => [
                    {
                        Field    => 'Visibility',
                        Operator => $Param{Search}->{Operator} eq 'EQ' ? 'IN' : '!IN',
                        Value    => $Value
                    }
                ]
            }
        };
    }

    my $Condition = $Self->_GetCondition(
        Operator  => $Param{Search}->{Operator},
        Column    => 'f.visibility',
        Value     => $Param{Search}->{Value},
        Prepare   => 1
    );

    return if ( !$Condition );

    return {
        Where => [ $Condition ]
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSortParams( %Param ) );

    my %SelectAttribute = (
        CustomerVisible => [ 'f.visibility' ],
        Visibility      => [ 'f.visibility' ]
    );

    my %OrderAttribute = (
        CustomerVisible => [
            <<'EOF'
CASE
    WHEN f.visibility = 'internal'
        OR f.visibility IS NULL
    THEN 0
    ELSE 1
END
EOF
        ],
        Visibility      => [ 'f.visibility' ]
    );

    return {
        Select  => $SelectAttribute{$Param{Attribute}},
        OrderBy => $OrderAttribute{$Param{Attribute}}
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
