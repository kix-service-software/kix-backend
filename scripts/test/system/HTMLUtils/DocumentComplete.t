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

# get HTMLUtils object
my $HTMLUtilsObject = $Kernel::OM->Get('HTMLUtils');

# DocumentComplete tests
my @Tests = (
    {
        Input  => 'Some Text',
        Result => '<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1"/>
                <style>
                        body {
                font-family:Geneva,Helvetica,Arial,sans-serif; font-size: 12px;
            }

        </style>

    </head>
    <body>Some Text</body>
</html>
',
        Name   => 'DocumentComplete - simple'
    },
    {
        Input  => '<html><body>Some Text</body></html>',
        Result => '<html><body>Some Text</body></html>',
        Name   => 'DocumentComplete - simple'
    },
);

for my $Test (@Tests) {
    my $Ascii = $HTMLUtilsObject->DocumentComplete(
        Charset => 'iso-8859-1',
        String  => $Test->{Input},
    );
    $Self->Is(
        $Ascii,
        $Test->{Result},
        $Test->{Name},
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
