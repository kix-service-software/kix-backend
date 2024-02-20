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

our @ObjectDependencies = (
    'Config',
    'Log',
    'Main',
    'SystemMaintenance',
    'Time',
    'User',
    'Valid',
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

    # get needed objects
    my $MainObject   = $Kernel::OM->Get('Main');
    my $ConfigObject = $Kernel::OM->Get('Config');

    my $AuthConfigRef = $ConfigObject->Get("Authentication");

    if ( !IsHashRefWithData($AuthConfigRef) ) {
        $MainObject->Die("Invalid Authentication config!");
    }

    # create clone to keep the original
    $Self->{AuthConfig} =  Storable::dclone($AuthConfigRef);

    # load auth module for each enabled config
    foreach my $AuthReg ( sort keys %{$Self->{AuthConfig}} ) {
        if ( !IsArrayRefWithData($Self->{AuthConfig}->{$AuthReg}) ) {
            $MainObject->Die("Invalid Authentication config ($AuthReg)!");
        }

        foreach my $Config ( @{$Self->{AuthConfig}->{$AuthReg}} ) {
            next if !$Config->{Enabled} || !$Config->{Module};

            my $Module = $Kernel::OM->GetModuleFor($Config->{Module}) || $Config->{Module};

            if ( !$MainObject->Require($Module) ) {
                $MainObject->Die("Can't load auth backend module $Config->{Module}! $@");
            }

            $Config->{BackendObject} = $Module->new(
                Name   => $Config->{Name},
                Config => $Config->{Config}
            );

            # set global config in module
            $Config->{BackendObject}->{Config} = $Config;

            if ( IsArrayRefWithData($Config->{Sync}) ) {
                foreach my $SyncConfig ( @{$Config->{Sync}} ) {
                    next if !$SyncConfig->{Enabled} || !$SyncConfig->{Module};

                    my $SyncModule = $Kernel::OM->GetModuleFor($SyncConfig->{Module}) || $SyncConfig->{Module};

                    if ( !$MainObject->Require($SyncModule) ) {
                        $MainObject->Die("Can't load auth sync backend module $SyncConfig->{Module}! $@");
                    }
                    # load sync module
                    $SyncConfig->{BackendObject} = $SyncModule->new(
                        Config => {
                            %{$Config->{Config} || {}},
                            %{$SyncConfig->{Config} || {}}
                        }
                    );
                }
            }
        }
    }

    # load 2factor auth modules
    COUNT:
    for my $Count ( '', 1 .. 10 ) {

        my $GenericModule = $ConfigObject->Get("AuthTwoFactorModule$Count");

        next COUNT if !$GenericModule;

        if ( !$MainObject->Require($GenericModule) ) {
            $MainObject->Die("Can't load backend module $GenericModule! $@");
        }

        $Self->{"AuthTwoFactorBackend$Count"} = $GenericModule->new( %{$Self}, Count => $Count );
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

=item GetAuthMethods()

get possible auth methods
    my $AuthMethods = $AuthObject->GetAuthMethods(
        UsageContext => 'Agent',       # (Agent|Customer)
    );

Returns:

    $AuthMethods = [
        {
            Type    => 'LOGIN',
            PreAuth => 0
        }
    ];

=cut

sub GetAuthMethods {
    my ( $Self, %Param ) = @_;

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
            my $PreAuthData = $Config->{BackendObject}->PreAuth(%Param);

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

    # get needed objects
    my $UserObject   = $Kernel::OM->Get('User');
    my $ConfigObject = $Kernel::OM->Get('Config');

    my $User;

    AUTHREG:
    foreach my $AuthReg ( sort keys %{$Self->{AuthConfig}} ) {

        CONFIG:
        foreach my $Config ( @{$Self->{AuthConfig}->{$AuthReg}} ) {

            next CONFIG if !$Config->{Enabled} || !$Config->{BackendObject};
            next CONFIG if defined $Config->{UsageContext} && $Config->{UsageContext} ne $Param{UsageContext};

            # check auth backend
            $User = $Config->{BackendObject}->Auth(%Param);

            # next on no success
            next CONFIG if !$User;

            # Sync will happen before two factor authentication (if configured)
            # because user might not exist before being created in sync (see bug #11966).
            # A failed two factor auth after successful sync will result
            # in a new or updated user but no information or permission leak.

            # if $AuthSyncBackend is defined but empty, don't sync with any backend
            if ( IsArrayRefWithData($Config->{Sync}) ) {

                SYNC_CONFIG:
                foreach my $SyncConfig ( @{$Config->{Sync}} ) {
                    next SYNC_CONFIG if !$SyncConfig->{Enabled} || !$SyncConfig->{BackendObject};

                    # sync configured backend
                    $SyncConfig->{BackendObject}->Sync( %Param, User => $User );
                }
            }

            # If we have no UserID at this point
            # it means auth was ok but user didn't exist before
            # and wasn't created in sync module.
            # We will skip two factor authentication even if configured
            # because we don't have user data to compare the otp anyway.
            # This will not count as a failed login.
            my $UserID = $UserObject->UserLookup(
                UserLogin => $User,
            );
            last CONFIG if !$UserID;

            # check 2factor auth backends
            my $TwoFactorAuth;
            TWOFACTORSOURCE:
            for my $Count ( '', 1 .. 10 ) {

                # return on no config setting
                next TWOFACTORSOURCE if !$Self->{"AuthTwoFactorBackend$Count"};

                # 2factor backend
                my $AuthOk = $Self->{"AuthTwoFactorBackend$Count"}->Auth(
                    TwoFactorToken => $Param{TwoFactorToken},
                    User           => $User,
                    UserID         => $UserID,
                    Silent         => $Param{Silent}
                );
                $TwoFactorAuth = $AuthOk ? 'passed' : 'failed';

                last TWOFACTORSOURCE if $AuthOk;
            }

            # if at least one 2factor auth backend was checked but none was successful,
            # it counts as a failed login
            if ( $TwoFactorAuth && $TwoFactorAuth ne 'passed' ) {
                $User = undef;
                last CONFIG;
            }

            # remember auth backend
            $UserObject->SetPreferences(
                Key    => 'UserAuthBackend',
                Value  => $Config->{Name},
                UserID => $UserID,
            );

            last AUTHREG;
        }
    }

    # check usage context
    if ( $Param{UsageContext} && $User ) {
        # remember failed logins
        my $UserID = $UserObject->UserLookup(
            UserLogin => $User,
        );

        return if !$UserID;

        my %UserData = $UserObject->GetUserData(
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
            my $UserID = $UserObject->UserLookup(
                UserLogin => $Param{User},
                Silent    => 1,
            );

            return if !$UserID;

            my %UserData = $UserObject->GetUserData(
                UserID => $UserID,
                Valid  => 1,
            );

            my $Count = $UserData{Preferences}->{UserLoginFailed} || 0;
            $Count++;

            $UserObject->SetPreferences(
                Key    => 'UserLoginFailed',
                Value  => $Count,
                UserID => $UserID,
            );

            # set agent to invalid-temporarily if max failed logins reached
            my $Config = $ConfigObject->Get('PreferencesGroups');
            my $PasswordMaxLoginFailed;

            if ( $Config && $Config->{Password} && $Config->{Password}->{PasswordMaxLoginFailed} ) {
                $PasswordMaxLoginFailed = $Config->{Password}->{PasswordMaxLoginFailed};
            }

            return if !%UserData;
            return if !$PasswordMaxLoginFailed;
            return if $Count < $PasswordMaxLoginFailed;

            my $ValidID = $Kernel::OM->Get('Valid')->ValidLookup(
                Valid => 'invalid-temporarily',
            );

            my $Update = $UserObject->UserUpdate(
                %UserData,
                ValidID      => $ValidID,
                ChangeUserID => 1,
            );

            return if !$Update;

            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "Login failed $Count times. Set $UserData{UserLogin} to "
                    . "'invalid-temporarily'.",
            );
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "Login failed.",
            );
        }

        return;
    }

    # remember login attributes
    my $UserID = $UserObject->UserLookup(
        UserLogin => $User,
    );

    return $User if !$UserID;

    # reset failed logins
    $UserObject->SetPreferences(
        Key    => 'UserLoginFailed',
        Value  => 0,
        UserID => $UserID,
    );

    # last login preferences update
    $UserObject->SetPreferences(
        Key    => 'UserLastLogin',
        Value  => $Kernel::OM->Get('Time')->SystemTime(),
        UserID => $UserID,
    );

    return $User;
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
