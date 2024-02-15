# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Validator::VersionValidator;

use strict;
use warnings;

use base qw(
    Kernel::API::Validator::Common
);

# prevent 'Used once' warning for Kernel::OM
use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Validator::VersionValidator - validator module

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Validate()

validate given data attribute

    my $Result = $ValidatorObject->Validate(
        Attribute => '...',                     # required
        Data      => {                          # required but may be empty
            ...
        }
    );

    $Result = {
        Success         => 1,                   # 0 or 1
        ErrorMessage    => '',                  # in case of error
    };

=cut

sub Validate {
    my ( $Self, %Param ) = @_;

    if ( !$Param{Attribute} ) {
        return $Self->_Error(
            Code    => 'Validator.InternalError',
            Message => 'Got no Attribute!'
        );
    }

    if ( !$Param{Operation} ) {
        return $Self->_Error(
            Code    => 'Validator.InternalError',
            Message => 'Got no Operation!'
        );
    }

    # check params
    if (
        (
            $Param{ParentAttribute}
            && $Param{ParentAttribute} eq 'ConfigItem'
        )
        || $Param{Attribute} eq 'ConfigItemVersion'
    ) {

        if ( !IsHashRef($Param{Data}->{$Param{Attribute}}) ) {
            return $Self->_Error(
                Code    => 'Validator.UnknownAttribute',
                Message => "VersionValidator: cannot validate attribute $Param{Attribute}!"
            );
        }

        # Initializes the validation of the sub-attributes like deployment/incident
        # states and others that should be validate.
        # But ignore all attributes under “Data” (XML data),
        # as the keys underneath can lead to incorrect validations.
        # e.g. if "Role" is set as an attribute key in the XMLData.
        return $Kernel::OM->Get('API::Validator')->Validate(
            %Param,
            Data => {
                %{$Param{Data}->{$Param{Attribute}}},
                Data => undef
            }
        );
    }

    return $Self->_Success();
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
