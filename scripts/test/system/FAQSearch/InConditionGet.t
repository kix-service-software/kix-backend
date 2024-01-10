# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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

my @Tests = (
    {
        Name   => 'No array',
        Params => {
            TableColumn => 'test.table',
            ValueList   => 1,
            Silent      => 1
        },
        Result => undef,
    },
    {
        Name   => 'Single value  (Integer)',
        Params => {
            TableColumn => 'test.table',
            ValueList   => [1],
            Type        => 'Integer'
        },
        Result => ' (  test.table IN (1)  ) ',
    },
    {
        Name   => 'Single integer value without type',
        Params => {
            TableColumn => 'test.table',
            ValueList   => [1],
        },
        Result => ' (  test.table IN (\'1\')  ) ',
    },
    {
        Name   => 'Single value (String)',
        Params => {
            TableColumn => 'test.table',
            ValueList   => [ 'de' ],
            Type        => 'String'
        },
        Result => ' (  test.table IN (\'de\')  ) ',
    },
    {
        Name   => 'Sorted values (Integer)',
        Params => {
            TableColumn => 'test.table',
            ValueList   => [ 2, 1, -1, 0 ],
            Type        => 'Integer'
        },
        Result => ' (  test.table IN (-1, 0, 1, 2)  ) ',
    },
    {
        Name   => 'Sorted values (String)',
        Params => {
            TableColumn => 'test.table',
            ValueList   => [ 'external', 'de'  ],
            Type        => 'String'
        },
        Result => ' (  test.table IN (\'de\', \'external\')  ) ',
    },
    {
        Name   => 'Invalid value (Integer)',
        Params => {
            TableColumn => 'test.table',
            ValueList   => [q{}],
            Type        => 'Integer'
        },
        Result => undef,
    },
    {
        Name   => 'Invalid value (String)',
        Params => {
            TableColumn => 'test.table',
            ValueList   => [undef],
            Type        => 'String'
        },
        Result => undef,
    },
    {
        Name   => 'Mix of valid and invalid values (Integer)',
        Params => {
            TableColumn => 'test.table',
            ValueList   => [ 1, 1.1 ],
            Type        => 'Integer'
        },
        Result => undef,
    },
    {
        Name   => 'Mix of valid and invalid values (String)',
        Params => {
            TableColumn => 'test.table',
            ValueList   => [ 'de', undef ],
            Type        => 'String'
        },
        Result => undef,
    },
);

# get FAQ object
my $FAQObject = $Kernel::OM->Get('FAQ');

for my $Test (@Tests) {
    $Self->Is(
        scalar $FAQObject->_InConditionGet( %{ $Test->{Params} } ),
        $Test->{Result},
        "$Test->{Name} _InConditionGet()"
    );
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
