# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::User::UserCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

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
        'User::IsAgent' => {
            RequiresValueIfUsed => 1,
            OneOf => [ 0, 1 ]
        },
        'User::IsCustomer' => {
            RequiresValueIfUsed => 1,
            OneOf => [ 0, 1 ]
        },
    }
}

=item Run()

perform UserCreate Operation. This will return the created UserLogin.

    my $Result = $OperationObject->Run(
        Data => {
            User => {
                UserLogin       => '...'                                        # required
                UserPassword    => '...'                                        # optional
                ValidID         => 1,
                IsAgent         => 0 | 1,                                       # optional
                IsCustomer      => 0 | 1,                                       # optional
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
    my %UserData = $Kernel::OM->Get('User')->GetUserData(
        User => $User->{UserLogin},
    );
    if (%UserData) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create user. Another user with same login already exists.",
        );
    }

    # create User
    my $UserID = $Kernel::OM->Get('User')->UserAdd(
        ValidID => 1,
        %{$User},
        ChangeUserID => $Self->{Authorization}->{UserID},
    );
    if ( !$UserID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create user, please contact the system administrator',
        );
    }

    # add preferences
    if ( IsArrayRefWithData( $User->{Preferences} ) ) {

        foreach my $Pref ( @{ $User->{Preferences} } ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::User::UserPreferenceCreate',
                Data          => {
                    UserID         => $UserID,
                    UserPreference => $Pref
                }
            );

            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    %{$Result},
                )
            }
        }
    }

    # assign roles
    if ( IsArrayRefWithData( $User->{RoleIDs} ) ) {

        foreach my $RoleID ( @{ $User->{RoleIDs} } ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::User::UserRoleIDCreate',
                Data          => {
                    UserID => $UserID,
                    RoleID => $RoleID,
                }
            );

            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    %{$Result},
                )
            }
        }
    }

    # auto assign customer role
    if ( $User->{IsCustomer} ) {

        # get RoleID from Role "Customer"
        my $RoleID = $Kernel::OM->Get('Role')->RoleLookup(
            Role => "Customer",
        );

        my $RoleIDFound = 0;
        if ( IsArrayRefWithData( $User->{RoleIDs} ) ) {
            if ( grep( /^$RoleID/, @{ $User->{RoleIDs} } ) ) {
                $RoleIDFound = 1;
            }
        }

        if ( !$RoleIDFound ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::User::UserRoleIDCreate',
                Data          => {
                    UserID => $UserID,
                    RoleID => $RoleID,
                }
            );

            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    %{$Result},
                )
            }
        }
    }

    return $Self->_Success(
        Code   => 'Object.Created',
        UserID => 0 + $UserID,
    );
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
