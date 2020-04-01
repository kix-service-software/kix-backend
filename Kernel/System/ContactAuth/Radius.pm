# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ContactAuth::Radius;

use strict;
use warnings;

use Authen::Radius;

our @ObjectDependencies = (
    'Config',
    'Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # Debug 0=off 1=on
    $Self->{Debug} = 0;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # get config
    $Self->{Die} = $ConfigObject->Get( 'Contact::AuthModule::Radius::Die' . $Param{Count} );

    # get user table
    $Self->{RadiusHost} = $ConfigObject->Get( 'Contact::AuthModule::Radius::Host' . $Param{Count} )
        || die "Need Contact::AuthModule::Radius::Host$Param{Count} in Kernel/Config.pm";
    $Self->{RadiusSecret} = $ConfigObject->Get( 'Contact::AuthModule::Radius::Password' . $Param{Count} )
        || die "Need Contact::AuthModule::Radius::Password$Param{Count} in Kernel/Config.pm";

    return $Self;
}

sub GetOption {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{What} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need What!"
        );
        return;
    }

    # module options
    my %Option = (
        PreAuth => 0,
    );

    # return option
    return $Option{ $Param{What} };
}

sub Auth {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{User} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need User!"
        );
        return;
    }

    # get params
    my $User       = $Param{User}      || '';
    my $Pw         = $Param{Pw}        || '';
    my $RemoteAddr = $ENV{REMOTE_ADDR} || 'Got no REMOTE_ADDR env!';
    my $UserID     = '';
    my $GetPw      = '';

    # just in case for debug!
    if ( $Self->{Debug} > 0 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "User: '$User' tried to authenticate with Pw: '$Pw' ($RemoteAddr)",
        );
    }

    # just a note
    if ( !$User ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "No User given!!! (REMOTE_ADDR: $RemoteAddr)",
        );
        return;
    }

    # just a note
    if ( !$Pw ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "User: $User Authentication without Pw!!! (REMOTE_ADDR: $RemoteAddr)",
        );
        return;
    }

    # Create a radius object
    my $Radius = Authen::Radius->new(
        Host   => $Self->{RadiusHost},
        Secret => $Self->{RadiusSecret},
    );
    if ( !$Radius ) {
        if ( $Self->{Die} ) {
            die "Can't connect to $Self->{RadiusHost}: $@";
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't connect to $Self->{RadiusHost}: $@",
            );
            return;
        }
    }
    my $AuthResult = $Radius->check_pwd( $User, $Pw );

    # login note
    if ( defined($AuthResult) && $AuthResult == 1 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "User: $User Authentication ok (REMOTE_ADDR: $RemoteAddr).",
        );
        return $User;
    }

    # just a note
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "User: $User Authentication with wrong Pw!!! (REMOTE_ADDR: $RemoteAddr)"
        );
        return;
    }
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
