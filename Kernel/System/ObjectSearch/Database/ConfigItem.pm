# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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

    # init translation join counter with 0
    $Param{Flags}->{TranslationJoinCounter} = 0;

    # extract flags from fields
    $Self->_CheckFields(
        %Param,
        Extract => {
            PreviousVersionSearch => 1
        },
        Draft => {
            AssignedOrganisation  => 1,
            AssignedContact       => 1
        }
    );

    return 1;
}

sub GetBaseDef {
    my ( $Self, %Param ) = @_;

    return {
        Select  => ['ci.id', 'ci.configitem_number'],
        From    => ['configitem ci'],
        OrderBy => ['ci.id ASC']
    };
}

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    my @List;
    for my $Attribute ( sort keys %{$Self->{AttributeMapping}} ) {
        my $Module    = $Self->{AttributeMapping}->{$Attribute};
        my $Property  = $Attribute;

        if ( IsArrayRefWithData($Module->{Class})) {
            for my $Index ( keys @{$Module->{Class}} ) {
                push (
                    @List,
                    {
                        ObjectType      => $Self->{ObjectType},
                        Property        => $Property,
                        ObjectSpecifics => {
                            ClassID => $Module->{ClassID}->[$Index],
                            Class   => $Module->{Class}->[$Index]
                        },
                        IsSearchable    => $Module->{IsSearchable} || 0,
                        IsSortable      => $Module->{IsSortable}   || 0,
                        Operators       => $Module->{Operators}    || [],
                        ValueType       => $Module->{ValueType}    || ''
                    }
                );
            }
        } else {
            push (
                @List,
                {
                    ObjectType      => $Self->{ObjectType},
                    Property        => $Property,
                    ObjectSpecifics => {
                        ClassID => undef,
                        Class   => undef
                    },
                    IsSearchable    => $Module->{IsSearchable} || 0,
                    IsSortable      => $Module->{IsSortable}   || 0,
                    Operators       => $Module->{Operators}    || [],
                    ValueType       => $Module->{ValueType}    || ''
                }
            );
        }
    }

    if ( @List ) {
        @List = sort(
            {
                $a->{Property} cmp $b->{Property}
                && ( $a->{ObjectSpecifics}->{Class} || q{} ) cmp ( $b->{ObjectSpecifics}->{Class} || q{} )
            }
            @List
        );
    }

    return \@List;
}


=begin Internal:

=cut

sub _CheckFields {
    my ($Self, %Param) = @_;

    for my $Type ( keys %{$Param{Search}} ) {
        my @Items;
        for my $SearchItem ( @{$Param{Search}->{$Type}} ) {
            if ( $Param{Draft}->{$SearchItem->{Field}} ) {
                $Param{Flags}->{$SearchItem->{Field}} = $SearchItem->{Value};
            }

            if ($Param{Extract}->{$SearchItem->{Field}}) {
                $Param{Flags}->{$SearchItem->{Field}} = $SearchItem->{Value};
            }
            else {
                push(@Items, $SearchItem);
            }
        }
        if ( scalar(@Items) ) {
            $Param{Search}->{$Type} = \@Items;
        }
        else {
            delete $Param{Search}->{$Type};
        }
    }

    return 1;
}

=end Internal:

=cut

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
