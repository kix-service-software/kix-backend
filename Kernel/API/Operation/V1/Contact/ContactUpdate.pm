# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Contact::ContactUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Contact::V1::ContactUpdate - API Contact Create Operation backend

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
        'ContactID' => {
            DataType => 'NUMERIC',
            Required => 1
        },
        'Contact' => {
            Type     => 'HASH',
            Required => 1
        },
        }
}

=item Run()

perform ContactUpdate Operation. This will return the updated ContactID.

    my $Result = $OperationObject->Run(
        Data => {
            ContactID => '...'                                              # required
            Contact => {
                Firstname   => '...'                                        # optional
                Lastname    => '...'                                        # optional
                Email       => '...'                                        # optional
                Phone       => '...'                                        # optional
                Title       => '...'                                        # optional
                ValidID     => 0 | 1 | 2                                     # optional
                ...
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ContactID  => '',                          # ContactID
            Error => {                              # should not return errors
                    Code    => 'Contact.Create.Code'
                    Message => 'Error Description'
            },
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Contact parameter
    my $Contact = $Self->_Trim(
        Data => $Param{Data}->{Contact}
    );

    # check if Contact exists
    my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
        ID => $Param{Data}->{ContactID},
    );
    if ( !%ContactData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    if ($Contact->{AssignedUserID}) {
        my $ExistingUser = $Kernel::OM->Get('User')->UserLookup(
            UserID => $Contact->{AssignedUserID},
            Silent => 1,
        );
        if (!$ExistingUser) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "Cannot update contact. User does not exist.",
            );
        }
        else {
            my $ExistingContactID = $Kernel::OM->Get('Contact')->ContactLookup(
                UserID => $Contact->{AssignedUserID},
                Silent => 1,
            );

            if ($ExistingContactID && $ExistingContactID != $Param{Data}->{ContactID}) {
                return $Self->_Error(
                    Code    => 'Object.AlreadyExists',
                    Message => "Cannot update contact. User already assigned to contact $ExistingContactID.",
                );
            }
        }
    }

    # check ContactEmail exists
    if ( $Kernel::OM->Get('Config')->Get('ContactEmailUniqueCheck') ) {
        for my $MailAttr ( qw(Email Email1 Email2 Email3 Email4 Email5) ) {
            if ($Contact->{$MailAttr}) {
                my $ExistingContactID = $Kernel::OM->Get('Contact')->ContactLookup(
                    Email  => $Contact->{$MailAttr},
                    Silent => 1
                );
                if ($ExistingContactID && $ExistingContactID != $Param{Data}->{ContactID}) {
                    return $Self->_Error(
                        Code    => 'Object.AlreadyExists',
                        Message => "Cannot update contact. Another contact with email address \"$Contact->{$MailAttr}\" already exists.",
                    );
                }
            }
        }
    }

    # check if primary OrganisationID exists
    if ($Contact->{PrimaryOrganisationID}) {
        my %OrgData = $Kernel::OM->Get('Organisation')->OrganisationGet(
            ID => $Contact->{PrimaryOrganisationID},
        );

        if (!%OrgData || $OrgData{ValidID} != 1) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => 'Validation failed. No valid organisation found for primary organisation ID "' . $Contact->{PrimaryOrganisationID} . '".',
            );
        }

    }

    # check each assigned customer
    if ( IsArrayRefWithData($Contact->{OrganisationIDs}) ) {
        foreach my $OrgID ( @{ $Contact->{OrganisationIDs} } ) {
            my %OrgData = $Kernel::OM->Get('Organisation')->OrganisationGet(
                ID => $OrgID,
            );
            if ( !%OrgData || $OrgData{ValidID} != 1 ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => 'Validation failed. No valid organisation found for assigned organisation ID "' . $OrgID . '".',
                );
            }
        }
    }

    # update Contact
    my $Success = $Kernel::OM->Get('Contact')->ContactUpdate(
        %ContactData,
        %{$Contact},
        ID              => $Param{Data}->{ContactID},
        UserID          => $Self->{Authorization}->{UserID},
    );
    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update contact, please contact the system administrator',
        );
    }

    # set dynamic fields
    if ( IsArrayRefWithData($Contact->{DynamicFields}) ) {

        DYNAMICFIELD:
        foreach my $DynamicField ( @{$Contact->{DynamicFields}} ) {
            my $Result = $Self->_SetDynamicFieldValue(
                %{$DynamicField},
                ObjectID   => $Param{Data}->{ContactID},
                ObjectType => 'Contact',
                UserID     => $Self->{Authorization}->{UserID},
            );

            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    Code         => 'Object.UnableToUpdate',
                    Message      => "Dynamic Field $DynamicField->{Name} could not be set ($Result->{Message})",
                );
            }
        }
    }

    return $Self->_Success(
        ContactID => 0 + $ContactData{ID}   # force numeric ID
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
