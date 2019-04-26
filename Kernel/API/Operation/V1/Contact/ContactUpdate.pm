# --
# Kernel/API/Operation/Contact/ContactUpdate.pm - API Contact Create operation backend
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Contact::ContactUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

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

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::Contact::ContactUpdate');

    return $Self;
}

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
                Login       => '...'                                        # optional
                Firstname   => '...'                                        # optional
                Lastname    => '...'                                        # optional
                Email       => '...'                                        # optional
                Password    => '...'                                        # optional                
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

    # check ContactLogin exists
    my %ContactData = $Kernel::OM->Get('Kernel::System::Contact')->ContactGet(
        ID => $Param{Data}->{ContactID},
    );
    if ( !%ContactData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # check if ContactLogin already exists
    if ( IsStringWithData($Contact->{Login}) ) {
        my %ContactList = $Kernel::OM->Get('Kernel::System::Contact')->CustomerSearch(
            Login => $Contact->{Login},
        );
        if ( %ContactList && (scalar(keys %ContactList) > 1 || !$ContactList{$ContactData{Login}})) {        
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => 'Cannot update contact. Another contact with same login already exists.',
            );
        }
    }


    # check ContactEmail exists
    if ( IsStringWithData($Contact->{Email}) ) {
        my %ContactList = $Kernel::OM->Get('Kernel::System::Contact')->CustomerSearch(
            PostMasterSearch => $Contact->{Email},
        );
        if ( %ContactList && (scalar(keys %ContactList) > 1 || !$ContactList{$ContactData{UserLogin}})) {        
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => 'Cannot update contact. Another contact with same email address already exists.',
            );
        }
    }
    
    # check if primary OrganisationID exists
    if ( $Contact->{PrimaryOrganisationID} ) {
        my %OrgData = $Kernel::OM->Get('Kernel::System::Organisation')->OrganisationGet(
            ID => $Contact->{PrimaryOrganisationID},
        );

        if ( !%OrgData || $OrgData{ValidID} != 1 ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => 'Validation failed. No valid organisation found for primary organisation ID "'.$Contact->{PrimaryOrganisationID}.'".',
            );
        }
    }
    
    if ( $Contact->{PrimaryOrganisationID} && (IsArrayRefWithData($Contact->{OrganisationIDs}) || IsArrayRefWithData($ContactData{OrganisationIDs})) ) {
        # check if primary CustomerID is contained in assigned CustomerIDs
        my @OrgIDs = @{IsArrayRefWithData($Contact->{OrganisationIDs}) ? $Contact->{OrganisationIDs} : $ContactData{OrganisationIDs}};
        if ( !grep /$Contact->{PrimaryOrganisationID}/, @OrgIDs ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => 'Validation failed. Primary organisation ID "'.$Contact->{PrimaryOrganisationID}.'" is not available in assigned organisation IDs "'.(join(", ", @OrgIDs)).'".',
            );
        }
        # check each assigned customer 
        foreach my $OrgID ( @OrgIDs ) {
            my %OrgData = $Kernel::OM->Get('Kernel::System::Organisation')->OrganisationGet(
                ID => $OrgID,
            );
            if ( !%OrgData || $OrgData{ValidID} != 1 ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => 'Validation failed. No valid organisation found for assigned organisation ID "'.$OrgID.'".',
                );
            }
        }
    }

    # update Contact
    my $Success = $Kernel::OM->Get('Kernel::System::Contact')->ContactUpdate(
        %ContactData,
        %{$Contact},
        ID     => $Param{Data}->{ContactID},
        UserID => $Self->{Authorization}->{UserID},
    );    
    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update contact, please contact the system administrator',
        );
    }
    
    return $Self->_Success(
        ContactID => $Param{Data}->{ContactID}
    );   
}