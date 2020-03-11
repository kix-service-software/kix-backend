# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::DefaultUser;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::System::Auth',
    'Kernel::System::User',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    # get needed objects
    my $UserObject  = $Kernel::OM->Get('Kernel::System::User');

    my %UserList = $UserObject->UserList(
        Type  => 'Short',
        Valid => '1',
    );

    my $DefaultPassword;

    my $SuperUserID;
    USER:
    for my $UserID ( sort keys %UserList ) {
        if ( $UserList{$UserID} eq 'root@localhost' ) {
            $SuperUserID = 1;
            last USER;
        }
    }

    if ($SuperUserID) {

        $DefaultPassword = $Kernel::OM->Get('Kernel::System::Auth')->Auth(
            User => 'root@localhost',
            Pw   => 'root',
        );
    }

    if ($DefaultPassword) {
        $Self->AddResultProblem(
            Label => Translatable('Default Admin Password'),
            Value => '',
            Message =>
                Translatable(
                'Security risk: the agent account root@localhost still has the default password. Please change it or invalidate the account.'
                ),
        );
    }
    else {
        $Self->AddResultOk(
            Label => Translatable('Default Admin Password'),
            Value => '',
        );
    }

    return $Self->GetResults();
}

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
