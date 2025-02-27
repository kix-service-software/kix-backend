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

When qr/I query the collection of clientregistration$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/clientregistrations',
   );
};

When qr/I query the collection of clientregistration with filter of "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/clientregistrations',
      Filter => '{"ClientRegistration": {"AND": [{"Field": "ClientID","Operator": "EQ","Value": "'.$1.'"}]}}',
   );
};

When qr/I query the collection of clientregistration with filter contains of "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/clientregistrations',
      Filter => '{"ClientRegistration": {"AND": [{"Field": "ClientID","Operator": "CONTAINS","Value": "'.$1.'"}]}}',
   );
};

When qr/I query the collection of clientregistration with filter end of "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/clientregistrations',
      Filter => '{"ClientRegistration": {"AND": [{"Field": "ClientID","Operator": "ENDSWITH","Value": "'.$1.'"}]}}',
   );
};

When qr/I query the collection of clientregistration with limit (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/clientregistrations',
      Limit => $1,
   );
};

When qr/I query the collection of clientregistration with offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/clientregistrations',
      Offset => $1,
   );
};

When qr/I query the collection of clientregistration with limit (\d+) and offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/clientregistrations',
      Offset => $2,
      Limit  => $1,
   );
};
   
When qr/I query the collection of clientregistration with sorted by "(.*?)" limit (\d+) and offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/clientregistrations',
      Offset => $3,
      Limit  => $2,
      Sort => $1,
   );   
};