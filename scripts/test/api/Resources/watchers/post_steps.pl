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

Given qr/a watcher$/, sub {

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/watchers',
      Token   => S->{Token},
      Content => {
        Watcher => {
            Object => "Ticket",
            ObjectID => S->{TicketID},
            UserID => 1
        }
      }
   );
};


When qr/I create a watcher$/, sub {

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/watchers',
      Token   => S->{Token},
      Content => {
        Watcher => {
            Object => "Ticket",
            ObjectID => S->{TicketID},
            UserID => 1
        }
      }
   );
};

