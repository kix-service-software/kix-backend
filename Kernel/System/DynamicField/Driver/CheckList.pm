# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::CheckList;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::DynamicField::Driver::BaseText);

our @ObjectDependencies = qw(
    Config
    DynamicFieldValue
    Main
);

=head1 NAME

Kernel::System::DynamicField::Driver::CheckList

=head1 SYNOPSIS

DynamicFields CheckList Driver delegate

=head1 PUBLIC INTERFACE

This module implements the public interface of L<Kernel::System::DynamicField::Backend>.
Please look there for a detailed reference of the functions.

=over 4

=item new()

usually, you want to create an instance of this
by using Kernel::System::DynamicField::Backend->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # set the maximum length for the text-area fields to still be a searchable field in some
    # databases
    $Self->{MaxLength} = 3800;

    # set field properties
    $Self->{Properties} = {
        'IsSelectable'    => 0,
        'IsSearchable'    => 0,
        'IsSortable'      => 0,
        'IsFulltextable'  => 0,
        'SearchOperators' => []
    };

    # get the Dynamic Field Backend custom extensions
    my $DynamicFieldDriverExtensions
        = $Kernel::OM->Get('Config')->Get('DynamicFields::Extension::Driver::CheckList');

    EXTENSION:
    for my $ExtensionKey ( sort keys %{$DynamicFieldDriverExtensions} ) {

        # skip invalid extensions
        next EXTENSION if !IsHashRefWithData( $DynamicFieldDriverExtensions->{$ExtensionKey} );

        # create a extension config shortcut
        my $Extension = $DynamicFieldDriverExtensions->{$ExtensionKey};

        # check if extension has a new module
        if ( $Extension->{Module} ) {

            # check if module can be loaded
            if (
                !$Kernel::OM->Get('Main')->RequireBaseClass( $Extension->{Module} )
                )
            {
                die "Can't load dynamic fields backend module"
                    . " $Extension->{Module}! $@";
            }
        }

        # check if extension contains more properties
        if ( IsHashRefWithData( $Extension->{Properties} ) ) {

            %{ $Self->{Properties} } = (
                %{ $Self->{Properties} },
                %{ $Extension->{Properties} }
            );
        }
    }

    return $Self;
}

sub DisplayValueRender {
    my ( $Self, %Param ) = @_;

    # set HTMLOutput as default if not specified
    if ( !defined $Param{HTMLOutput} ) {
        $Param{HTMLOutput} = 1;
    }

    my $LineBreak = "\n";
    if ($Param{HTMLOutput}) {
        $LineBreak = "<br />";
    }

    # set Value and Title variables
    my $Value = $Param{DynamicFieldConfig}->{Label} . $LineBreak;
    my $Title = q{};

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    for my $ChecklistItemString ( @Values) {
        next if !$ChecklistItemString;

        my $ChecklistItems = $Kernel::OM->Get('JSON')->Decode(
            Data => $ChecklistItemString,
        );
        my $Items = $Self->_GetChecklistRows(Items => $ChecklistItems);

        if (IsArrayRefWithData($Items)) {
            for my $Item (@{$Items}) {
                $Value .= "- $Item->{Title}: $Item->{Value}$LineBreak";
            }
        }
        $Value .= $LineBreak;
    }

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title
    };

    return $Data;
}

sub HTMLDisplayValueRender {
    my ( $Self, %Param ) = @_;

    # set Value and Title variables
    my $Value = '<h3>' . $Param{DynamicFieldConfig}->{Label} . '</h3>';
    my $Title = q{};

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    for my $ChecklistItemString ( @Values) {
        next if !$ChecklistItemString;

        my $ChecklistItems = $Kernel::OM->Get('JSON')->Decode(
            Data => $ChecklistItemString,
        );
        my $Items = $Self->_GetChecklistRows(Items => $ChecklistItems);

        if (IsArrayRefWithData($Items)) {
            $Value .= '<table style="border:none; width:90%">'
                . '<thead><tr>'
                    . '<th style="padding:10px 15px;">Action</th>'
                    . '<th style="padding:10px 15px;">State</th>'
                . '<tr></thead>'
                . '<tbody>';

            for my $Item (@{$Items}) {
                my $ItemValue = $Item->{Value};
                $ItemValue =~ s/\n/<br \/>/gxsm;
                $Value .= '<tr>'
                    . '<td style="padding:10px 15px;">' . $Item->{Title} . '</td>'
                    . '<td style="padding:10px 15px;">' . $ItemValue . '</td>'
                    . '</tr>';
            }

            $Value .= '</tbody></table>';
        }
    }

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title
    };

    return $Data;
}

sub ShortDisplayValueRender {
    my ( $Self, %Param ) = @_;

    # set Value and Title variables
    my $Value = q{};
    my $Title = q{};

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    for my $ChecklistItemString ( @Values) {
        next if !$ChecklistItemString;

        my $ChecklistItems = $Kernel::OM->Get('JSON')->Decode(
            Data => $ChecklistItemString,
        );

        my $Items = $Self->_GetChecklistRows(Items => $ChecklistItems);

        if (IsArrayRefWithData($Items)) {
            my $Done = 0;
            my $All = 0;
            for my $Item ( @{ $Items } ) {
                if ($Item) {
                    $All++;
                    if ($Item->{IsCountable}) {
                        $Done++;
                    }
                }
            }
            $Value .= ($Value ? ', ' : q{}) . "$Done/$All";
        }
    }

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title
    };

    return $Data;
}

sub _GetChecklistRows {
    my ( $Self, %Param ) = @_;

    my @Rows;

    if ( IsArrayRefWithData($Param{Items}) ) {
        for my $Item ( @{ $Param{Items} } ) {
            if (IsHashRefWithData($Item)) {

                # check if the item is countable
                my $IsCountable = 0;
                if( $Item->{input} eq 'ChecklistState' ) {
                    for my $ChecklistState ( @{ $Item->{inputStates} }) {
                        if ( $ChecklistState->{value} eq $Item->{value} && $ChecklistState->{done} ) {
                            $IsCountable = 1;
                            last;
                        }
                    }
                } else {
                    # if text has a value than it should be counted
                    $IsCountable = length( $Item->{value} ) > 0;
                }

                push(
                    @Rows,
                    {
                        Title       => $Item->{title} || q{},
                        Value       => $Item->{value} || q{},
                        IsCountable => $IsCountable
                    }
                );

                if ( IsArrayRefWithData($Item->{sub}) ) {
                    my $SubRows = $Self->_GetChecklistRows(Items => $Item->{sub});
                    push(@Rows, @{$SubRows});
                }
            }
        }
    }

    return \@Rows;
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
