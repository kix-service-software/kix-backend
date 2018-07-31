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
            ContactID => '...'                                                  # required
            Contact => {
                UserLogin       => '...'                                        # optional
                UserFirstname   => '...'                                        # optional
                UserLastname    => '...'                                        # optional
                UserEmail       => '...'                                        # optional
                UserPassword    => '...'                                        # optional                
                UserPhone       => '...'                                        # optional                
                UserTitle       => '...'                                        # optional
                ValidID         = 0 | 1 | 2                                     # optional
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
    my %ContactData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
        User => $Param{Data}->{ContactID},
    );
    if ( !%ContactData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Can not update Contact. No Contact with ID '$Param{Data}->{ContactID}' found.",
        );
    }

    # check if backend (Source) is writeable
    
    my %SourceList = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSourceList(
        ReadOnly => 0
    );    
    if ( !$SourceList{$ContactData{Source}} ) {
        return $Self->_Error(
            Code    => 'Forbidden',
            Message => 'Can not update Contact. Corresponding backend is not writable or does not exist.',
        );        
    }

    # check if ContactLogin already exists
    if ( IsStringWithData($Contact->{UserLogin}) ) {
        my %ContactList = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSearch(
            User => $Contact->{UserLogin},
        );
        if ( %ContactList && (scalar(keys %ContactList) > 1 || !$ContactList{$ContactData{UserLogin}})) {        
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => 'Can not update Contact. Another Contact with same login already exists.',
            );
        }
    }


    # check ContactEmail exists
    if ( IsStringWithData($Contact->{UserEmail}) ) {
        my %ContactList = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSearch(
            PostMasterSearch => $Contact->{UserEmail},
        );
        if ( %ContactList && (scalar(keys %ContactList) > 1 || !$ContactList{$ContactData{UserLogin}})) {        
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => 'Can not update Contact. Another Contact with same email address already exists.',
            );
        }
    }
    
    # update Contact
    my $Success = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserUpdate(
        %ContactData,
        %{$Contact},
        UserCustomerIDs => IsArrayRefWithData($Contact->{UserCustomerIDs}) ? join(',', @{$Contact->{UserCustomerIDs}}) : $ContactData{UserCustomerIDs},
        ID              => $ContactData{UserID},
        UserID          => $Self->{Authorization}->{UserID},
    );    
    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update Contact, please contact the system administrator',
        );
    }
    
    return $Self->_Success(
        ContactID => $Contact->{UserLogin} || $ContactData{UserID},
    );   
}