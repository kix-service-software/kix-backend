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

When qr/I query the cmdb collection of (\w+) (\w+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets/'.$1.'/articles',
   );
};

When qr/I query the articles collection$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets/'.S->{TicketID}.'/articles',
   );
};

When qr/I query the articles collection with limit (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets/'.S->{TicketID}.'/articles',
      Limit => $1,
   );
};

When qr/I query the articles collection with offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets/'.S->{TicketID}.'/articles',
      Offset => $1,
   );
};

When qr/I query the articles collection with limit (\d+) and offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets/'.S->{TicketID}.'/articles',
      Limit => $1,
      Offset => $2,
   );
};

