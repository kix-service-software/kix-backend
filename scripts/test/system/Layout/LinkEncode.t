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

# get layout object
my $LayoutObject = $Kernel::OM->Get('Output::HTML::Layout');

my @LinkEncodeTests = (

    {
        Source => '%',
        Target => '%25',
    },
    {
        Source => '&',
        Target => '%26',
    },
    {
        Source => '=',
        Target => '%3D',
    },
    {
        Source => '!',
        Target => '%21',
    },
    {
        Source => '"',
        Target => '%22',
    },
    {
        Source => '#',
        Target => '%23',
    },
    {
        Source => '$',
        Target => '%24',
    },
    {
        Source => '\'',
        Target => '%27',
    },
    {
        Source => ',',
        Target => '%2C',
    },
    {
        Source => '+',
        Target => '%2B',
    },
    {
        Source => '?',
        Target => '%3F',
    },
    {
        Source => '|',
        Target => '%7C',
    },
    {
        Source => '/',
        Target => '%2F',
    },

    # According to the URL encoding RFC, the path segment of an URL must use %20 for space,
    # while in the query string + is used normally. However, IIS does not understand + in the
    # path segment, but understands %20 in the query string, like all others do as well.
    # Therefore we use %20.
    {
        Source => ' ',
        Target => '%20',
    },
    {
        Source => ':',
        Target => '%3A',
    },
    {
        Source => ';',
        Target => '%3B',
    },
    {
        Source => '@',
        Target => '%40',
    },

    # LinkEncode() on reserved characters
    {
        Source => '!*\'();:@&=+$,/?#[]',
        Target => '%21%2A%27%28%29%3B%3A%40%26%3D%2B%24%2C%2F%3F%23%5B%5D',
    },

    # LinkEncode() on common characters
    {
        Source => '<>"{}|\`^% ',
        Target => '%3C%3E%22%7B%7D%7C%5C%60%5E%25%20',
    },

    # LinkEncode() on normal characters
    {
        Source => 'normaltext123',
        Target => 'normaltext123',
    },
);

for my $LinkEncodeTest (@LinkEncodeTests) {
    $Self->Is(
        $LayoutObject->LinkEncode( $LinkEncodeTest->{Source} ),
        $LinkEncodeTest->{Target},
        "LinkEncode from '$LinkEncodeTest->{Source}' to '$LinkEncodeTest->{Target}'",
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
