# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::Ticket::SearchIndexModule;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Config',
    'DB',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    my $Module = $Kernel::OM->Get('Config')->Get('Ticket::SearchIndexModule');

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    my $ArticleCount;
    $DBObject->Prepare( SQL => 'SELECT count(*) FROM article' );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ArticleCount = $Row[0];
    }

    if ( $ArticleCount > 50_000 && $Module =~ /RuntimeDB/ ) {
        $Self->AddResultWarning(
            Label => Translatable('Ticket Search Index Module'),
            Value => $Module,
            Message =>
                Translatable(
                'You have more than 50,000 articles and should use the StaticDB backend. See admin manual (Performance Tuning) for more information.'
                ),
        );
    }
    else {
        $Self->AddResultOk(
            Label => Translatable('Ticket Search Index Module'),
            Value => $Module,
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
