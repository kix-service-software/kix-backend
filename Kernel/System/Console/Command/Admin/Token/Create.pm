# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Token::Create;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Token',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Create AccessToken for remote APIs.');
    $Self->AddOption(
        Name        => 'user',
        Description => "The user identifier which will used by the token. Agent = UserLogin, Customer = CustomerKey.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'user-type',
        Description => "The type of the user. Possible values are 'Agent' or 'Customer'",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/(Agent|Customer)/smx,
    );

    $Self->AddOption(
        Name        => 'valid-until',
        Description => "The token will be valid until the given date+time. Format: YYYY-MM-DD HH24:MI:SS",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/^\d{4}-\d{2}-\d{2}[ ]\d{2}:\d{2}:\d{2}$/smx,
    );

    $Self->AddOption(
        Name        => 'remote-ip',
        Description => "The remote IP for which the token should be valid. The value 0.0.0.0 represents all IPs.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'allowed-ops',
        Description => "A comma separated list to allow specific API operation types. RegEx is supported.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'ignore-max-idle-time',
        Description => "Set to 1 to not validate the MaxIdleTime for this token.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^1$/smx,
    );

    $Self->AddOption(
        Name        => 'denied-ops',
        Description => "A comma separated list to deny specific API operation types. RegEx is supported.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'description',
        Description => "It's recommended to add a description to identify the token.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;
    my @AllowedOperations;
    my @DeniedOperations;

    $Self->Print("<yellow>Creating token...</yellow>\n");

    my $UserID;
    my $UserType   = $Self->GetOption('user-type');
    my $AllowedOps = $Self->GetOption('allowed-ops');
    my $DeniedOps  = $Self->GetOption('denied-ops');

    if ( $UserType eq 'Agent' ) {
        # lookup UserID
        $UserID = $Kernel::OM->Get('User')->UserLookup(
            UserLogin => $Self->GetOption('user'),
        );
    }
    elsif ( $UserType eq 'Customer' ) {
        # take user parameter as userid
        $UserID = $Self->GetOption('user');
    }

    if ( !$UserID ) {
        $Self->PrintError("No such user.");
        return $Self->ExitCodeError();
    }

    if ( $AllowedOps ) {
        @AllowedOperations = split(/,/, $AllowedOps);
    }

    if ( $DeniedOps ) {
        @DeniedOperations = split(/,/, $DeniedOps);
    }

    my $Token = $Kernel::OM->Get('Token')->CreateToken(
        Payload => {
            UserID      => $UserID,
            UserType    => $UserType,
            ValidUntil  => $Self->GetOption('valid-until'),
            RemoteIP    => $Self->GetOption('remote-ip'),
            IgnoreMaxIdleTime => $Self->GetOption('ignore-max-idle-time'),
            Description => $Self->GetOption('description'),
            AllowedOperations => \@AllowedOperations,
            DeniedOperations  => \@DeniedOperations,
            TokenType   => 'AccessToken',
        },
    );

    $Self->Print("\n".$Token."\n");

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
