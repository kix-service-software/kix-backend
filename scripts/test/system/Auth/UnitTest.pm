# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package scripts::test::system::Auth::UnitTest;

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

    if ( ref( $Param{Config} ) ne 'HASH' ) {
        die 'Need Config as hash ref!';
    }

    # reset ISA
    @scripts::test::system::Auth::UnitTest::ISA = ();

    for my $Method ( keys( %{ $Param{Config} } ) ) {
        my $SubModule = 'scripts::test::system::Auth::submodules::' . $Method;

        if ( !$Kernel::OM->Get('Main')->RequireBaseClass($SubModule) ) {
            die "Can't load unittest sub module $SubModule! $@";
        }
    }

    $Self->{ReturnValues} = $Param{Config};

    return $Self;
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
