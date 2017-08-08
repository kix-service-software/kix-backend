# --
# Kernel/GenericInterface/Operation/CustomerContact/CustomerContactCreate.pm - GenericInterface CustomerContact Create operation backend
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

package Kernel::API::Operation::V1::CustomerContact::CustomerContactCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
    Kernel::API::Operation::V1::CustomerContact::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CustomerContact::CustomerContactCreate - GenericInterface CustomerContact Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::CustomerContactCreate');

    return $Self;
}

=item Run()

perform CustomerContactCreate Operation. This will return the created UserLogin.

    my $Result = $OperationObject->Run(
        Data => {
            UserLogin         => 'some agent login',                            # UserLogin or CustomerContactLogin or SessionID is
                                                                                #   required
            CustomerContactLogin => 'some customer login',
            SessionID         => 123,

            Password  => 'some password',                                       # if UserLogin or CustomerContactLogin is sent then
                                                                                #   Password is required

            CustomerContact => {
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
            ErrorCode    => 'CustomerContactCreate.MissingParameter',
            ErrorMessage => "CustomerContactCreate: UserLogin, CustomerContactLogin or SessionID is required!",
        );
    }

    if ( $Param{Data}->{UserLogin} || $Param{Data}->{CustomerContactLogin} ) {

        if ( !$Param{Data}->{Password} )
        {
            return $Self->ReturnError(
                ErrorCode    => 'CustomerContactCreate.MissingParameter',
                ErrorMessage => "CustomerContactCreate: Password or SessionID is required!",
            );
        }
    }

    # authenticate user
    my ( $UserID, $UserType ) = $Self->Auth(
        %Param,
    );

    if ( !$UserID ) {
        return $Self->ReturnError(
            ErrorCode    => 'CustomerContactCreate.AuthFail',
            ErrorMessage => "CustomerContactCreate: User could not be authenticated!",
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
                ErrorCode    => 'CustomerContactCreate.MissingParameter',
                ErrorMessage => "CustomerContactCreate: $Needed parameter is missing or not valid!",
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
    for my $Needed (qw(UserLogin UserFirstname UserLastname UserEmail UserCustomerID)) {
        if ( !$CustomerContact->{$Needed} ) {
            return $Self->ReturnError(
                ErrorCode    => 'CustomerContactCreate.MissingParameter',
                ErrorMessage => "CustomerContactCreate: CustomerContact->$Needed parameter is missing!",
            );
        }
    }
    
    # check UserLogin exists
    my $UserExists = $Kernel::OM->Get('Kernel::System::CustomerContact')->CustomerName(
        UserLogin => $CustomerContact->{UserLogin},
    );
    if ( $UserExists ) {
        return {
            Success      => 0,
            ErrorMessage => "Can not create customer user. Customer user '$CustomerContact->{UserLogin}' already exists.",
        }
    }

    # check UserEmail exists
    my %UserList = $Kernel::OM->Get('Kernel::System::CustomerContact')->CustomerSearch(
        PostMasterSearch => $CustomerContact->{UserEmail},
    );
    if ( %UserList ) {
        return {
            Success      => 0,
            ErrorMessage => 'Can not create customer user. Customer user with same email address already exists.',
        }
    }
    
    # create CustomerContact
    my $UserLogin = $Kernel::OM->Get('Kernel::System::CustomerContact')->CustomerContactAdd(
        %{$CustomerContact},
        Source  => $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::Module')->{'CustomerContact::CustomerContactCreate'}->{DefaultSource},
        UserID  => $UserID,
        ValidID => 1,
    );    
    if ( !$UserLogin ) {
        return {
            Success      => 0,
            ErrorMessage => 'Could not create customer user, please contact the system administrator',
            }
    }
    
    return {
        Success => 1,
        Data    => {
            CustomerContactID => $UserLogin,
        },
    };
    
}
