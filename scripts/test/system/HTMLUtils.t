# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# test ToAscii
my @TestCases = (
    {
        Name     => 'ToAscii: empty string',
        Input    => {
            String => ''
        },
        Expected => ''
    },
    {
        Name     => 'ToAscii: plain text',
        Input    => {
            String => <<'END'
This is plain text
END
        },
        Expected => 'This is plain text '
    },
    {
        Name     => 'ToAscii: html code',
        Input    => {
            String => <<'END'
<p>Line 1</p>
<p>This is an URL: <a class="Link" href="https://kixdesk.com">KIXDesk</a>
</p>
<ul>
<li>Entry 1</li>
<li>Entry 2</li>
</ul>
Umlauts: &Auml;&Ouml;&Uuml;&auml;&ouml;&uuml;&szlig;
<br />
"Test" &lt;test@kixdesk.com&gt;
END
        },
        Expected => <<'END'

Line 1

This is an URL: [1]KIXDesk 

 - Entry 1 
 - Entry 2 

 Umlauts: ÄÖÜäöüß 
"Test" <test@kixdesk.com> 


[1] https://kixdesk.com
END
    },
    {
        Name     => 'ToAscii: html code / NoURLGlossar',
        Input    => {
            NoURLGlossar => 1,
            String       => <<'END'
<p>Line 1</p>
<p>This is an URL: <a class="Link" href="https://kixdesk.com">KIXDesk</a>
</p>
<ul>
<li>Entry 1</li>
<li>Entry 2</li>
</ul>
Umlauts: &Auml;&Ouml;&Uuml;&auml;&ouml;&uuml;&szlig;
<br />
"Test" &lt;test@kixdesk.com&gt;
END
        },
        Expected => <<'END'

Line 1

This is an URL: KIXDesk 

 - Entry 1 
 - Entry 2 

 Umlauts: ÄÖÜäöüß 
"Test" <test@kixdesk.com> 
END
    },
    {
        Name     => 'ToAscii: long text line',
        Input    => {
            NoForcedLinebreak => 1,
            String            => 'Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua.'
        },
        Expected => 'Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua.'
    },
    {
        Name     => 'ToAscii: long text line / NoForcedLinebreak',
        Input    => {
            NoForcedLinebreak => 1,
            String            => 'Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua.'
        },
        Expected => 'Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua.'
    }
);
for my $Test ( @TestCases ) {
    my $Result = $Kernel::OM->Get('HTMLUtils')->ToAscii(
        %{ $Test->{Input} }
    );
    $Self->IsDeeply(
        $Result,
        $Test->{Expected},
        $Test->{Name}
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
