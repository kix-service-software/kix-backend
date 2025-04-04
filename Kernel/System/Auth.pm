# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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
        $Kernel::OM->Get('Main')->Die("Invalid Authentication config! Need hash with data");
    }

    # init auth config with empty array
    $Self->{AuthConfig} = [];

    # load auth module for each enabled config
    AUTHCONFIG:
    for my $AuthReg ( sort( keys( %{ $AuthConfigRef } ) ) ) {
        # check config data structure
        if ( !IsArrayRefWithData( $AuthConfigRef->{ $AuthReg } ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Invalid auth config "' . $AuthReg . '". Need array with data!'
            );

            next AUTHCONFIG;
        }

        CONFIG:
        for my $Config ( @{ $AuthConfigRef->{ $AuthReg } } ) {
            # check entry data structure
            if ( !IsHashRefWithData( $Config ) ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Invalid auth config entry in "' . $AuthReg . '". Need hash with data!'
                );

                next CONFIG;
            }

            # skip disabled entry
            next CONFIG if ( !$Config->{Enabled} );

            # check needed stuff
            for my $Needed ( qw(Name Module) ) {
                if ( !$Config->{ $Needed } ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => 'Invalid auth config entry in "' . $AuthReg . '". No "' . $Needed . '" given!'
                    );

                    next CONFIG;
                }
            }

            # lookup module alias
            my $Module = $Kernel::OM->GetModuleFor( $Config->{Module} ) || $Config->{Module};

            # require module
            if ( !$Kernel::OM->Get('Main')->Require( $Module ) ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Can not require auth backend module "' . $Config->{Module} . '": ' . $@
                );

                next CONFIG;
            }

            # init auth entry
            my %AuthEntry = (
                Name         => $Config->{Name},
                UsageContext => $Config->{UsageContext}
            );

            # get backend instance
            $AuthEntry{BackendObject} = $Module->new(
                Name   => $Config->{Name},
                Config => $Config->{Config}
            );
            next CONFIG if ( !defined( $AuthEntry{BackendObject} ) );

            # check if backend can handle at least method "Auth"
            if ( !$AuthEntry{BackendObject}->can('Auth') ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Auth backend module "' . $Config->{Module} . '" can not handle method "Auth"!'
                );

                next CONFIG;
            }

            # set global config in module
            $AuthEntry{BackendObject}->{Config} = Storable::dclone( $Config );

            # init sync config with empty array
            $AuthEntry{Sync} = [];

            # check for configured auth sync configuration
            if ( IsArrayRefWithData( $Config->{Sync} ) ) {
                SYNCCONFIG:
                for my $SyncConfig ( @{ $Config->{Sync} } ) {
                    # check entry data structure
                    if ( !IsHashRefWithData( $SyncConfig ) ) {
                        $Kernel::OM->Get('Log')->Log(
                            Priority => 'error',
                            Message  => 'Invalid auth sync config entry in "' . $AuthReg . '". Need hash with data!'
                        );

                        next SYNCCONFIG;
                    }

                    # skip disabled sync entry
                    next SYNCCONFIG if ( !$SyncConfig->{Enabled} );

                    # check needed stuff
                    for my $Needed ( qw(Module) ) {
                        if ( !$SyncConfig->{ $Needed } ) {
                            $Kernel::OM->Get('Log')->Log(
                                Priority => 'error',
                                Message  => 'Invalid auth sync config entry in "' . $AuthReg . '". No "' . $Needed . '" given!'
                            );

                            next SYNCCONFIG;
                        }
                    }

                    # lookup module alias
                    my $SyncModule = $Kernel::OM->GetModuleFor( $SyncConfig->{Module} ) || $SyncConfig->{Module};

                    # require module
                    if ( !$Kernel::OM->Get('Main')->Require( $SyncModule ) ) {
                        $Kernel::OM->Get('Log')->Log(
                            Priority => 'error',
                            Message  => 'Can not require auth sync backend module "' . $SyncConfig->{Module} . '": ' . $@
                        );

                        next SYNCCONFIG;
                    }

                    # init auth sync entry
                    my %AuthSyncEntry = ();

                    # load sync module
                    $AuthSyncEntry{BackendObject} = $SyncModule->new(
                        Config => {
                            %{ $Config->{Config} || {} },
                            %{ $SyncConfig->{Config} || {} }
                        }
                    );
                    next SYNCCONFIG if ( !defined( $AuthSyncEntry{BackendObject} ) );

                    # check if backend can handle at least method "Auth"
                    if ( !$AuthSyncEntry{BackendObject}->can('Sync') ) {
                        $Kernel::OM->Get('Log')->Log(
                            Priority => 'error',
                            Message  => 'Auth sync backend module "' . $SyncConfig->{Module} . '" can not handle method "Sync"!'
                        );

                        next SYNCCONFIG;
                    }

                    # set global config in module
                    $AuthSyncEntry{BackendObject}->{Config} = Storable::dclone( $SyncConfig );

                    # add entry
                    push( @{ $AuthEntry{Sync} }, \%AuthSyncEntry );
                }
            }

            # add entry
            push( @{ $Self->{AuthConfig} }, \%AuthEntry );
        }
    }

    # init auth config with empty array
    $Self->{MultiFactorAuthConfig} = [];

    # handle multi factor auth config
    my $MultiFactorAuthConfigRef = $Kernel::OM->Get('Config')->Get('MultiFactorAuthentication');
    if ( IsHashRefWithData( $MultiFactorAuthConfigRef ) ) {
        # load multi factor auth module for each enabled config
        MULTIFACTORAUTHCONFIG:
        for my $MFAuthReg ( sort( keys( %{ $MultiFactorAuthConfigRef } ) ) ) {
            # check config data structure
            if ( !IsArrayRefWithData( $MultiFactorAuthConfigRef->{ $MFAuthReg } ) ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Invalid multi factor auth config "' . $MFAuthReg . '". Need array with data!'
                );

                next MULTIFACTORAUTHCONFIG;
            }

            MFACONFIG:
            for my $MFAConfig ( @{ $MultiFactorAuthConfigRef->{ $MFAuthReg } } ) {

                # check entry data structure
                if ( !IsHashRefWithData( $MFAConfig ) ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => 'Invalid multi factor auth config entry in "' . $MFAuthReg . '". Need hash with data!'
                    );

                    next MFACONFIG;
                }

                # skip disabled entry
                next MFACONFIG if ( !$MFAConfig->{Enabled} );

                # check needed stuff
                for my $Needed ( qw(Name Module) ) {
                    if ( !$MFAConfig->{ $Needed } ) {
                        $Kernel::OM->Get('Log')->Log(
                            Priority => 'error',
                            Message  => 'Invalid multi factor auth config entry in "' . $MFAuthReg . '". No "' . $Needed . '" given!'
                        );

                        next MFACONFIG;
                    }
                }

                # lookup module alias
                my $MFAModule = $Kernel::OM->GetModuleFor( $MFAConfig->{Module} ) || $MFAConfig->{Module};

                # require module
                if ( !$Kernel::OM->Get('Main')->Require( $MFAModule ) ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => 'Can not require multi factor auth backend module "' . $MFAConfig->{Module} . '": ' . $@
                    );

                    next MFACONFIG;
                }

                # init auth entry
                my %MultiFactorAuthEntry = (
                    Name         => $MFAConfig->{Name},
                    AuthType     => $MFAConfig->{AuthType},
                    UsageContext => $MFAConfig->{UsageContext}
                );

                # get backend instance
                $MultiFactorAuthEntry{BackendObject} = $MFAModule->new(
                    Name   => $MFAConfig->{Name},
                    Config => $MFAConfig->{Config}
                );
                next MFACONFIG if ( !defined( $MultiFactorAuthEntry{BackendObject} ) );

                # check if backend can handle at least method "Auth"
                if ( !$MultiFactorAuthEntry{BackendObject}->can('MFAuth') ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => 'Multi factor auth backend module "' . $MFAConfig->{Module} . '" can not handle method "MFAuth"!'
                    );

                    next MFACONFIG;
                }

                # set global config in module
                $MultiFactorAuthEntry{BackendObject}->{Config} = Storable::dclone( $MFAConfig );

                # add entry
                push( @{ $Self->{MultiFactorAuthConfig} }, \%MultiFactorAuthEntry );
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
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
            }
            return;
        }
    }

    # init hash for available pre auth types
    my %PreAuthTypesHash = ();

    AUTH:
    for my $Auth ( @{ $Self->{AuthConfig} } ) {
        # skip non relevant UsageContext
        next AUTH if (
            defined $Auth->{UsageContext}
            && $Auth->{UsageContext} ne $Param{UsageContext}
        );

        # skip backends that can not handle method PreAuth or GetPreAuthType
        next AUTH if (
            !$Auth->{BackendObject}->can('PreAuth')
            || !$Auth->{BackendObject}->can('GetPreAuthType')
        );

        # get PreAuthType of auth backend
        my $PreAuthType = $Auth->{BackendObject}->GetPreAuthType(
            Silent => $Param{Silent}
        );

        # check PreAuthType result
        if ( !$PreAuthType ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Got invalid PreAuthType from backend!'
                );
            }

            next AUTH;
        }

        # add available pre auth type
        $PreAuthTypesHash{ $PreAuthType } = 1;
    }

    # map available pre auth type to sorted array
    my @PreAuthTypes = sort( keys( %PreAuthTypesHash ) );

    return \@PreAuthTypes;
}

=item GetMFAuthTypes()

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
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
            }
            return;
        }
    }

    # init hash for available multi factor auth types
    my %MFAuthTypesHash = ();

    MULTIFACTORAUTH:
    for my $MFAuth ( @{ $Self->{MultiFactorAuthConfig} } ) {
        # skip non relevant UsageContext
        next MULTIFACTORAUTH if (
            defined $MFAuth->{UsageContext}
            && $MFAuth->{UsageContext} ne $Param{UsageContext}
        );

        # skip backends that can not handle method MFAuthType
        next MULTIFACTORAUTH if ( !$MFAuth->{BackendObject}->can('GetMFAuthType') );

        # get MFAuthType of multi factor auth backend
        my $MFAuthType = $MFAuth->{BackendObject}->GetMFAuthType(
            Silent => $Param{Silent}
        );

        # check MFAuthType result
        if ( !$MFAuthType ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Got invalid MFAuthType from backend!'
                );
            }

            next MULTIFACTORAUTH;
        }

        # add available multi factor auth type
        $MFAuthTypesHash{ $MFAuthType } = 1;
    }

    # map available multi factor auth type to sorted array
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
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
            }
            return;
        }
    }

    # init array for available auth methods
    my @AuthMethods = ();

    AUTH:
    for my $Auth ( @{ $Self->{AuthConfig} } ) {
        # skip non relevant UsageContext
        next AUTH if (
            defined $Auth->{UsageContext}
            && $Auth->{UsageContext} ne $Param{UsageContext}
        );

        # skip backends that can not handle method AuthMethod
        next AUTH if ( !$Auth->{BackendObject}->can('GetAuthMethod') );

        # get AuthMethod of auth backend
        my $AuthMethod = $Auth->{BackendObject}->GetAuthMethod(
            Silent => $Param{Silent}
        );

        # check AuthMethod result
        if (
            ref( $AuthMethod ) ne 'HASH'
            || !$AuthMethod->{Type}
            || !defined( $AuthMethod->{PreAuth} )
        ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Got invalid AuthMethod from backend!"
                );
            }

            next AUTH;
        }

        # init array for available multi factor auth methods
        my @MFAuthMethods = ();

        MULTIFACTORAUTH:
        for my $MFAuth ( @{ $Self->{MultiFactorAuthConfig} } ) {
            # skip non relevant AuthType
            next MULTIFACTORAUTH if (
                defined $MFAuth->{AuthType}
                && $MFAuth->{AuthType} ne $AuthMethod->{Type}
            );

            # skip non relevant UsageContext
            next MULTIFACTORAUTH if (
                defined $MFAuth->{UsageContext}
                && $MFAuth->{UsageContext} ne $Param{UsageContext}
            );

            # skip backends that can not handle method MFAuthType
            next MULTIFACTORAUTH if ( !$MFAuth->{BackendObject}->can('GetMFAuthMethod') );

            # get MFAuthMethod of multi factor auth backend
            my $MFAuthMethod = $MFAuth->{BackendObject}->GetMFAuthMethod(
                Silent => $Param{Silent}
            );

            if (
                ref( $MFAuthMethod ) ne 'HASH'
                || !$MFAuthMethod->{Type}
                || ref( $MFAuthMethod->{Data} ) ne 'HASH'
            ) {
                if ( !$Param{Silent} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Got invalid MFAuthMethod from backend!"
                    );
                }

                next MULTIFACTORAUTH;
            }

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

        # add multi factor auth entries
        $AuthMethod->{MFA} = \@MFAuthMethods;

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
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
            }
            return;
        }
    }

    AUTH:
    for my $Auth ( @{ $Self->{AuthConfig} } ) {
        # skip non relevant UsageContext
        next AUTH if (
            defined $Auth->{UsageContext}
            && $Auth->{UsageContext} ne $Param{UsageContext}
        );

        # skip backends that can not handle method PreAuth
        next AUTH if ( !$Auth->{BackendObject}->can('PreAuth') );

        # get pre auth data from backend
        my $PreAuthData = $Auth->{BackendObject}->PreAuth( %Param );

        # return data if we got a defined result
        return $PreAuthData if ( defined( $PreAuthData ) );
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
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
            }
            return;
        }
    }

    my $User;
    my $UserID;

    AUTH:
    for my $Auth ( @{ $Self->{AuthConfig} } ) {
        # skip non relevant UsageContext
        next AUTH if (
            defined $Auth->{UsageContext}
            && $Auth->{UsageContext} ne $Param{UsageContext}
        );

        # get auth data from backend
        $User = $Auth->{BackendObject}->Auth( %Param );

        # skip, if auth backend does not provide a user login
        next AUTH if ( !$User );

        # Sync will happen before two factor authentication (if configured)
        # because user might not exist before being created in sync (see bug #11966).
        # A failed two factor auth after successful sync will result
        # in a new or updated user but no information or permission leak.

        for my $Sync ( @{ $Auth->{Sync} } ) {
            # sync configured backend
            $Sync->{BackendObject}->Sync(
                %Param,
                User => $User
            );
        }

        # try to get valid user by login
        my %UserData = $Kernel::OM->Get('User')->GetUserData(
            User  => $User,
            Valid => 1,
        );
        if (
            !%UserData
            || (
                $Param{UsageContext} eq 'Agent'
                && !$UserData{IsAgent}
            )
            || (
                $Param{UsageContext} eq 'Customer'
                && !$UserData{IsCustomer}
            )
        ) {
            $User   = undef;
            $UserID = undef;

            next AUTH;
        }

        # get user id from data
        $UserID = $UserData{UserID};

        # only handle multi factor auth, if auth backend can provide a auth method type
        if ( $Auth->{BackendObject}->can('GetAuthMethod') ) {

            # get AuthMethod of auth backend
            my $AuthMethod = $Auth->{BackendObject}->GetAuthMethod();
            if (
                ref( $AuthMethod ) eq 'HASH'
                && $AuthMethod->{Type}
            ) {
                # init multi factor auth state
                my $MFAState = undef;

                MULTIFACTORAUTH:
                for my $MFAuth ( @{ $Self->{MultiFactorAuthConfig} } ) {
                    # skip non relevant AuthType
                    next MULTIFACTORAUTH if (
                        defined $MFAuth->{AuthType}
                        && $MFAuth->{AuthType} ne $AuthMethod->{Type}
                    );

                    # skip non relevant UsageContext
                    next MULTIFACTORAUTH if (
                        defined $MFAuth->{UsageContext}
                        && $MFAuth->{UsageContext} ne $Param{UsageContext}
                    );

                    # check multi factor auth backend
                    my $MFAResult = $MFAuth->{BackendObject}->MFAuth(
                        %Param,
                        User   => $User,
                        UserID => $UserID
                    );
                    if ( defined( $MFAResult ) ) {
                        $MFAState = $MFAResult;
                    }

                    # no more checks needed when one mfa check was successful
                    if ( $MFAState ) {
                        last MULTIFACTORAUTH;
                    }
                }

                # if at least one multi factor auth backend was checked but none was successful,
                # it counts as a failed login
                # Reset user and try next authentification
                if (
                    defined( $MFAState )
                    && !$MFAState
                ) {
                    $User   = undef;
                    $UserID = undef;

                    next AUTH;
                }
            }
        }

        # remember auth backend
        my $Success = $Kernel::OM->Get('User')->SetPreferences(
            Key    => 'UserAuthBackend',
            Value  => $Auth->{Name},
            UserID => $UserID,
        );
        if ( !$Success ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Error while setting preference "UserAuthBackend"'
            );
        }

        last AUTH;
    }

    # handle failed login
    if ( !$User ) {

        # if parameter User was given, remember failed login
        if ( $Param{User} ) {
            # get user by login
            my %UserData = $Kernel::OM->Get('User')->GetUserData(
                User => $Param{User},
            );
            return if ( !%UserData );

            # increment current failed login count
            my $FailedCount = $UserData{Preferences}->{UserLoginFailed} || 0;
            $FailedCount++;

            # update failed login count
            $Kernel::OM->Get('User')->SetPreferences(
                Key    => 'UserLoginFailed',
                Value  => $FailedCount,
                UserID => $UserData{UserID},
            );

            # no need to check PasswordMaxLoginFailed if user is already invalid
            return if ( $UserData{ValidID} != 1 );

            # set user to invalid-temporarily if max failed logins reached
            my $Config = $Kernel::OM->Get('Config')->Get('PreferencesGroups');
            my $PasswordMaxLoginFailed;
            if (
                $Config
                && $Config->{Password}
                && $Config->{Password}->{PasswordMaxLoginFailed}
            ) {
                $PasswordMaxLoginFailed = $Config->{Password}->{PasswordMaxLoginFailed};
            }
            # skip if config is not set
            return if ( !$PasswordMaxLoginFailed );

            # skip if failed login count is not reached
            return if ( $FailedCount < $PasswordMaxLoginFailed );

            # lookup valid id for invalid-temporarily
            my $ValidID = $Kernel::OM->Get('Valid')->ValidLookup(
                Valid => 'invalid-temporarily',
            );

            # remove UserPw from update data to keep current password
            delete( $UserData{UserPw} );

            # set user invalid-temporarily
            my $Update = $Kernel::OM->Get('User')->UserUpdate(
                %UserData,
                ValidID      => $ValidID,
                ChangeUserID => 1,
            );
            if ( !$Update ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Could not set user with login "' . $UserData{UserLogin}  . '" invalid-temporarily!',
                );
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'notice',
                    Message  => 'Login failed ' . $FailedCount . ' times. Set user with login "' . $UserData{UserLogin} . 'invalid-temporarily.',
                );
            }
        }

        return;
    }

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
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
            }
            return 0;
        }
    }

    # handle multi factor auth
    MULTIFACTORAUTH:
    for my $MFAuth ( @{ $Self->{MultiFactorAuthConfig} } ) {
        # skip backends that can not handle method GenerateSecret
        next MULTIFACTORAUTH if ( !$MFAuth->{BackendObject}->can('GenerateSecret') );

        my $Secret = $MFAuth->{BackendObject}->GenerateSecret( %Param );

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
