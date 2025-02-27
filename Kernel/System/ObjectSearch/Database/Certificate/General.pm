# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Certificate::General;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Certificate::General - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Subject => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Issuer => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Email => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Fingerprint => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        },
        CType => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        },
        Type => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        },
        Modulus => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        },
        Hash => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # check for needed joins
    my @SQLJoin = ();
    my $JoinFlag = 'JoinCertificate' . $Param{Search}->{Field};
    my $TableAlias = $Param{Flags}->{JoinMap}->{ $JoinFlag } // 'vfsp';
    if ( !$Param{Flags}->{JoinMap}->{ $JoinFlag } ) {
        my $Count = $Param{Flags}->{CertificateJoinCounter}++;
        $TableAlias .= $Count;
        push(
            @SQLJoin,
            "INNER JOIN virtual_fs_preferences $TableAlias ON $TableAlias.virtual_fs_id = vfs.id",
            "AND $TableAlias.preferences_key = '$Param{Search}->{Field}'"
        );

        $Param{Flags}->{JoinMap}->{ $JoinFlag } = $TableAlias;
    }

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator        => $Param{Search}->{Operator},
        Column          => "$TableAlias.preferences_value",
        Value           => $Param{Search}->{Value},
        Silent          => $Param{Silent},
        CaseInsensitive => 1,
        NULLValue       => 1
    );
    return if ( !$Condition );

    # return search def
    return {
        Join  => \@SQLJoin,
        Where => [ $Condition ]
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSortParams( %Param ) );

    my $Attr = $Param{Attribute};
    # init mapping
    my %AttributeMapping = (
        Subject => {
            Select   => 'preferences_value AS csubject',
            OrderBy  => 'csubject'
        },
        Issuer => {
            Select   => 'preferences_value AS cissuer',
            OrderBy  => 'cissuer'
        },
        CType => {
            Select   => 'preferences_value AS cctype',
            OrderBy  => 'cctype'
        },
        Email => {
            Select   => 'preferences_value AS cemail',
            OrderBy  => 'cemail'
        },
        Fingerprint => {
            Select   => 'preferences_value AS cfingerprint',
            OrderBy  => 'cfingerprint'
        },
        Type => {
            Select   => 'preferences_value AS ctype',
            OrderBy  => 'ctype'
        },
        Modulus => {
            Select   => 'preferences_value AS cmodulus',
            OrderBy  => 'cmodulus'
        },
        Hash => {
            Select   => 'preferences_value AS chash',
            OrderBy  => 'chash'
        }
    );

    # check for needed joins
    my @SQLJoin    = ();
    my $JoinFlag   = 'JoinCertificate' . $Attr;
    my $TableAlias = $Param{Flags}->{JoinMap}->{ $JoinFlag } // 'vfsp';
    if ( !$Param{Flags}->{JoinMap}->{ $JoinFlag } ) {
        my $Count = $Param{Flags}->{CertificateJoinCounter}++;
        $TableAlias .= $Count;

        push(
            @SQLJoin,
            "INNER JOIN virtual_fs_preferences $TableAlias ON $TableAlias.virtual_fs_id = vfs.id",
            "AND $TableAlias.preferences_key = '$Attr'"
        );

        $Param{Flags}->{JoinMap}->{ $JoinFlag } = $TableAlias;
    }

    # return sort def
    return {
        Join    => \@SQLJoin,
        Select  => [ $TableAlias . q{.} . $AttributeMapping{ $Attr }->{Select} ],
        OrderBy => [ $AttributeMapping{ $Attr }->{OrderBy} ]
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
