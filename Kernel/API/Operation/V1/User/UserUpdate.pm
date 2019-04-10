# --
# Kernel/API/Operation/User/UserUpdate.pm - API User Create operation backend
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

package Kernel::API::Operation::V1::User::UserUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::User::V1::UserUpdate - API User Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::User::UserUpdate');

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
        'UserID' => {
            DataType => 'NUMERIC',
            Required => 1
        },
        'User' => {
            Type     => 'HASH',
            Required => 1
        },
        'User::UserLogin' => {
            RequiresValueIfUsed => 1
        },
        'User::UserFirstname' => {
            RequiresValueIfUsed => 1
        },
        'User::UserLastname' => {
            RequiresValueIfUsed => 1
        },
        'User::UserEmail' => {
            RequiresValueIfUsed => 1
        },
    }
}

=item Run()

perform UserUpdate Operation. This will return the updated UserID.

    my $Result = $OperationObject->Run(
        Data => {
            User => {
                UserLogin       => '...'                                        # requires a value if given
                UserFirstname   => '...'                                        # requires a value if given
                UserLastname    => '...'                                        # requires a value if given
                UserEmail       => '...'                                        # requires a value if given
                UserPassword    => '...'                                        # optional                
                UserPhone       => '...'                                        # optional                
                UserTitle       => '...'                                        # optional
                ValidID         = 0 | 1 | 2                                     # optional
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

    # isolate and trim User parameter
    my $User = $Self->_Trim(
        Data => $Param{Data}->{User},
    );

    # check UserLogin exists
    my %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $Param{Data}->{UserID},
    );
    if ( !%UserData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # check if UserLogin already exists
    if ( IsStringWithData($User->{UserLogin}) ) {
        my %UserList = $Kernel::OM->Get('Kernel::System::User')->UserSearch(
            Search => $User->{UserLogin},
        );
        if ( %UserList && (scalar(keys %UserList) > 1 || !$UserList{$UserData{UserID}})) {        
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => 'Can not update user. Another user with same login already exists.',
            );
        }
    }


    # check UserEmail exists
    if ( IsStringWithData($User->{UserEmail}) ) {
        my %UserList = $Kernel::OM->Get('Kernel::System::User')->UserSearch(
            PostMasterSearch => $User->{UserEmail},
        );
        if ( %UserList && (scalar(keys %UserList) > 1 || !$UserList{$UserData{UserID}})) {        
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => 'Can not update user. Another user with same email address already exists.',
            );
        }
    }
    
    # update User
    my $Success = $Kernel::OM->Get('Kernel::System::User')->UserUpdate(
        %UserData,
        %{$User},
        UserPw        => $User->{UserPw},
        ChangeUserID  => $Self->{Authorization}->{UserID},
    );    
    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }
    
    return $Self->_Success(
        UserID => $UserData{UserID},
    );   
}