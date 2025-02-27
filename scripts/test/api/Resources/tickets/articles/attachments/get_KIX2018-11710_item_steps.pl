# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --
use warnings;

use Cwd;
use lib cwd();
use lib cwd() . '/Kernel/cpan-lib';
use lib cwd() . '/plugins';
use lib cwd() . '/scripts/test/api/Cucumber';

use LWP::UserAgent;
use HTTP::Request;
use JSON::MaybeXS qw(encode_json decode_json);
use JSON::Validator;

use Test::More;
use Test::BDD::Cucumber::StepFile;

use Data::Dumper;

use Kernel::System::ObjectManager;

$Kernel::OM = Kernel::System::ObjectManager->new();

# require our helper
require '_Helper.pl';

# require our common library
require '_StepsLib.pl';

# feature specific steps 

When qr/I get the article\s*$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets/'.S->{TicketID}.'/articles/'.S->{ResponseContent}->{ArticleID}.'?include=DynamicFields',
   );
};

When qr/I create a article with inline pic$/, sub {
    print STDERR "TID:".Dumper(S->{ResponseContent}->{TicketID});
    ( S->{Response}, S->{ResponseContent} ) = _Post(
        URL     => S->{API_URL}.'/tickets/'.S->{TicketID}.'/articles',
        Token   => S->{Token},
        Content => {
            Article => {
                 Subject =>"Test mit Inlineimage",
                 Body =>"<img src=\"cid:inline908365.782562451.1717154478.5897968.14714663@kixdesk.com\"/>",
                 ContentType =>"text/html; charset=utf8",
                 MimeType =>"text/html",
                 Charset =>"utf8",
                 ChannelID =>2,
                 SenderTypeID =>2,
				 Attachments => [
					  {
						  ContentType => "image/png; name=\"grafik.png\"",
						  ContentID => "<inline908365.782562451.1717154478.5897968.14714663@kixdesk.com>",
						  Disposition => "inline",
						  Filename => "grafik.jpg",
						  Content => "iVBORw0KGgoAAAANSUhEUgAAAFQAAAAdCAYAAAA0PEtlAAAC5ElEQVRoQ+2YsUsqQBzHv25O4mAgzQoOZjgZiCBG2FQ5BIVo6iBKKkQU2RJRQ39BSQVBQ0GDttbYH9EgiCBC6aYGuvne3ePEni/uTk98w92ieL/7/n73ubvf/U5Dr9frQzdlBAwaqDKWVEgDVctTA1XMUwPVQFUTUKync6gGqpiAYjm9Q2cFdHt7G91ud+DeYDCg3+/D5/Nhf39fcVh/5DqdDiKRyIj22toaEomEUp8bGxtUz+124+TkZKDNfp+bm8PNzQ3Xp/AOzWQyqNfrPwqWSiUQyCrb09MTHh8f6cKxRnzc3d3BbDardAUGbnl5GdlsdgSow+HAxcUF16cw0L29PVSrVSr4/PxMP2u1GnK5HP3u9XpxcHDAdTiOQSgUolAvLy8xPz8/jgR3DAMaDAaRTqdHgC4sLODs7IyrIw2U7BCyG1ljgayuriKVSnEdyho0m00kk8lvCymrIWI/c6BfX1+4vr7G29vbVCd7f3+PYrFI08nwQopAkrGZGdB/BXl7ewuLxSITv7BtNBpFu91GIBAYpBfhwRKGMwNKdorL5cLn5ycajcYgZJLndnZ2JKYgZsry5/n5OZxOp9igMax+Asr8Ly4u4vT0lKs8cQ4lF8Xr6+tUjj1ZNJaX2UXIndGYBgycx+NBPp8fuSNWVlawu7vLVZ8Y6Pv7O46Pj6mjQqEAq9XKdSpq8PDwAFI6TTt/knhILV2pVKgvUqoZjUa8vLzg6uqKhnt0dISlpSVu6NJAieLwbtna2sLvP6mnskNJ+fLx8YH19XXE43HuZCYxaLVaiMVi32pepiezoMJAeYV9OBzG5ubmJHMajCW1Lalxh5vMpCYJ4vDwEOVymUqYTCb4/X6pV5kw0OGn5/CLyGaz0TrRbrdPMo9vY8kF8feri6QSdvyUOZqCkDDQKfj+byTZhcQLSOSUaKA8ipL9GqgkMJ65BsojJNmvgUoC45lroDxCkv0aqCQwnrkGyiMk2f8Lr5WFWFGkqmUAAAAASUVORK5CYII="
                      }
                 ]
            }
        }
    );
};

Given qr/a ticket$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/tickets',
      Token   => S->{Token},
      Content => {
        Ticket => {
            Title => "test ticket for unknown contact",
            ContactID => 1,
            OrganisationID => 1,
            StateID => 4,
            PriorityID => 3,
            QueueID => 1,
            TypeID => 2
        }
     }
   );
};

When qr/I delete this ticket$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Delete(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets/'.S->{TicketID},
);
};

When qr/I get the inline attachment item\s*$/, sub {
	print STDERR "hier:".Dumper(S->{TicketID}, S->{ResponseContent}->{Article}->{ArticleID});
	( S->{Response}, S->{ResponseContent} ) = _Get(
		Token => S->{Token},
		URL   => S->{API_URL}.'/tickets/'.S->{TicketID}.'/articles/'.S->{ResponseContent}->{Article}->{ArticleID}.'/attachments',
	);
};






=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
