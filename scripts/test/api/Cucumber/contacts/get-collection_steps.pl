use warnings;

use Cwd;
use lib cwd();
use lib cwd() . '/Kernel/cpan-lib';
use lib cwd() . '/Custom';
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

When qr/I query the collection of contacts$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/contacts',
   );
};

When qr/I query the collection of contacts with filter of "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/contacts',
      Filter => '{"Contact": {"AND": [{"Field": "Email","Operator": "STARTSWITH","Value": "'.$1.'"}]}}',
   );
};

When qr/I query the collection of contacts with filter of Firstname "(.*?)" and Login "(.*?)"$/, sub {  
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/contacts',
      Filter => '{"Contact": {"AND": [{"Field": "Firstname","Operator": "STARTSWITH","Value": "'.$1.'"},{"Field": "Login","Operator": "STARTSWITH","Value": "'.$2.'"}]}}',
   );
};

When qr/I query the collection of contacts with limit (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/contacts',
      Limit => $1,
   );
};

When qr/I query the collection of contacts with offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/contacts',
      Offset => $1,
   );
};

When qr/I query the collection of contacts with limit (\d+) and offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/contacts',
      Offset => $2,
      Limit => $1,
   );
};

When qr/I query the collection of contacts with sorted by "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/contacts',
      Sort => $1,
   );
};


When qr/I query the collection of contacts with sorted by "(.*?)" limit (\d+) and offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/contacts',
      Offset => $3,
      Limit => $2,
      Sort => $1,
   );
};



