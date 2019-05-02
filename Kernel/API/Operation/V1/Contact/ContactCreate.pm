# --
# Kernel/API/Operation/Contact/ContactCreate.pm - API Contact Create operation backend
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

package Kernel::API::Operation::V1::Contact::ContactCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Contact::V1::ContactCreate - API Contact Create Operation backend

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
        'Contact' => {
            Type     => 'HASH',
            Required => 1
        },          
        'Contact::Firstname' => {
            Required => 1
        },            
        'Contact::Lastname' => {
            Required => 1
        },
        'Contact::Email' => {
            Required => 1
        },
        'Contact::PrimaryOrganisationID' => {
            Required => 1,
        },
        'Contact::OrganisationIDs' => {
            Required => 1,
        },
    }
}

=item Run()

perform ContactCreate Operation. This will return the created ContactLogin.

    my $Result = $OperationObject->Run(
        Data => {
            Contact => {
                ...                 # attributes
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ContactID  => '',                       # ContactID 
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Contact parameter
    my $Contact = $Self->_Trim(
        Data => $Param{Data}->{Contact}
    );

    # check Login exists
    my %ContactData = $Kernel::OM->Get('Kernel::System::Contact')->ContactSearch(
        Login => $Contact->{Login},
    );
    if ( %ContactData ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create contact. Another contact with same login already exists.",
        );
    }

    # check Email exists
    my %ContactList = $Kernel::OM->Get('Kernel::System::Contact')->ContactSearch(
        PostMasterSearch => $Contact->{Email},
    );
    if ( %ContactList ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => 'Cannot create contact. Another contact with same email address already exists.',
        );
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
    
    if ( IsArrayRefWithData($Contact->{OrganisationIDs}) || IsArrayRefWithData($ContactData{OrganisationIDs}) ) {
        # check if primary OrganisationID is contained in assigned OrganisationIDs
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

    # create Contact
    my $ContactID = $Kernel::OM->Get('Kernel::System::Contact')->ContactAdd(
        %{$Contact},
        ValidID         => $Contact->{ValidID} || 1,
        UserID          => $Self->{Authorization}->{UserID},
    );    
    if ( !$ContactID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create Contact, please contact the system administrator',
        );
    }
    
    return $Self->_Success(
        Code   => 'Object.Created',
        ContactID => $ContactID,
    );    
}
