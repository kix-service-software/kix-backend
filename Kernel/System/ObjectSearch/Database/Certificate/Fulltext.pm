# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Certificate::Fulltext;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Certificate::Fulltext - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Fulltext => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['LIKE']
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # init search parameter for fulltext search
    my %Search = (
        OR => []
    );

    my %AttributeMapping = (
        Fulltext => {
            Fields => [
                'Subject',
                'Email'
            ]
        }
    );

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
            "AND $TableAlias.preferences_key IN ('Subject','Email')"
        );

        $Param{Flags}->{JoinMap}->{ $JoinFlag } = $TableAlias;
    }

    # prepare condition
    # fixed search in the  following columns:
    # preferences_value (depending on the table prefix and requested preferences_key)
    my $Condition = $Self->_FulltextCondition(
        Columns => [ "$TableAlias.preferences_value" ],
        Value   => $Param{Search}->{Value},
        Silent  => $Param{Silent}
    );

    return if ( !$Condition );

    # return search def
    return {
        Join  => \@SQLJoin,
        Where => [ $Condition ]
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
