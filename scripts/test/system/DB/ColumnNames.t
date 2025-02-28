# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get DB object
my $DBObject = $Kernel::OM->Get('DB');

# ------------------------------------------------------------ #
# column name tests
# ------------------------------------------------------------ #

my @Tests = (
    {
        Name   => 'SELECT with named columns',
        Data   => 'SELECT id, name FROM roles',
        Result => [qw(id name)],
    },
    {
        Name   => 'SELECT with all columns',
        Data   => 'SELECT * FROM roles',
        Result => [qw(id name comments valid_id usage_context create_time create_by change_time change_by)],
    },
);

for my $Test (@Tests) {
    my $Result = $DBObject->Prepare(
        SQL => $Test->{Data},
    );
    my @Names = $DBObject->GetColumnNames();

    my $Counter = 0;
    for my $Field ( @{ $Test->{Result} } ) {

        $Self->Is(
            lc $Names[$Counter],
            $Field,
            "GetColumnNames - field $Field - $Test->{Name}",
        );
        $Counter++;
    }
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
