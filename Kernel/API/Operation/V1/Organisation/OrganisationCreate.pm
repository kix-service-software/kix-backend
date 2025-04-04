# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Organisation::OrganisationCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Organisation::V1::OrganisationCreate - API Organisation Create Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'Organisation' => {
            Type     => 'HASH',
            Required => 1
        },
        'Organisation::Number' => {
            Required => 1
        },
        'Organisation::Name' => {
            Required => 1
        },
    }
}

=item Run()

perform OrganisationCreate Operation. This will return the created OrganisationLogin.

    my $Result = $OperationObject->Run(
        Data => {
            Organisation => {
                ...                 # attributes (required and optional) depend on Map config
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            OrganisationID  => '',                       # OrganisationID
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Organisation parameter
    my $Organisation = $Self->_Trim(
        Data => $Param{Data}->{Organisation}
    );

    # check Number exists
    my $ID = $Kernel::OM->Get('Organisation')->OrganisationLookup(
        Number => $Organisation->{Number},
        Silent => 1,
    );

    if ( $ID ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => 'Cannot create organisation. Another organisation with same number already exists.',
        );
    }

    # create Organisation
    my $OrganisationID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
        %{$Organisation},
        ValidID => $Organisation->{ValidID} || 1,
        UserID  => $Self->{Authorization}->{UserID},
    );
    if ( !$OrganisationID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create organisation, please contact the system administrator',
        );
    }

    # set dynamic fields
    if ( IsArrayRefWithData( $Organisation->{DynamicFields} ) ) {

        DYNAMICFIELD:
        foreach my $DynamicField ( @{ $Organisation->{DynamicFields} } ) {
            my $Result = $Self->_SetDynamicFieldValue(
                %{$DynamicField},
                ObjectID   => $OrganisationID,
                ObjectType => 'Organisation',
                UserID     => $Self->{Authorization}->{UserID},
            );

            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    Code    => 'Operation.InternalError',
                    Message => "Dynamic Field $DynamicField->{Name} could not be set ($Result->{Message})",
                );
            }
        }
    }

    return $Self->_Success(
        Code   => 'Object.Created',
        OrganisationID => $OrganisationID,
    );
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
