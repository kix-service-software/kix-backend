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

When qr/I query the collection of addressbook$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/addressbook',
   );
};

When qr/I query the collection of addressbook with filter of (.*?)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/addressbook',
      Filter => '{"Address": {"AND": [{"Field": "EmailAddress","Operator": "STARTSWITH","Value": "'.$1.'"}]}}',
   );
};

When qr/I query the collection of addressbook with filter contains of (.*?)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/addressbook',
      Filter => '{"Address": {"AND": [{"Field": "EmailAddress","Operator": "CONTAINS","Value": "'.$1.'"}]}}',
   );
};

When qr/I query the collection of addressbook with filter and of (.*?)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/addressbook',
      Filter => '{"Address": {"AND": [{"Field": "EmailAddress","Operator": "CONTAINS","Value": "'.$1.'"}]}}',
   );
};

When qr/I query the collection of addressbook with limit (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/addressbook',
      Limit => $1,
   );
};

When qr/I query the collection of addressbook with offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/addressbook',
      Offset => $1,
   );
};

When qr/I query the collection of addressbook with limit (\d+) and offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token  => S->{Token},
      URL    => S->{API_URL}.'/addressbook',
      Limit  => $1,
      Offset => $2,
   );
};

When qr/I query the collection of addressbook with sorted by "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/addressbook',
      Sort => $1,
   );
};

When qr/I query the collection of addressbook with sorted by "(.*?)" limit (\d+) and offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/addressbook',
      Limit  => $2,
      Offset => $3,
      Sort => $1,
   );
};