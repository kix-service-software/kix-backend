# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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

When qr/I update this ticket$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Patch(
      URL     => S->{API_URL}.'/tickets/'.S->{ResponseContent}->{TicketID},
      Token   => S->{Token},
      Content => {
        Ticket => {
            Title => "test ticket patch for unknown contact update",
            ContactID => 1,
            OrganisationID => 1,
            StateID => 4,
            PriorityID => 3,
            QueueID => 1,
            TypeID => 2,
            Articles => [
                {
                    Subject => "d  fsd fds ",
                    Body => "<p>sd fds sd</p>",
                    ContentType => "text/html; charset=utf8",
                    MimeType => "text/html",
                    Charset => "utf8",
                    ChannelID => 1,
                    SenderTypeID => 1,
                    From => 'root@nomail.org',
                    CustomerVisible => 0,
                    To => 'contact222@nomail.org'
                }
            ]
        }
      }
   );
};

When qr/I update this ticket with placeholder$/, sub {
    ( S->{Response}, S->{ResponseContent} ) = _Patch(
        URL     => S->{API_URL}.'/tickets/'.S->{ResponseContent}->{TicketID},
        Token   => S->{Token},
        Content => {
            Ticket => {
                Title => "test KIX_CONFIG_DefaultUsedLanguages: <KIX_CONFIG_DefaultUsedLanguages> ticket for unknown contact",
                ContactID => 1,
                OrganisationID => 1,
                StateID => 4,
                PriorityID => 3,
                QueueID => 1,
                TypeID => 2,
                Articles => [
                    {
                        Subject => "d  fsd fds ",
                        Body => "Calendar: <KIX_TICKET_SLACriteria_FirstResponse_Calendar>, BusinessTimeDeviaton: <KIX_TICKET_SLACriteria_FirstResponse_BusinessTimeDeviaton>, TargetTime: <KIX_TICKET_SLACriteria_FirstResponse_TargetTime>, KIX_CONFIG_Ticket::Hook: <KIX_CONFIG_Ticket::Hook>,KIX_CONFIG_PGP::Key::Password: <KIX_CONFIG_PGP::Key::Password>,KIX_CONFIG_ContactSearch::UseWildcardPrefix: <KIX_CONFIG_ContactSearch::UseWildcardPrefix>",
                        ContentType => "text/html; charset=utf8",
                        MimeType => "text/html",
                        Charset => "utf8",
                        ChannelID => 1,
                        SenderTypeID => 1,
                        From => 'root@nomail.org',
                        CustomerVisible => 0,
                        To => 'contact222@nomail.org'
                    }
                ]
            }
        }
    );
};
