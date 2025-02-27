# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Auth::HTTPBasicAuth;

use strict;
use warnings;

our @ObjectDependencies = (
    'Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Replace}       = $Param{Config}->{Replace};
    $Self->{ReplaceRegExp} = $Param{Config}->{ReplaceRegExp};
    $Self->{Debug}         = $Param{Config}->{Debug} || 0;

    return $Self;
}

sub Auth {
    my ( $Self, %Param ) = @_;

    # get params
    my $User       = $ENV{REMOTE_USER} || $ENV{HTTP_REMOTE_USER};
    my $RemoteAddr = $ENV{REMOTE_ADDR} || 'Got no REMOTE_ADDR env!';

    # just a note
    if ( !$User ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "[Auth::HTTPBasicAuth] No User given by environment REMOTE_USER and HTTP_REMOTE_USER! "
                . "(REMOTE_ADDR: '$RemoteAddr', Backend: '$Self->{Config}->{Name}')",
        );
        return;
    }

    # just in case for debug
    if ( $Self->{Debug} > 0 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'debug',
            Message  => "[Auth::HTTPBasicAuth] User '$User' tried to authenticate. "
                . "(REMOTE_ADDR: '$RemoteAddr', Backend: '$Self->{Config}->{Name}')",
        );
    }

    # replace login parts
    if ( $Self->{Replace} ) {
        $User =~ s/^\Q$Self->{Replace}\E//;

        # just in case for debug
        if ( $Self->{Debug} > 0 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "[Auth::HTTPBasicAuth] Pattern '$Self->{Replace}' removed from given User. "
                    . "(REMOTE_ADDR: '$RemoteAddr', Backend: '$Self->{Config}->{Name}')",
            );
        }
    }

    # regexp on login
    if ( $Self->{ReplaceRegExp} ) {
        $User =~ s/$Self->{ReplaceRegExp}/$1/;

        # just in case for debug
        if ( $Self->{Debug} > 0 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "[Auth::HTTPBasicAuth] Pattern '$Self->{ReplaceRegExp}' replaced by first capture group for given User. "
                    . "(REMOTE_ADDR: '$RemoteAddr', Backend: '$Self->{Config}->{Name}')",
            );
        }
    }

    # log
    $Kernel::OM->Get('Log')->Log(
        Priority => 'notice',
        Message  => "[Auth::HTTPBasicAuth] User '$User' authentication ok. "
            . "(REMOTE_ADDR: '$RemoteAddr', Backend: '$Self->{Config}->{Name}')",
    );

    return $User;
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
