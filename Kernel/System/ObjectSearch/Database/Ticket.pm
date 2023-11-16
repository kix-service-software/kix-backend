# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonObjectType
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket - object type module for object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Init()

### TODO ###

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    # init dynamic field join map as empty hash
    $Param{Flags}->{DynamicFieldJoin} = {};

    # init dynamic field join counter with 0
    $Param{Flags}->{DynamicFieldJoinCounter} = 0;

    return 1;
}

=item GetBase()

### TODO ###

=cut

sub GetBaseDef {
    my ( $Self, %Param ) = @_;

    return {
        Select => ['st.id', 'st.tn'],
        From   => ['ticket st'],
    };
}

=item GetPermissionDef()

### TODO ###

=cut

sub GetPermissionDef {
    my ( $Self, %Param ) = @_;

    my $QueueIDs = $Kernel::OM->Get('Ticket')->BasePermissionRelevantObjectIDList(
        %Param,
        Types        => ['Base::Ticket'],
        UsageContext => $Param{UserType},
        Permission   => 'READ',
    );

    if ( IsArrayRefWithData( $QueueIDs ) ) {
        return {
            Join  => [ 'INNER JOIN queue q ON q.id = st.queue_id' ],
            Where => [ 'q.id IN (' . join( q{,}, @{ $QueueIDs } ) . q{)} ]
        };
    }
    else {
        return {
            Where => [ '0=1' ]
        };
    }
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
