# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package scripts::test::system::PostMaster::Filter::UnitTest;

use strict;
use warnings;

# prevent 'Used once' warning for Kernel::OM
use Kernel::System::ObjectManager;

our @ObjectDependencies = qw(
    Main
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    if ( ref( $Param{JobConfig}->{Set} ) eq 'HASH' ) {
        for my $Key ( %{ $Param{JobConfig}->{Set} } ) {
            $Param{GetParam}->{ $Key } = $Param{JobConfig}->{Set}->{ $Key };
        }
    }

    return $Param{JobConfig}->{ReturnValue};
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
