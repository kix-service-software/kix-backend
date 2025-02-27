# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::Number::AutoIncrement;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ITSMConfigItem::Number::AutoIncrement - config item number backend module

=head1 SYNOPSIS

All auto increment config item number functions

=over 4

=cut

=item ConfigItemNumberCreate()

create a new config item number

    my $Number = $ConfigItemObject->ConfigItemNumberCreate(
        ClassID => 123,
    );

=cut

sub ConfigItemNumberCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ClassID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ClassID!',
        );
        return;
    }

    # get system id
    my $SystemID = $Kernel::OM->Get('Config')->Get('SystemID');

    # get current counter
    my $CurrentCounter = $Self->ConfigItemCounterGet(
        ClassID => $Param{ClassID},
        Counter => 'AutoIncrement',
    ) || 0;

    CIPHER:
    for my $Cipher ( 1 .. 1_000_000_000 ) {

        # create new number
        my $Number = $SystemID . $Param{ClassID} . sprintf( "%06d", ( $CurrentCounter + $Cipher ) );

        # find existing number
        my $Duplicate = $Self->ConfigItemLookup(
            ConfigItemNumber => $Number,
        );

        next CIPHER if $Duplicate;

        # set counter
        $Self->ConfigItemCounterSet(
            ClassID => $Param{ClassID},
            Counter => 'AutoIncrement',
            Value   => ( $CurrentCounter + $Cipher ),
        );

        return $Number;
    }

    return;
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
