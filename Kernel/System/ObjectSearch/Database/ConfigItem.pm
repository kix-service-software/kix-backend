# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::ConfigItem;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonObjectType
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::ConfigItem::Base - object type module for object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    # init join map as empty hash
    $Param{Flags}->{JoinMap} = {};

    # init xml storage join counter with 0
    $Param{Flags}->{XMLStorageJoinCounter} = 0;

    # init translation join counter with 0
    $Param{Flags}->{TranslationJoinCounter} = 0;

    return 1;
}

sub GetBaseDef {
    my ( $Self, %Param ) = @_;

    return {
        Select  => ['ci.id', 'ci.configitem_number'],
        From    => ['configitem ci'],
        OrderBy => ['ci.id ASC'],
        Extract => {
            PreviousVersionSearch => 0,
            AssignedOrganisation  => 1,
            AssignedContact       => 1
        }
    };
}

sub _GetObjectSpecifics {
    my ( $Self, %Param ) = @_;

    my $ClassEntries = undef;
    if ( IsArrayRefWithData( $Param{AttributeRef}->{Class} ) ) {
        $ClassEntries = [];

        for my $Index ( sort { $Param{AttributeRef}->{Class}->[ $a ] cmp $Param{AttributeRef}->{Class}->[ $b ] } ( keys( @{ $Param{AttributeRef}->{Class} } ) ) ) {
            push(
                @{ $ClassEntries },
                {
                    ClassID => $Param{AttributeRef}->{ClassID}->[ $Index ],
                    Class   => $Param{AttributeRef}->{Class}->[ $Index ]
                }
            );
        }
    }
    else {
        $ClassEntries = {
            ClassID => undef,
            Class   => undef
        }
    }

    return $ClassEntries;
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
