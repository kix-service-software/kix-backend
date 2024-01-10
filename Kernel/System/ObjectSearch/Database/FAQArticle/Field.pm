# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::FAQArticle::Field;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::FAQArticle::Field - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    my %Supported = ();
    for ( 1..6 ) {
        $Supported{"Field$_"} = {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        };
    }

    return \%Supported;
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    my %AttributeMapping = (
        Field1 => 'f.f_field1',
        Field2 => 'f.f_field2',
        Field3 => 'f.f_field3',
        Field4 => 'f.f_field4',
        Field5 => 'f.f_field5',
        Field6 => 'f.f_field6',
    );

    my $Values = [];
    if ( !IsArrayRef( $Param{Search}->{Value} ) ) {
        push( @{ $Values },  $Param{Search}->{Value}  );
    }
    else {
        $Values =  $Param{Search}->{Value} ;
    }

    my $PreparedValues = [];
    # also search as html value, because fields content are html
    for my $Value ( @{$Values} ) {
        my $HTMLValue = $Kernel::OM->Get('HTMLUtils')->ToHTML(
            String      => $Value,
            AlsoUmlauts => 1
        );

        # adds prepared value only if they are different
        if ( $Value ne $HTMLValue ) {
            push(
                @{$PreparedValues},
                $HTMLValue
            );
        }

        push(
            @{$PreparedValues},
            $Value
        );
    }

    my $Condition = $Self->_GetCondition(
        Operator        => $Param{Search}->{Operator},
        Column          => $AttributeMapping{$Param{Search}->{Field}},
        Value           => $PreparedValues,
        NULLValue       => 1,
        CaseInsensitive => 1
    );

    return if ( !$Condition );

    return {
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
