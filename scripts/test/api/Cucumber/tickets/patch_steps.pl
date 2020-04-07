use warnings;

use Cwd;
use lib cwd();
use lib cwd() . '/Kernel/cpan-lib';
use lib cwd() . '/plugins';
use lib cwd() . '/scripts/test/api/Cucumber';

use LWP::UserAgent;
use HTTP::Request;
use JSON::XS qw(encode_json decode_json);
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
            Title => "test ticket for unknown contact update",
            ContactID => "test\@no-mail.com",
            OrganisationID => "test\@no-mail.com",
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
                    From => "root\@nomail.org",
                    CustomerVisible => 0,
                    To => "contact222\@nomail.org"
                }
            ]
        }
      }
   );
};
