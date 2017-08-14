# --
# Kernel/API/Operation/User/UserCreate.pm - API User Create operation backend
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

package Kernel::API::Operation::V1::User::UserCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::User::V1::UserCreate - API User Create Operation backend

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
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!"
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::UserCreate');

    return $Self;
}

=item Run()

perform UserCreate Operation. This will return the created UserLogin.

    my $Result = $OperationObject->Run(
        Data => {
            Authorization => {
                ...
            },

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
            UserID  => '',                          # UserID 
            Error => {                              # should not return errors
                    ErrorCode    => 'User.Create.ErrorCode'
                    ErrorMessage => 'Error Description'
            },
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webservice
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->ReturnError(
            ErrorCode    => 'Webservice.InvalidConfiguration',
            ErrorMessage => $Result->{ErrorMessage},
        );
    }

    # parse and prepare parameters
    $Result = $Self->ParseParameters(
        Data       => $Param{Data},
        Parameters => {
            'User' => {
                Type     => 'HASH',
                Required => 1
            },
            'User::UserLogin' => {
                Required => 1
            },            
            'User::UserFirstname' => {
                Required => 1
            },            
            'User::UserLastname' => {
                Required => 1
            },            
            'User::UserEmail' => {
                Required => 1
            },            
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->ReturnError(
            ErrorCode    => 'UserGet.MissingParameter',
            ErrorMessage => $Result->{ErrorMessage},
        );
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
        ChangeUserID     => $Param{Data}->{Autorization}->{UserID},
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
