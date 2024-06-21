# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Auth;

use strict;
use warnings;

use Storable;

use Kernel::Language qw(Translatable);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    Config
    Log
    Main
    Time
    User
    Valid
);

=head1 NAME

Kernel::System::Auth - agent authentication module.

=head1 SYNOPSIS

The authentication module for the agent interface.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $AuthObject = $Kernel::OM->Get('Auth');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # handle auth config
    my $AuthConfigRef = $Kernel::OM->Get('Config')->Get('Authentication');
    if ( !IsHashRefWithData( $AuthConfigRef ) ) {
        $Kernel::OM->Get('Main')->Die("Invalid Authentication config!");
    }

    # create clone to keep the original
    $Self->{AuthConfig} =  Storable::dclone( $AuthConfigRef );

    # load auth module for each enabled config
    for my $AuthReg ( sort( keys( %{ $Self->{AuthConfig} } ) ) ) {
        if ( !IsArrayRefWithData( $Self->{AuthConfig}->{ $AuthReg } ) ) {
            $Kernel::OM->Get('Main')->Die("Invalid Authentication config ($AuthReg)!");
        }

        CONFIG:
        for my $Config ( @{ $Self->{AuthConfig}->{ $AuthReg } } ) {
            next CONFIG if (
                !$Config->{Enabled}
                || !$Config->{Module}
            );

            my $Module = $Kernel::OM->GetModuleFor( $Config->{Module} ) || $Config->{Module};

            if ( !$Kernel::OM->Get('Main')->Require( $Module ) ) {
                $Kernel::OM->Get('Main')->Die("Can't load auth backend module $Config->{Module}! $@");
            }

            $Config->{BackendObject} = $Module->new(
                Name   => $Config->{Name},
                Config => $Config->{Config}
            );
            next CONFIG if ( !defined( $Config->{BackendObject} ) );

            # set global config in module
            $Config->{BackendObject}->{Config} = $Config;

            if ( IsArrayRefWithData( $Config->{Sync} ) ) {
                SYNCCONFIG:
                for my $SyncConfig ( @{ $Config->{Sync} } ) {
                    next SYNCCONFIG if (
                        !$SyncConfig->{Enabled}
                        || !$SyncConfig->{Module}
                    );

                    my $SyncModule = $Kernel::OM->GetModuleFor( $SyncConfig->{Module} ) || $SyncConfig->{Module};

                    if ( !$Kernel::OM->Get('Main')->Require( $SyncModule ) ) {
                        $Kernel::OM->Get('Main')->Die("Can't load auth sync backend module $SyncConfig->{Module}! $@");
                    }
                    # load sync module
                    $SyncConfig->{BackendObject} = $SyncModule->new(
                        Config => {
                            %{ $Config->{Config} || {} },
                            %{ $SyncConfig->{Config} || {} }
                        }
                    );
                }
            }
        }
    }

    # handle multi factor auth config
    my $MultiFactorAuthConfigRef = $Kernel::OM->Get('Config')->Get('MultiFactorAuthentication');
    if ( IsHashRefWithData( $MultiFactorAuthConfigRef ) ) {
        # create clone to keep the original
        $Self->{MultiFactorAuthConfig} =  Storable::dclone( $MultiFactorAuthConfigRef );

        # load multi factor auth module for each enabled config
        for my $MFAuthReg ( sort( keys( %{ $Self->{MultiFactorAuthConfig} } ) ) ) {
            if ( !IsArrayRefWithData($Self->{MultiFactorAuthConfig}->{ $MFAuthReg }) ) {
                $Kernel::OM->Get('Main')->Die("Invalid MultiFactorAuthentication config ($MFAuthReg)!");
            }

            MFACONFIG:
            for my $MFAConfig ( @{ $Self->{MultiFactorAuthConfig}->{ $MFAuthReg } } ) {
                next MFACONFIG if (
                    !$MFAConfig->{Enabled}
                    || !$MFAConfig->{Module}
                );

                my $Module = $Kernel::OM->GetModuleFor( $MFAConfig->{Module} ) || $MFAConfig->{Module};

                if ( !$Kernel::OM->Get('Main')->Require( $Module ) ) {
                    $Kernel::OM->Get('Main')->Die("Can't load auth backend module $MFAConfig->{Module}! $@");
                }

                $MFAConfig->{BackendObject} = $Module->new(
                    Name   => $MFAConfig->{Name},
                    Config => $MFAConfig->{Config}
                );
                next MFACONFIG if ( !defined( $MFAConfig->{BackendObject} ) );

                # set global config in module
                $MFAConfig->{BackendObject}->{Config} = $MFAConfig;
            }
        }
    }

    # Initialize last error message
    $Self->{LastErrorMessage} = '';

    return $Self;
}

=item GetPreAuthTypes()

get possible preauth types
    my $PreAuthTypes = $AuthObject->GetPreAuthTypes(
        UsageContext => 'Agent',       # (Agent|Customer)
    );

Returns:

    $PreAuthTypes = [
        'PreAuthType'
    ];

=cut

sub GetPreAuthTypes {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw(UsageContext) ) {
        if ( !$Param{ $Needed } ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my %PreAuthTypesHash = ();

    AUTHREG:
    for my $AuthReg ( sort( keys( %{ $Self->{AuthConfig} } ) ) ) {

        CONFIG:
        for my $Config ( @{ $Self->{AuthConfig}->{ $AuthReg } } ) {
            next CONFIG if (
                !$Config->{Enabled}
                || !$Config->{BackendObject}
            );
            next CONFIG if (
                defined $Config->{UsageContext}
                && $Config->{UsageContext} ne $Param{UsageContext}
            );
            next CONFIG if (
                !$Config->{BackendObject}->can('PreAuth')
                || !$Config->{BackendObject}->can('PreAuthType')
            );

            # get PreAuthType of auth backend
            my $PreAuthType = $Config->{BackendObject}->PreAuthType();

            $PreAuthTypesHash{ $PreAuthType } = 1;
        }
    }

    my @PreAuthTypes = sort( keys( %PreAuthTypesHash ) );
    return \@PreAuthTypes;
}

=item GetMFATypes()

get possible mfa types
    my $MFAuthTypes = $AuthObject->GetMFAuthTypes(
        UsageContext => 'Agent',       # (Agent|Customer)
    );

Returns:

    $MFAuthTypes = [
        'MFAuthType'
    ];

=cut

sub GetMFAuthTypes {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw(UsageContext) ) {
        if ( !$Param{ $Needed } ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my %MFAuthTypesHash = ();

    # handle multi factor auth
    if ( IsHashRefWithData( $Self->{MultiFactorAuthConfig} ) ) {

        MFAREG:
        for my $MFAuthReg ( sort( keys( %{ $Self->{MultiFactorAuthConfig} } ) ) ) {

            MFACONFIG:
            for my $MFAConfig ( @{ $Self->{MultiFactorAuthConfig}->{ $MFAuthReg } } ) {
                next MFACONFIG if (
                    !$MFAConfig->{Enabled}
                    || !$MFAConfig->{BackendObject}
                );
                next MFACONFIG if (
                    defined $MFAConfig->{UsageContext}
                    && $MFAConfig->{UsageContext} ne $Param{UsageContext}
                );
                next MFACONFIG if ( !$MFAConfig->{BackendObject}->can('GetMFAuthType') );

                # get MFAuthType of multi factor auth backend
                my $MFAuthType = $MFAConfig->{BackendObject}->GetMFAuthType();

                $MFAuthTypesHash{ $MFAuthType } = 1;
            }
        }
    }

    my @MFAuthTypes = sort( keys( %MFAuthTypesHash ) );
    return \@MFAuthTypes;
}

=item GetAuthMethods()

get possible auth methods
    my $AuthMethods = $AuthObject->GetAuthMethods(
        UsageContext => 'Agent',       # (Agent|Customer)
    );

Returns:

    $AuthMethods = [
        {
            Type    => 'LOGIN',
            PreAuth => 0,
            MFA     => []
        }
    ];

=cut

sub GetAuthMethods {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw(UsageContext) ) {
        if ( !$Param{ $Needed } ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my @AuthMethods = ();

    AUTHREG:
    for my $AuthReg ( sort( keys( %{ $Self->{AuthConfig} } ) ) ) {

        CONFIG:
        for my $Config ( @{ $Self->{AuthConfig}->{ $AuthReg } } ) {
            next CONFIG if (
                !$Config->{Enabled}
                || !$Config->{BackendObject}
            );
            next CONFIG if (
                defined $Config->{UsageContext}
                && $Config->{UsageContext} ne $Param{UsageContext}
            );
            next CONFIG if ( !$Config->{BackendObject}->can('GetAuthMethod') );

            # get AuthMethod of auth backend
            my $AuthMethod = $Config->{BackendObject}->GetAuthMethod();

            next CONFIG if (
                ref( $AuthMethod ) ne 'HASH'
                || !$AuthMethod->{Type}
                || !defined( $AuthMethod->{PreAuth} )
            );

            # handle multi factor auth config
            if ( IsHashRefWithData( $Self->{MultiFactorAuthConfig} ) ) {
                my @MFAuthMethods = ();

                MFAREG:
                for my $MFAuthReg ( sort( keys( %{ $Self->{MultiFactorAuthConfig} } ) ) ) {

                    MFACONFIG:
                    for my $MFAConfig ( @{ $Self->{MultiFactorAuthConfig}->{ $MFAuthReg } } ) {
                        next MFACONFIG if (
                            !$MFAConfig->{Enabled}
                            || !$MFAConfig->{BackendObject}
                        );
                        next MFACONFIG if (
                            defined $MFAConfig->{UsageContext}
                            && $MFAConfig->{UsageContext} ne $Param{UsageContext}
                        );
                        next MFACONFIG if (
                            defined $MFAConfig->{AuthType}
                            && $MFAConfig->{AuthType} ne $AuthMethod->{Type}
                        );
                        next MFACONFIG if ( !$MFAConfig->{BackendObject}->can('GetMFAuthMethod') );

                        # get MFAuthMethod of multi factor auth backend
                        my $MFAuthMethod = $MFAConfig->{BackendObject}->GetMFAuthMethod();

                        next MFACONFIG if (
                            ref( $MFAuthMethod ) ne 'HASH'
                            || !$MFAuthMethod->{Type}
                            || ref( $MFAuthMethod->{Data} ) ne 'HASH'
                        );

                        # check for identical known entry
                        my $NewEntry = 1;
                        MFAENTRY:
                        for my $KnownEntry ( @MFAuthMethods ) {
                            if (
                                !DataIsDifferent(
                                    Data1 => $MFAuthMethod,
                                    Data2 => $KnownEntry
                                )
                            ) {
                                $NewEntry = 0;

                                last MFAENTRY;
                            }
                        }
                        if ( $NewEntry ) {
                            push( @MFAuthMethods, $MFAuthMethod );
                        }
                    }
                }

                $AuthMethod->{MFA} = \@MFAuthMethods;
            }

            # check for identical known entry
            my $NewEntry = 1;
            ENTRY:
            for my $KnownEntry ( @AuthMethods ) {
                if (
                    !DataIsDifferent(
                        Data1 => $AuthMethod,
                        Data2 => $KnownEntry
                    )
                ) {
                    $NewEntry = 0;

                    last ENTRY;
                }
            }
            if ( $NewEntry ) {
                push( @AuthMethods, $AuthMethod );
            }
        }
    }

    return \@AuthMethods;
}

=item PreAuth()

The preauthentication function provides required data
    my $PreAuthData = $AuthObject->PreAuth(
        UsageContext => 'Agent',        # (Agent|Customer)
        Type         => 'PreAuthType',  # Type as provided by GetAuthMethods
        Data         => { ... }         # Data as provided by GetAuthMethods
    );

Returns:

    $PreAuthData = {
        RedirectURL => 'http://...'
    };

=cut

sub PreAuth {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw(UsageContext) ) {
        if ( !$Param{ $Needed } ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    AUTHREG:
    for my $AuthReg ( sort( keys( %{ $Self->{AuthConfig} } ) ) ) {

        CONFIG:
        for my $Config ( @{ $Self->{AuthConfig}->{ $AuthReg } } ) {
            next CONFIG if (
                !$Config->{Enabled}
                || !$Config->{BackendObject}
            );
            next CONFIG if (
                defined $Config->{UsageContext}
                && $Config->{UsageContext} ne $Param{UsageContext}
            );
            next CONFIG if ( !$Config->{BackendObject}->can('PreAuth') );

            # get pre auth data from backend
            my $PreAuthData = $Config->{BackendObject}->PreAuth( %Param );

            # return data if we got a defined result
            return $PreAuthData if ( defined( $PreAuthData ) );
        }
    }

    return;
}

=item Auth()

The authentication function.

    if ( $AuthObject->Auth( User => $User, UsageContext => 'Agent', Pw => $Pw ) ) {
        print "Auth ok!\n";
    }
    else {
        print "Auth invalid!\n";
    }

=cut

sub Auth {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw(UsageContext) ) {
        if ( !$Param{ $Needed } ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $User;

    AUTHREG:
    for my $AuthReg ( sort( keys(  %{ $Self->{AuthConfig} } ) ) ) {

        CONFIG:
        for my $Config ( @{ $Self->{AuthConfig}->{ $AuthReg } } ) {

            next CONFIG if (
                !$Config->{Enabled}
                || !$Config->{BackendObject}
            );
            next CONFIG if (
                defined $Config->{UsageContext}
                && $Config->{UsageContext} ne $Param{UsageContext}
            );

            # check auth backend
            $User = $Config->{BackendObject}->Auth( %Param );

            # next on no success
            next CONFIG if ( !$User );

            # Sync will happen before two factor authentication (if configured)
            # because user might not exist before being created in sync (see bug #11966).
            # A failed two factor auth after successful sync will result
            # in a new or updated user but no information or permission leak.

            # if $AuthSyncBackend is defined but empty, don't sync with any backend
            if ( IsArrayRefWithData( $Config->{Sync} ) ) {

                SYNC_CONFIG:
                for my $SyncConfig ( @{ $Config->{Sync} } ) {
                    next SYNC_CONFIG if (
                        !$SyncConfig->{Enabled}
                        || !$SyncConfig->{BackendObject}
                    );

                    # sync configured backend
                    $SyncConfig->{BackendObject}->Sync(
                        %Param,
                        User => $User
                    );
                }
            }

            # If we have no UserID at this point
            # it means auth was ok but user didn't exist before
            # and wasn't created in sync module.
            # This counts as a failed login
            my $UserID = $Kernel::OM->Get('User')->UserLookup(
                UserLogin => $User,
            );
            if ( !$UserID ) {
                $User = undef;

                next CONFIG;
            }

            # handle multi factor auth
            if ( IsHashRefWithData( $Self->{MultiFactorAuthConfig} ) ) {

                # only handle multi factor auth, if auth backend can provide a auth method type
                if ( $Config->{BackendObject}->can('GetAuthMethod') ) {

                    # get AuthMethod of auth backend
                    my $AuthMethod = $Config->{BackendObject}->GetAuthMethod();
                    if (
                        ref( $AuthMethod ) eq 'HASH'
                        && $AuthMethod->{Type}
                    ) {

                        # init multi factor auth state
                        my $MFAState = undef;

                        MFAREG:
                        for my $MFAuthReg ( sort( keys( %{ $Self->{MultiFactorAuthConfig} } ) ) ) {

                            MFACONFIG:
                            for my $MFAConfig ( @{ $Self->{MultiFactorAuthConfig}->{ $MFAuthReg } } ) {
                                next MFACONFIG if (
                                    !$MFAConfig->{Enabled}
                                    || !$MFAConfig->{BackendObject}
                                );
                                next MFACONFIG if (
                                    defined $MFAConfig->{UsageContext}
                                    && $MFAConfig->{UsageContext} ne $Param{UsageContext}
                                );
                                next MFACONFIG if (
                                    defined $MFAConfig->{AuthType}
                                    && $MFAConfig->{AuthType} ne $AuthMethod->{Type}
                                );

                                # check multi factor auth backend
                                my $MFAResult = $MFAConfig->{BackendObject}->MFAuth(
                                    %Param,
                                    User   => $User,
                                    UserID => $UserID
                                );
                                if ( defined( $MFAResult ) ) {
                                    $MFAState = $MFAResult;
                                }

                                # no more checks needed when one mfa check was successful
                                if ( $MFAState ) {
                                    last MFAREG;
                                }
                            }
                        }

                        # if at least one multi factor auth backend was checked but none was successful,
                        # it counts as a failed login
                        if (
                            defined( $MFAState )
                            && !$MFAState
                        ) {
                            $User = undef;

                            next CONFIG;
                        }
                    }
                }
            }

            # remember auth backend
            my $Success = $Kernel::OM->Get('User')->SetPreferences(
                Key    => 'UserAuthBackend',
                Value  => $Config->{Name},
                UserID => $UserID,
            );
            if ( !$Success ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Error while setting preference "UserAuthBackend"'
                );
                return 0;
            }

            last AUTHREG;
        }
    }

    # check usage context
    if ( $Param{UsageContext} && $User ) {
        # remember failed logins
        my $UserID = $Kernel::OM->Get('User')->UserLookup(
            UserLogin => $User,
        );

        return if !$UserID;

        my %UserData = $Kernel::OM->Get('User')->GetUserData(
            UserID => $UserID,
            Valid  => 1,
        );

        # reset user if the user is not allowed for this usage context
        $User = undef if ( $Param{UsageContext} eq 'Agent'    && !$UserData{IsAgent} );
        $User = undef if ( $Param{UsageContext} eq 'Customer' && !$UserData{IsCustomer} );

        if ( !$User ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "Login failed. User is not allowed for usage context \"$Param{UsageContext}\".",
            );
        }
    }

    # return if no auth user
    if ( !$User ) {

        if ( $Param{User} ) {
            # remember failed logins
            my $UserID = $Kernel::OM->Get('User')->UserLookup(
                UserLogin => $Param{User},
                Silent    => 1,
            );

            return if !$UserID;

            my %UserData = $Kernel::OM->Get('User')->GetUserData(
                UserID => $UserID,
                Valid  => 1,
            );

            my $Count = $UserData{Preferences}->{UserLoginFailed} || 0;
            $Count++;

            $Kernel::OM->Get('User')->SetPreferences(
                Key    => 'UserLoginFailed',
                Value  => $Count,
                UserID => $UserID,
            );

            # set agent to invalid-temporarily if max failed logins reached
            my $Config = $Kernel::OM->Get('Config')->Get('PreferencesGroups');
            my $PasswordMaxLoginFailed;

            if (
                $Config
                && $Config->{Password}
                && $Config->{Password}->{PasswordMaxLoginFailed}
            ) {
                $PasswordMaxLoginFailed = $Config->{Password}->{PasswordMaxLoginFailed};
            }

            return if ( !%UserData );
            return if ( !$PasswordMaxLoginFailed );
            return if ( $Count < $PasswordMaxLoginFailed );

            my $ValidID = $Kernel::OM->Get('Valid')->ValidLookup(
                Valid => 'invalid-temporarily',
            );

            my $Update = $Kernel::OM->Get('User')->UserUpdate(
                %UserData,
                ValidID      => $ValidID,
                ChangeUserID => 1,
            );

            return if ( !$Update );

            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "Login failed $Count times. Set $UserData{UserLogin} to "
                    . "'invalid-temporarily'.",
            );
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => 'Login failed',
            );
        }

        return;
    }

    # remember login attributes
    my $UserID = $Kernel::OM->Get('User')->UserLookup(
        UserLogin => $User,
    );
    return $User if ( !$UserID );

    # reset failed logins
    my $Success = $Kernel::OM->Get('User')->SetPreferences(
        Key    => 'UserLoginFailed',
        Value  => 0,
        UserID => $UserID,
    );
    if ( !$Success ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Error while setting preference "UserLoginFailed"'
        );
    }

    # last login preferences update
    $Success = $Kernel::OM->Get('User')->SetPreferences(
        Key    => 'UserLastLogin',
        Value  => $Kernel::OM->Get('Time')->SystemTime(),
        UserID => $UserID,
    );
    if ( !$Success ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Error while setting preference "UserLastLogin"'
        );
    }

    return $User;
}

=item MFASecretGenerate()

generate secret for MFA
    my $Success = $AuthObject->MFASecretGenerate(
        MFAuth => 'MFA_TOTP_andOTP',
        UserID => 1,
    );

Returns:

    $Success = 1;

=cut

sub MFASecretGenerate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw(MFAuth UserID) ) {
        if ( !$Param{ $Needed } ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return 0;
        }
    }

    # handle multi factor auth
    if ( IsHashRefWithData( $Self->{MultiFactorAuthConfig} ) ) {

        MFAREG:
        for my $MFAuthReg ( sort( keys( %{ $Self->{MultiFactorAuthConfig} } ) ) ) {

            MFACONFIG:
            for my $MFAConfig ( @{ $Self->{MultiFactorAuthConfig}->{ $MFAuthReg } } ) {
                next MFACONFIG if (
                    !$MFAConfig->{Enabled}
                    || !$MFAConfig->{BackendObject}
                );
                next MFACONFIG if ( !$MFAConfig->{BackendObject}->can('GenerateSecret') );

                my $Secret = $MFAConfig->{BackendObject}->GenerateSecret(
                    MFAuth => $Param{MFAuth}
                );

                if ( defined( $Secret ) ) {
                    # set secret in user preferences
                    my $Success = $Kernel::OM->Get('User')->SetPreferences(
                        Key    => $Param{MFAuth} . '_Secret',
                        Value  => $Secret,
                        UserID => $Param{UserID},
                    );
                    if ( !$Success ) {
                        $Kernel::OM->Get('Log')->Log(
                            Priority => 'error',
                            Message  => 'Error while setting preference "' .  $Param{MFAuth} . '_Secret"'
                        );
                        return 0;
                    }

                    # return success
                    return 1;
                }
            }
        }
    }

    # no backend has generated a secret
    return 0;
}

=item GetLastErrorMessage()

Retrieve $Self->{LastErrorMessage} content.

    my $AuthErrorMessage = $AuthObject->GetLastErrorMessage();

    Result:

        $AuthErrorMessage = "An error string message.";

=cut

sub GetLastErrorMessage {
    my ( $Self, %Param ) = @_;

    return $Self->{LastErrorMessage};
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
