# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Role::Add;

use strict;
use warnings;

use Kernel::System::Role;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Role',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Create a new role.');
    $Self->AddOption(
        Name        => 'name',
        Description => 'Name of the new role.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'usage-context',
        Description => 'The usage context of the new role. Can be Agent, Customer or Both (Default: Agent).',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/(Agent|Customer|Both)/smx,
    );
    $Self->AddOption(
        Name        => 'comment',
        Description => 'Comment for the new role.',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my %UsageContextMap = (
        Agent    => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
        Customer => Kernel::System::Role->USAGE_CONTEXT->{CUSTOMER},
        Both     => Kernel::System::Role->USAGE_CONTEXT->{CUSTOMER} + Kernel::System::Role->USAGE_CONTEXT->{AGENT},
    );

    $Self->Print("<yellow>Adding a new role...</yellow>\n");

    my $RID = $Kernel::OM->Get('Role')->RoleAdd(
        Name         => $Self->GetOption('name'),
        Comment      => $Self->GetOption('comment') || '',
        UsageContext => $UsageContextMap{$Self->GetOption('usage-context') || ''} || Kernel::System::Role->USAGE_CONTEXT->{AGENT},
        ValidID      => 1,
        UserID       => 1,
    );

    if ($RID) {
        $Self->Print("<green>Done</green>\n");
        return $Self->ExitCodeOk();
    }

    $Self->PrintError("Can't add role");
    return $Self->ExitCodeError();
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
