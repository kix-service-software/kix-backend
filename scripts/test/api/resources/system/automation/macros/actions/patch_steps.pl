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

When qr/I update this automation macro action$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Patch(
      URL     => S->{API_URL}.'/system/automation/macros/'.S->{MacroID}.'/actions/'.S->{MacroActionID},
      Token   => S->{Token},
      Content => {
        MacroAction => {
            Comment => "some action comment update",
            MacroID => S->{MacroID},
            Name => "new macro action update",
            Parameters => {
                Body => "The text of the new article. update",
                Contact => "testupdate@nomail.com",
                Priority => "1 very low",
                State => "new",
                Team => "Service Desk",
                Title => "Test macro actions update"
            },
            Type => "TicketCreate",
            ValidID => 1
        }
      }
   );
};

