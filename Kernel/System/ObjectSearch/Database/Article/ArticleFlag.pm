# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ObjectSearch::Database::Article::ArticleFlag;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Article::ArticleFlag - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        'ArticleFlag.Seen' => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE']
        },
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # get requested flag
    my $Flag = $Param{Search}->{Field};
    $Flag =~ s/^ArticleFlag\.//;

    # check for needed joins
    my $TableAlias = 'af_left' . ( $Param{Flags}->{JoinMap}->{ 'ArticleFlag_' . $Flag } // '' );
    my @SQLJoin = ();
    if ( !defined( $Param{Flags}->{JoinMap}->{ 'ArticleFlag_' . $Flag } ) ) {
        my $Count = $Param{Flags}->{ArticleFlagJoinCounter}++;
        $TableAlias .= $Count;
        push( @SQLJoin, "LEFT OUTER JOIN article_flag $TableAlias ON $TableAlias.article_id = a.id AND $TableAlias.article_key = \'$Flag\' AND af_left0.create_by = $Param{UserID}" );

        $Param{Flags}->{JoinMap}->{ 'ArticleFlag_' . $Flag } = $Count;
    }

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator   => $Param{Search}->{Operator},
        Column     => "$TableAlias.article_value",
        Value      => $Param{Search}->{Value},
        NULLValue  => 1,
        Silent     => $Param{Silent}
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
