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
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

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
        Message    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            UserID  => '',                          # UserID 
            Error => {                              # should not return errors
                    Code    => 'User.Create.Code'
                    Message => 'Error Description'
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
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
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
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
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
        return $Self->_Error(
            Code    => 'UserCreate.LoginExists',
            Message => "Can not create user. User with same login '$User->{UserLogin}' already exists.",
        );
    }

    # check UserEmail exists
    my %UserList = $Kernel::OM->Get('Kernel::System::User')->UserSearch(
        Search => $User->{UserEmail},
    );
    if ( %UserList ) {
        return $Self->_Error(
            Code    => 'UserCreate.EmailExists',
            Message => 'Can not create user. User with same email address already exists.',
        );
    }
    
    # create User
    my $UserID = $Kernel::OM->Get('Kernel::System::User')->UserAdd(
        %{$User},
        ChangeUserID     => $Param{Data}->{Authorization}->{UserID},
        ValidID          => 1,
    );    
    if ( !$UserID ) {
        return $Self->_Error(
            Code    => 'UserCreate.UnableToCreate',
            Message => 'Could not create user, please contact the system administrator',
        );
    }
    
    return $Self->_Success(
        Code   => 'Object.Created',
        UserID => $UserID,
    );    
}
