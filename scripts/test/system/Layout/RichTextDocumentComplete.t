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

# get layout object
my $LayoutObject = $Kernel::OM->Get('Output::HTML::Layout');

my @Tests = (
    {
        Name   => 'Empty document',
        String => '123',
        Result => '<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
                <style>
                        body {
                font-family:Geneva,Helvetica,Arial,sans-serif; font-size: 12px;
            }

        </style>

    </head>
    <body>123</body>
</html>
',
    },
    {
        Name   => 'Image with ContentID, no session',
        String => '123 <img src="index.pl?Action=SomeAction;FileID=0;ContentID=inline105816.238987884.1382708457.5104380.88084622@localhost" /> 234',
        Result => '<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
                <style>
                        body {
                font-family:Geneva,Helvetica,Arial,sans-serif; font-size: 12px;
            }

        </style>

    </head>
    <body>123 <img src="cid:inline105816.238987884.1382708457.5104380.88084622@localhost" /> 234</body>
</html>
',
    },
    {
        Name   => 'Image with ContentID, with session',
        String => '123 <img src="index.pl?Action=SomeAction;FileID=0;ContentID=inline105816.238987884.1382708457.5104380.88084622@localhost;SessionID=123" /> 234',
        Result => '<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
                <style>
                        body {
                font-family:Geneva,Helvetica,Arial,sans-serif; font-size: 12px;
            }

        </style>

    </head>
    <body>123 <img src="cid:inline105816.238987884.1382708457.5104380.88084622@localhost" /> 234</body>
</html>
',
    },
    {
        Name   => 'Image with ContentID, with session',
        String => '123 <img src="index.pl?Action=SomeAction;FileID=0;ContentID=inline105816.238987884.1382708457.5104380.88084622@localhost&SessionID=123" /> 234',
        Result => '<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
                <style>
                        body {
                font-family:Geneva,Helvetica,Arial,sans-serif; font-size: 12px;
            }

        </style>

    </head>
    <body>123 <img src="cid:inline105816.238987884.1382708457.5104380.88084622@localhost" /> 234</body>
</html>
',
    },
);

for my $Test (@Tests) {
    my $Result = $LayoutObject->RichTextDocumentComplete(
        String => $Test->{String},
    );
    $Self->Is(
        $Result,
        $Test->{Result},
        "$Test->{Name}",
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
