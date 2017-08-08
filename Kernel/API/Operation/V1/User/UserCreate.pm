# --
# Kernel/GenericInterface/Operation/User/UserCreate.pm - GenericInterface User Create operation backend
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

package Kernel::GenericInterface::Operation::User::UserCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::GenericInterface::Operation::Common
    Kernel::GenericInterface::Operation::User::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::User::UserCreate - GenericInterface User Create Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::GenericInterface::Operation->new();

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('GenericInterface::Operation::UserCreate');

    return $Self;
}

=item Run()

perform UserCreate Operation. This will return the created UserLogin.

    my $Result = $OperationObject->Run(
        Data => {
            UserLogin         => 'some agent login',                            # UserLogin or UserLogin or SessionID is
                                                                                #   required
            UserLogin => 'some customer login',
            SessionID         => 123,

            Password  => 'some password',                                       # if UserLogin or UserLogin is sent then
                                                                                #   Password is required

            User => {
                UserLogin       => '...'                                        # required
                UserFirstname   => '...'                                        # required
                UserLastname    => '...'                                        # required
                UserEmail       => '...'                                        # required
                UserPassword    => '...'                                        # optional                
                UserPhone       => '...'                                        # optional                
                UserTitle       => '...'                                        # optional
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        ErrorMessage    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            UserID  => '',                     # UserID 
            Error => {                              # should not return errors
                    ErrorCode    => 'User.Create.ErrorCode'
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
        && !$Param{Data}->{UserLogin}
        && !$Param{Data}->{SessionID}
        )
    {
        return $Self->ReturnError(
            ErrorCode    => 'UserCreate.MissingParameter',
            ErrorMessage => "UserCreate: UserLogin, UserLogin or SessionID is required!",
        );
    }

    if ( $Param{Data}->{UserLogin} || $Param{Data}->{UserLogin} ) {

        if ( !$Param{Data}->{Password} )
        {
            return $Self->ReturnError(
                ErrorCode    => 'UserCreate.MissingParameter',
                ErrorMessage => "UserCreate: Password or SessionID is required!",
            );
        }
    }

    # authenticate user
    my ( $UserID, $UserType ) = $Self->Auth(
        %Param,
    );

    if ( !$UserID ) {
        return $Self->ReturnError(
            ErrorCode    => 'UserCreate.AuthFail',
            ErrorMessage => "UserCreate: User could not be authenticated!",
        );
    }

    my $PermissionUserID = $UserID;
    if ( $UserType eq 'Customer' ) {
        $UserID = $Kernel::OM->Get('Kernel::Config')->Get('CustomerPanelUserID')
    }

    # check needed hashes
    for my $Needed (qw(User)) {
        if ( !IsHashRefWithData( $Param{Data}->{$Needed} ) ) {
            return $Self->ReturnError(
                ErrorCode    => 'UserCreate.MissingParameter',
                ErrorMessage => "UserCreate: $Needed parameter is missing or not valid!",
            );
        }
    }

    # isolate User parameter
    my $User = $Param{Data}->{User};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$User} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $User->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $User->{$Attribute} =~ s{\s+\z}{};
        }
    }

    # check User attribute values
    for my $Needed (qw(UserLogin UserFirstname UserLastname UserEmail)) {
        if ( !$User->{$Needed} ) {
            return $Self->ReturnError(
                ErrorCode    => 'UserCreate.MissingParameter',
                ErrorMessage => "UserCreate: User->$Needed parameter is missing!",
            );
        }
    }
    
    # check UserLogin exists
    my %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        User => $User->{UserLogin},
    );
    if ( %UserData ) {
        return {
            Success      => 0,
            ErrorMessage => "Can not create user. User with same login '$User->{UserLogin}' already exists.",
        }
    }

    # check UserEmail exists
    my %UserList = $Kernel::OM->Get('Kernel::System::User')->UserSearch(
        Search => $User->{UserEmail},
    );
    if ( %UserList ) {
        return {
            Success      => 0,
            ErrorMessage => 'Can not create user. User with same email address already exists.',
        }
    }
    
    # create User
    my $UserID = $Kernel::OM->Get('Kernel::System::User')->UserAdd(
        %{$User},
        ChangeUserID     => $UserID,
        ValidID          => 1,
    );    
    if ( !$UserID ) {
        return {
            Success      => 0,
            ErrorMessage => 'Could not create user, please contact the system administrator',
            }
    }
    
    return {
        Success => 1,
        Data    => {
            UserID => $UserID,
        },
    };
    
}
