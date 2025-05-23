# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::SystemAddress::Add;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Queue',
    'SystemAddress',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Add new system address.');
    $Self->AddOption(
        Name        => 'name',
        Description => "Display name of the new system address.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'email-address',
        Description => "Email address which should be used for the new system address.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'queue-name',
        Description => "Queue name the address should be linked to.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'comment',
        Description => "Comment for the new system address.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    # check if queue already exists
    $Self->{QueueName} = $Self->GetOption('queue-name');
    $Self->{QueueID}   = $Kernel::OM->Get('Queue')->QueueLookup(
        Queue => $Self->{QueueName},
    );
    if ( !$Self->{QueueID} ) {
        die "Queue $Self->{QueueName} does not exist.\n";
    }

    # check if system address already exists
    $Self->{EmailAddress} = $Self->GetOption('email-address');
    my $SystemExists = $Kernel::OM->Get('SystemAddress')->SystemAddressIsLocalAddress(
        Address => $Self->{EmailAddress},
    );
    if ($SystemExists) {
        die "SystemAddress $Self->{EmailAddress} already exists.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Adding a new system address...</yellow>\n");

    # add system address
    if (
        !$Kernel::OM->Get('SystemAddress')->SystemAddressAdd(
            UserID   => 1,
            ValidID  => 1,
            Comment  => $Self->GetOption('comment'),
            Realname => $Self->GetOption('name'),
            QueueID  => $Self->{QueueID},
            Name     => $Self->{EmailAddress},
        )
        )
    {
        $Self->PrintError("Can't add system address.");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
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
