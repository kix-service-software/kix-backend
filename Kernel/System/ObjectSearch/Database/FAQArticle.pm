# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ObjectSearch::Database::FAQArticle;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonObjectType
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::FAQArticle - object type module for object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    # init join map as empty hash
    $Param{Flags}->{JoinMap} = {};

    # init category join counter with 0
    $Param{Flags}->{CategoryJoinCounter} = 0;

    # init dynamic field join counter with 0
    $Param{Flags}->{DynamicFieldJoinCounter} = 0;

    # init vote join counter with 0
    $Param{Flags}->{VoteJoinCounter} = 0;

    # init valid join counter with 0
    $Param{Flags}->{ValidJoinCounter} = 0;

    # init contact join counter with 0
    $Param{Flags}->{ContactJoinCounter} = 0;

    return 1;
}

sub GetBaseDef {
    my ( $Self, %Param ) = @_;

    return {
        Select  => ['f.id', 'f.f_number'],
        From    => ['faq_item f'],
        OrderBy => ['f.id ASC']
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
