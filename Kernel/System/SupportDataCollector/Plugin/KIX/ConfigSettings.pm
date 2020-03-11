# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::ConfigSettings;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
);

sub GetDisplayPath {
    return Translatable('KIX') . '/' . Translatable('Config Settings');
}

sub Run {
    my $Self = shift;

    my @Settings = qw(
        Home
        FQDN
        HttpType
        DefaultLanguage
        SystemID
        Version
        ProductName
        Organization
        Ticket::IndexModule
        Ticket::SearchIndexModule
        Ticket::StorageModule
        SendmailModule
        Frontend::RichText
    );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    for my $Setting (@Settings) {

        my $ConfigValue = $ConfigObject->Get($Setting);

        if ( defined $ConfigValue ) {
            $Self->AddResultInformation(
                Identifier => $Setting,
                Label      => $Setting,
                Value      => $ConfigValue,
            );
        }
        else {
            $Self->AddResultProblem(
                Identifier => $Setting,
                Label      => $Setting,
                Value      => $ConfigValue,
                Message    => Translatable('Could not determine value.'),
            );
        }
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
