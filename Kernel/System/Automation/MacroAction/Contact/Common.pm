# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Contact::Common;

use strict;
use warnings;

use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Common);

our @ObjectDependencies = (
    'Contact',
    'Log',
);

=item _CheckParams()

Check if all required parameters are given.

Example:
    my $Result = $Object->_CheckParams(
        ContactID => 123,
        Config    => {
            ...
        }
    );

=cut

sub _CheckParams {
    my ( $Self, %Param ) = @_;

    return if !$Self->SUPER::_CheckParams(%Param);

    return 1 if ($Param{NoContactIDCheckNeeded});

    # check needed stuff
    if ( !$Param{ContactID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "_CheckParams: Need ContactID!",
        );
        return;
    }

    my $Email = $Kernel::OM->Get('Contact')->ContactLookup(
        ID     => $Param{ContactID},
        Silent => 1
    );

    if (!$Email) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "_CheckParams: No contact found with ID '$Param{ContactID}'!",
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
