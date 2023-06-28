# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::DynamicField::Common;

use strict;
use warnings;

use MIME::Base64();

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::DynamicField::Common - Base class for all DynamicField Operations

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=begin Internal:

=item _CheckDynamicField()

checks if the given DynamicField parameter is valid.

    my $CheckResult = $OperationObject->_CheckDynamicField(
        DynamicField => $DynamicField,              # all parameters
    );

    returns:

    $CheckResult = {
        Success => 1,                               # if everything is OK
    }

    $CheckResult = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckDynamicField {
    my ( $Self, %Param ) = @_;

    my $DynamicField = $Param{DynamicField};

    # check if Name is alphanumeric
    if ( $DynamicField->{Name} && $DynamicField->{Name} !~ m{\A (?: [a-zA-Z] | \d )+ \z}xms ) {

        return $Self->_Error(
            Code    => 'BadRequest',
            Message => 'Attribute "Name" has to be alphanumeric.',
        );
    }

    # check if FieldType is valid
    if ( $DynamicField->{FieldType} ) {

        # get FieldTypes
        my $FieldTypeConfig = $Kernel::OM->Get('Config')->Get('DynamicFields::Driver');

        if ( !IsHashRefWithData($FieldTypeConfig) ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => 'DynamicField::Driver config is not valid',
            );
        }

        if ( !$FieldTypeConfig->{$DynamicField->{FieldType}} ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Unknown field type '$DynamicField->{FieldType}'.",
            );
        }
    }

    # check if ObjectType is valid
    if ( $DynamicField->{ObjectType} ) {

        # get FieldTypes
        my $ObjectTypeConfig = $Kernel::OM->Get('Config')->Get('DynamicFields::ObjectType');

        if ( !IsHashRefWithData($ObjectTypeConfig) ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => 'DynamicField::ObjectType config is not valid',
            );
        }

        if ( !$ObjectTypeConfig->{$DynamicField->{ObjectType}} ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Unknown object type '$DynamicField->{ObjectType}'.",
            );
        }
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

1;

=end Internal:





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
