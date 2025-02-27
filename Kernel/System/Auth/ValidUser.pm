# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Auth::ValidUser;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Config}->{Debug} // 0;

    return $Self;
}

sub Auth {
    my ( $Self, %Param ) = @_;

    # get params
    my @Addresses = ( $ENV{REMOTE_ADDR} || 'Got no REMOTE_ADDR env!' );
    if ( IsArrayRefWithData( $Param{RemoteAddresses} ) ) {
        @Addresses = @{ $Param{RemoteAddresses} };
    }
    my $AddrString = join(',', @Addresses);

    # just a note
    if ( !$Param{User} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "[Auth::ValidUser] No User given. "
                . "(REMOTE_ADDR: '$AddrString', Backend: '$Self->{Config}->{Name}')",
        );
        return;
    }

    # check client IP whitelist if available
    if ( IsHashRefWithData($Self->{Config}->{Config}) && IsArrayRefWithData($Self->{Config}->{Config}->{RelevantClientIPs}) ) {
        my $Allowed = 0;

        ALLOW:
        foreach my $Allow ( @{$Self->{Config}->{Config}->{RelevantClientIPs}} ) {
            foreach my $RemoteAddr ( @Addresses ) {
                if ( $RemoteAddr =~ /$Allow/smx ) {
                    $Allowed = 1;
                    last ALLOW;
                }
            }
        }

        # do nothing, because the client IP isn't relevant for us
        if ( !$Allowed ) {
            if ( $Self->{Debug} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'debug',
                    Message  => "[Auth::ValidUser] Client IP does not match RelevantClientIPs config. "
                        . "(REMOTE_ADDR: '$AddrString', Backend: '$Self->{Config}->{Name}')",
                );
            }
            return;
        }
    }

    # check user whitelist if available
    if ( IsHashRefWithData($Self->{Config}->{Config}) && IsArrayRefWithData($Self->{Config}->{Config}->{RelevantUsers}) ) {
        my $Allowed = 0;
        ALLOW:
        foreach my $Allow ( @{$Self->{Config}->{Config}->{RelevantUsers}} ) {
            if ( $Param{User} =~ /$Allow/smx ) {
                $Allowed = 1;
                last ALLOW;
            }
        }
        # do nothing, because the user isn't relevant for us
        if ( !$Allowed ) {
            if ( $Self->{Debug} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'debug',
                    Message  => "[Auth::ValidUser] User '$Param{User}' does not match RelevantUsers config. "
                        . "(REMOTE_ADDR: '$AddrString', Backend: '$Self->{Config}->{Name}')",
                );
            }
            return;
        }
    }

    my %UserData = $Kernel::OM->Get('User')->GetUserData(
        User => $Param{User},
    );

    # return on no valid user
    if ( !IsHashRefWithData(\%UserData) || $UserData{ValidID} != 1 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "[Auth::ValidUser] User '$Param{User}' is not a valid user. "
                . "(REMOTE_ADDR: '$AddrString', Backend: '$Self->{Config}->{Name}')",
        );
        return;
    }

    # log
    $Kernel::OM->Get('Log')->Log(
        Priority => 'notice',
        Message  => "[Auth::ValidUser] User '$Param{User}' authentication ok. "
            . "(REMOTE_ADDR: '$AddrString', Backend: '$Self->{Config}->{Name}')",
    );

    return $Param{User};
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
