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
}

=item Run()

perform UserCreate Operation. This will return the created UserLogin.

    my $Result = $OperationObject->Run(
        Data => {
            User => {
                UserLogin       => '...'                                        # required
                UserFirstname   => '...'                                        # required
                UserLastname    => '...'                                        # required
                UserEmail       => '...'                                        # required
                UserPassword    => '...'                                        # optional                
                UserPhone       => '...'                                        # optional                
                UserTitle       => '...'                                        # optional
                RoleIDs         => [                                            # optional          
                    123
                ],
                Preferences     => [                                            # optional
                    {
                        ID    => '...',
                        Value => '...'
                    }
                ]
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            UserID  => '',                          # UserID 
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
        User => $User->{UserLogin},
    );
    if ( %UserData ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create user. Another user with same login already exists.",
        );
    }

    # check UserEmail exists
    my %UserList = $Kernel::OM->Get('Kernel::System::User')->UserSearch(
        PostMasterSearch => $User->{UserEmail},
    );
    if ( %UserList ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => 'Can not create user. Another user with same email address already exists.',
        );
    }
    
    # create User
    my $UserID = $Kernel::OM->Get('Kernel::System::User')->UserAdd(
        %{$User},
        ChangeUserID     => $Self->{Authorization}->{UserID},
        ValidID          => 1,
    );    
    if ( !$UserID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create user, please contact the system administrator',
        );
    }

    # add preferences
    if ( IsArrayRefWithData($User->{Preferences}) ) {

        foreach my $Pref ( @{$User->{Preferences}} ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::User::UserPreferenceCreate',
                Data          => {
                    UserID         => $UserID,
                    UserPreference => $Pref
                }
            );
            
            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    ${$Result},
                )
            }
        }
    }

    # assign roles
    if ( IsArrayRefWithData($User->{RoleIDs}) ) {

        foreach my $RoleID ( @{$User->{RoleIDs}} ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::User::UserRoleCreate',
                Data          => {
                    UserID => $UserID,
                    RoleID => $RoleID,
                }
            );
            
            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    ${$Result},
                )
            }
        }
    }
    
    return $Self->_Success(
        Code   => 'Object.Created',
        UserID => $UserID,
    );    
}
