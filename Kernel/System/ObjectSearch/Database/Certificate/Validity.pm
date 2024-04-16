# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Certificate::Validity;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Certificate::Validity - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        StartDate => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE']
        },
        EndDate => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE']
        },
        ShortStartDate => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE']
        },
        ShortEndDate => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE']
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # init mapping
    my %AttributeMapping = (
        StartDate => {
            PrefKey => 'StartDate'
        },
        EndDate => {
            PrefKey => 'EndDate'
        },
        ShortStartDate => {
            PrefKey => 'ShortStartDate'
        },
        ShortEndDate => {
            PrefKey => 'ShortEndDate'
        }
    );

    # check for needed joins
    my @SQLJoin = ();
    if ( !$Param{Flags}->{JoinMap}->{CertificatePreference} ) {
        push( @SQLJoin, 'INNER JOIN virtual_fs_preferences vfsp ON vfsp.virtual_fs_id = vfs.id' );

        $Param{Flags}->{JoinMap}->{CertificatePreference} = 1;
    }

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator    => $Param{Search}->{Operator},
        Column      => 'vfsp.preferences_value',
        Value       => $Param{Search}->{Value},
        Silent      => $Param{Silent},
        NULLValue   => 1,
        Supplement  => 'vfsp.preferences_key = ' . $AttributeMapping{ $Param{Search}->{Field} }->{PrefKey}
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
        StartDate => {
            JoinType => 'CertificateStartDate',
            Select   => 'preferences_value AS cstartdate',
            OrderBy  => 'cstartdate'
        },
        EndDate => {
            JoinType => 'CertificateEndDate',
            Select   => 'preferences_value AS cenddate',
            OrderBy  => 'cenddate'
        },
        ShortEndDate => {
            JoinType => 'CertificateShortStart',
            Select   => 'preferences_value AS cshortstart',
            OrderBy  => 'cshortstart'
        },
        ShortStartDate => {
            JoinType => 'CertificateShortEnd',
            Select   => 'preferences_value AS cshortend',
            OrderBy  => 'cshortend'
        }
    );

    # check for needed joins
    my $JoinType = $AttributeMapping{ $Attr }->{JoinType};
    my @SQLJoin = ();
    my $TableAlias = $Param{Flags}->{JoinMap}->{ $JoinType } // 'vfsp';
    if ( !$Param{Flags}->{JoinMap}->{ $JoinType } ) {
        my $Count = $Param{Flags}->{CertificateJoinCounter}++;
        $TableAlias .= $Count;

        push(
            @SQLJoin,
            "INNER JOIN virtual_fs_preferences $TableAlias ON $TableAlias.virtual_fs_id = vfs.id",
            "AND $TableAlias.preferences_key = '$Attr'"
        );

        $Param{Flags}->{JoinMap}->{ $JoinType } = $TableAlias;
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
