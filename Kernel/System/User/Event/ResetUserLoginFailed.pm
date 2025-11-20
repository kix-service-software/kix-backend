# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::User::Event::ResetUserLoginFailed;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Log
    User
);

use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for ( qw(Data Event Config) ) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    for ( qw(NewUser OldUser) ) {
        if ( !IsHashRefWithData( $Param{Data}->{ $_ } ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_ in Data!"
            );
            return;
        }
    }

    # check for existing user
    my $UserLogin = $Kernel::OM->Get('User')->UserLookup(
        UserID => $Param{Data}->{NewUser}->{UserID},
        Silent => 1,
    );
    return 1 if ( !$UserLogin );

    return 1 if (
        $Param{Data}->{NewUser}->{ValidID} != 1
        || $Param{Data}->{OldUser}->{ValidID} == 1
    );

    # reset failed logins
    my $Success = $Kernel::OM->Get('User')->SetPreferences(
        Key    => 'UserLoginFailed',
        Value  => 0,
        UserID => $Param{Data}->{NewUser}->{UserID},
    );
    if ( !$Success ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Could not reset preference "UserLoginFailed" for user (' . $Param{NewUser}->{UserID} . ')!'
        );
        return;
    }

    return 1;
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
