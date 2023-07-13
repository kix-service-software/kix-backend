# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::LoopProtection;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Main',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub SendEmail {
    my ( $Self, %Param ) = @_;

    # get configured backend module
    my $BackendModule = $Kernel::OM->Get('Config')->Get('LoopProtectionModule')
        || 'PostMaster::LoopProtection::DB';

    # get backend object
    my $BackendObject = $Kernel::OM->Get($BackendModule);

    if ( !$BackendObject ) {

        # get main object
        my $MainObject = $Kernel::OM->Get('Main');

        $MainObject->Die("Can't load loop protection backend module $BackendModule!");
    }

    return $BackendObject->SendEmail(%Param);
}

sub Check {
    my ( $Self, %Param ) = @_;

    # get configured backend module
    my $BackendModule = $Kernel::OM->Get('Config')->Get('LoopProtectionModule')
        || 'PostMaster::LoopProtection::DB';

    # get backend object
    my $BackendObject = $Kernel::OM->Get($BackendModule);

    if ( !$BackendObject ) {

        # get main object
        my $MainObject = $Kernel::OM->Get('Main');

        $MainObject->Die("Can't load loop protection backend module $BackendModule!");
    }

    return $BackendObject->Check(%Param);
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
