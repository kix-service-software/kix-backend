# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Session::UserUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

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
            RequiresValueIfUsed => 1
        },
    }
}

=item Run()

perform UserUpdate Operation. This will return the updated UserID.

    my $Result = $OperationObject->Run(
        Data => {
            User => {
                UserLogin       => '...',                                          # requires a value if given
                UserPassword    => '...',                                         # optional
                ValidID         => 0 | 1 | 2,                                     # optional
                IsAgent         => 0 | 1,                                         # optional
                IsCustomer      => 0 | 1,                                         # optional
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
    delete $User->{UserID};

    # check UserLogin exists
    my %UserData = $Kernel::OM->Get('User')->GetUserData(
        UserID => $Self->{Authorization}->{UserID},
    );
    if ( !%UserData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # check if UserLogin already exists
    if ( IsStringWithData( $User->{UserLogin} ) ) {
        my %UserList = $Kernel::OM->Get('User')->UserSearch(
            Search => $User->{UserLogin},
        );
        if ( %UserList && ( scalar( keys %UserList ) > 1 || !$UserList{ $UserData{UserID} } ) ) {
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => 'Cannot update user. Another user with same login already exists.',
            );
        }
    }

    # update User
    my $Success = $Kernel::OM->Get('User')->UserUpdate(
        %UserData,
        %{$User},
        UserPw       => $User->{UserPw},
        ChangeUserID => $Self->{Authorization}->{UserID},
    );
    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # create access token
    if ( $User->{ExecGenerateToken} ) {
        my $Success = $Kernel::OM->Get('User')->TokenGenerate(
            UserID => $Self->{Authorization}->{UserID}
        );
    }

    # create mfa secret
    if ( $User->{ExecMFAGenerateSecret} ) {
        my $Success = $Kernel::OM->Get('Auth')->MFASecretGenerate(
            MFAuth => $User->{ExecMFAGenerateSecret},
            UserID => $Self->{Authorization}->{UserID}
        );
    }

    return $Self->_Success(
        UserID => $UserData{UserID},
    );
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
