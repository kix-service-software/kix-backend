# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Role;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonObjectType
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Role - object type module for object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    # init join map as empty hash
    $Param{Flags}->{JoinMap} = {};

    # init translation join counter with 0
    $Param{Flags}->{TranslationJoinCounter} = 0;

    # init role_permission join counter with 0
    $Param{Flags}->{RolePermissionJoinCounter} = 0;

    # init permission_type join counter with 0
    $Param{Flags}->{PermissionTypeJoinCounter} = 0;

    # init valid join counter with 0
    $Param{Flags}->{ValidJoinCounter} = 0;

    return 1;
}

sub GetBaseDef {
    my ( $Self, %Param ) = @_;

    return {
        Select  => ['r.id', 'r.name'],
        From    => ['roles r'],
        OrderBy => ['r.id ASC']
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
