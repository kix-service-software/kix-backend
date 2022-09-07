# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
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

            if ( !$MainObject->Require($Config->{Module}) ) {
                $MainObject->Die("Can't load auth backend module $Config->{Module}! $@");
            }

            $Config->{BackendObject} = $Config->{Module}->new(Config => $Config->{Config});

            # set global config in module
            $Config->{BackendObject}->{Config} = $Config;

            if ( IsArrayRefWithData($Config->{Sync}) ) {
                foreach my $SyncConfig ( @{$Config->{Sync}} ) {
                    next if !$SyncConfig->{Enabled} || !$SyncConfig->{Module};

                    if ( !$MainObject->Require($SyncConfig->{Module}) ) {
                        $MainObject->Die("Can't load auth sync backend module $SyncConfig->{Module}! $@");
                    }
                    # load sync module
                    $SyncConfig->{BackendObject} = $SyncConfig->{Module}->new(
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

=item GetOption()

Get module options. Currently there is just one option, "PreAuth".

    if ( $AuthObject->GetOption( What => 'PreAuth' ) ) {
        print "No login screen is needed. Authentication is based on some other options. E. g. $ENV{REMOTE_USER}\n";
    }

=cut

sub GetOption {
    my ( $Self, %Param ) = @_;

    return $Self->{AuthBackend}->GetOption(%Param);
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

            my $Count = $UserData{UserLoginFailed} || 0;
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

    # on system maintenance just admin users
    # should be allowed to get into the system
    my $ActiveMaintenance = $Kernel::OM->Get('SystemMaintenance')->SystemMaintenanceIsActive();

    # reset failed logins
    $UserObject->SetPreferences(
        Key    => 'UserLoginFailed',
        Value  => 0,
        UserID => $UserID,
    );

    # check if system maintenance is active
    if ($ActiveMaintenance) {

        # TODO!!! rbo-190327
        # # check if user is allow to login
        # # get current user groups
        # my %Groups = $Kernel::OM->Get('Group')->PermissionUserGet(
        #     UserID => $UserID,
        #     Type   => 'move_into',
        # );

        # # reverse groups hash for easy look up
        # %Groups = reverse %Groups;

        # # check if the user is in the Admin group
        # # if that is not the case return
        # if ( !$Groups{admin} ) {

        #     $Self->{LastErrorMessage} =
        #         $ConfigObject->Get('SystemMaintenance::IsActiveDefaultLoginErrorMessage')
        #         || Translatable("It is currently not possible to login due to a scheduled system maintenance.");

        #     return;
        # }
    }

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
