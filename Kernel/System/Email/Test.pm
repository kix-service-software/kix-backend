# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Email::Test;

use strict;
use warnings;

our @ObjectDependencies = (
    'Cache',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{CacheKey}  = 'Emails';
    $Self->{CacheType} = 'EmailTest';

    return $Self;
}

sub Send {
    my ( $Self, %Param ) = @_;

    # get already stored emails from cache
    my $Emails = $Kernel::OM->Get('Cache')->Get(
        Key  => $Self->{CacheKey},
        Type => $Self->{CacheType},
    ) // [];

    push @{$Emails}, \%Param;

    $Kernel::OM->Get('Cache')->Set(
        Key   => $Self->{CacheKey},
        Type  => $Self->{CacheType},
        Value => $Emails,
        TTL   => 60 * 60 * 24,
    );

    return 1;
}

sub EmailsGet {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('Cache')->Get(
        Key  => $Self->{CacheKey},
        Type => $Self->{CacheType},
    ) // [];
}

sub CleanUp {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
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
