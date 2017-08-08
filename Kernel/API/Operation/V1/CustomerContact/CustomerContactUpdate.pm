# --
# Kernel/GenericInterface/Operation/CustomerContact/CustomerContactUpdate.pm - GenericInterface CustomerContact Update operation backend
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

package Kernel::API::Operation::V1::CustomerContact::CustomerContactUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
    Kernel::API::Operation::V1::CustomerContact::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CustomerContact::CustomerContactUpdate - GenericInterface CustomerContact Update Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!"
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::CustomerContactUpdate');

    return $Self;
}

=item Run()

perform CustomerContactUpdate Operation. This will return the updated UserLogin.

    my $Result = $OperationObject->Run(
        Data => {
            UserLogin         => 'some agent login',                            # UserLogin or CustomerContactLogin or SessionID is
                                                                                #   required
            CustomerContactLogin => 'some customer login',
            SessionID         => 123,

            Password  => 'some password',                                       # if UserLogin or CustomerContactLogin is sent then
                                                                                #   Password is required

            CustomerContact => {
                UserID          => '...'                                        # required
                UserLogin       => '...'                                        # required
                UserFirstname   => '...'                                        # required
                UserLastname    => '...'                                        # required
                UserEmail       => '...'                                        # required
                UserPassword    => '...'                                        # optional
                UserComment     => '...'                                        # optional
                UserPhone       => '...'                                        # optional
                UserMobile      => '...'                                        # optional
                UserFax         => '...'                                        # optional
                UserStreet      => '...'                                        # optional
                UserCity        => '...'                                        # optional
                UserZip         => '...'                                        # optional
                UserCountry     => '...'                                        # optional
                UserTitle       => '...'                                        # optional
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        ErrorMessage    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            CustomerContactID  => '',                     # CustomerContactID 
            Error => {                              # should not return errors
                    ErrorCode    => 'CustomerContact.Create.ErrorCode'
                    ErrorMessage => 'Error Description'
            },
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->ReturnError(
            ErrorCode    => 'Webservice.InvalidConfiguration',
            ErrorMessage => $Result->{ErrorMessage},
        );
    }

    # check needed stuff
    if (
        !$Param{Data}->{UserLogin}
        && !$Param{Data}->{CustomerContactLogin}
        && !$Param{Data}->{SessionID}
        )
    {
        return $Self->ReturnError(
            ErrorCode    => 'CustomerContactUpdate.MissingParameter',
            ErrorMessage => "CustomerContactUpdate: UserLogin, CustomerContactLogin or SessionID is required!",
        );
    }

    if ( $Param{Data}->{UserLogin} || $Param{Data}->{CustomerContactLogin} ) {

        if ( !$Param{Data}->{Password} )
        {
            return $Self->ReturnError(
                ErrorCode    => 'CustomerContactUpdate.MissingParameter',
                ErrorMessage => "CustomerContactUpdate: Password or SessionID is required!",
            );
        }
    }

    # authenticate user
    my ( $UserID, $UserType ) = $Self->Auth(
        %Param,
    );

    if ( !$UserID ) {
        return $Self->ReturnError(
            ErrorCode    => 'CustomerContactUpdate.AuthFail',
            ErrorMessage => "CustomerContactUpdate: User could not be authenticated!",
        );
    }

    my $PermissionUserID = $UserID;
    if ( $UserType eq 'Customer' ) {
        $UserID = $Kernel::OM->Get('Kernel::Config')->Get('CustomerPanelUserID')
    }

    # check needed hashes
    for my $Needed (qw(CustomerContact)) {
        if ( !IsHashRefWithData( $Param{Data}->{$Needed} ) ) {
            return $Self->ReturnError(
                ErrorCode    => 'CustomerContactUpdate.MissingParameter',
                ErrorMessage => "CustomerContactUpdate: $Needed parameter is missing or not valid!",
            );
        }
    }

    # isolate CustomerContact parameter
    my $CustomerContact = $Param{Data}->{CustomerContact};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$CustomerContact} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $CustomerContact->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $CustomerContact->{$Attribute} =~ s{\s+\z}{};
        }
    }

    # check CustomerContact attribute values
    for my $Needed (qw(UserID)) {
        if ( !$CustomerContact->{$Needed} ) {
            return $Self->ReturnError(
                ErrorCode    => 'CustomerContactUpdate.MissingParameter',
                ErrorMessage => "CustomerContactUpdate: CustomerContact->$Needed parameter is missing!",
            );
        }
    }
    
    # check UserLogin exists
    my %UserData = $Kernel::OM->Get('Kernel::System::CustomerContact')->CustomerContactDataGet(
        User => $CustomerContact->{UserID},
    );
    if ( !%UserData) {
        return {
            Success      => 0,
            ErrorMessage => "Can not update customer user. No customer user with id '$CustomerContact->{UserID}' exists.",
        }
    }

    # check UserEmail exists
    my %UserList = $Kernel::OM->Get('Kernel::System::CustomerContact')->CustomerSearch(
        PostMasterSearch => $CustomerContact->{UserEmail},
    );
    if ( %UserList && (scalar(keys %UserList) > 1 || !$UserList{$UserData{UserID}})) {        
        return {
            Success      => 0,
            ErrorMessage => 'Can not update customer user. Another customer user with same email address already exists.',
        }
    }
        
    # update CustomerContact
    my $Success = $Kernel::OM->Get('Kernel::System::CustomerContact')->CustomerContactUpdate(
        %UserData,
        %{$CustomerContact},
        ID      => $CustomerContact->{UserID},
        ValidID => $UserData{ValidID},
        UserID  => $UserID,
    );    
    if ( !$Success ) {
        return {
            Success      => 0,
            ErrorMessage => 'Could not update customer user, please contact the system administrator',
        }
    }
    
    return {
        Success => 1,
        Data    => {
            CustomerContactID => $UserData{UserLogin},
        },
    };
    
}
