# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::TextArea;

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

Kernel::System::DynamicField::Driver::TextArea

=head1 SYNOPSIS

DynamicFields TextArea Driver delegate

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
        'IsSearchable'    => 1,
        'IsSortable'      => 1,
        'SearchOperators' => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
    };

    # get the Dynamic Field Backend custom extensions
    my $DynamicFieldDriverExtensions
        = $Kernel::OM->Get('Config')->Get('DynamicFields::Extension::Driver::TextArea');

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
            ) {
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

sub HTMLDisplayValueRender {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->DisplayValueRender(%Param);
    if (IsHashRefWithData($Result) && $Result->{Value}) {
        $Result->{Value} =~ s/(\r\n|\n\r|\n|\r)/<br>/g;
    }

    return $Result;
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
