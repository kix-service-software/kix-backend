# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package scripts::test::system::ObjectManager::Dummy;    ## no critic

use strict;
use warnings;

our @ObjectDependencies = ();                   # we want to use an undeclared dependency for testing

sub new {
    my ( $Class, %Param ) = @_;

    bless \%Param, $Class;
}

sub Data {
    my ($Self) = @_;
    return $Self->{Data};
}

sub DESTROY {

    # Request this object (undeclared dependency) in the desctructor.
    #   This will create it again in the OM to test that ObjectsDiscard will still work.
    $Kernel::OM->Get('scripts::test::system::ObjectManager::Dummy2');
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
