# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);
use vars (qw($Self));

# get ReportDefinition object
my $ReportingObject = $Kernel::OM->Get('Reporting');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $Backends = $Kernel::OM->Get('Config')->Get('Reporting::OutputFormat');

my @FormatList = $ReportingObject->OutputFormatList();

$Self->Is(
    scalar @FormatList,
    scalar keys %{$Backends},
    'OutputFormatList() - count',
);

$Self->IsDeeply(
    \@FormatList,
    [ sort keys %{$Backends} ],
    'OutputFormatList() - contains',
);

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
