# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Article;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonObjectType
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Article - object type module for object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    # init join map as empty hash
    $Param{Flags}->{JoinMap} = {};

    # init flag join counter with 0
    $Param{Flags}->{ArticleFlagJoinCounter} = 0;

    # init dynamic field join counter with 0
    $Param{Flags}->{DynamicFieldJoinCounter} = 0;

    # init translation join counter with 0
    $Param{Flags}->{TranslationJoinCounter} = 0;

    return 1;
}

sub GetBaseDef {
    my ( $Self, %Param ) = @_;

    return {
        Select  => ['a.id', 'a.incoming_time'],
        From    => [ 'article a'],
        OrderBy => ['a.incoming_time ASC,a.id ASC']
    };
}

sub GetPermissionDef {
    my ( $Self, %Param ) = @_;

    # init PermissionDef
    my @PermissionDef = ();

    # restrict search from customers to customer visible articles
    if ( $Param{UserType} eq 'Customer' ) {
        push @PermissionDef, 'a.customer_visible = 1';
    }

    return {
        Where => \@PermissionDef
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
