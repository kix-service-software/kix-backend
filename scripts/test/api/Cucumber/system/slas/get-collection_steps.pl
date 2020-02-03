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

When qr/I query the collection of slas$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/slas',
   );
};

When qr/I query the collection of slas with filter of "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/slas',
      Filter => '{"SLA": {"AND": [{"Field": "Comment","Operator": "EQ","Value": "'.$1.'"}]}}',
   );
};

When qr/I query the collection of slas with filter contains of "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/slas',
      Filter => '{"SLA": {"AND": [{"Field": "Name","Operator": "CONTAINS","Value": "'.$1.'"}]}}',
   );
};

When qr/I query the collection of slas with a limit of (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/slas',
      Limit => $1,
   );
};

When qr/I query the collection of slas with offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/slas',
      Offset => $1,
   );
};

When qr/I query the collection of slas with limit (\d+) and offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/slas',
      Limit  => $1,
      Offset => $2,
   );
};

When qr/I query the collection of slas with sorted by "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/slas',
      Sort => $1,
   );
};

When qr/I query the collection of slas with sorted by "(.*?)" limit (\d+) and offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/slas',
      Limit  => $2,
      Offset => $3,
      Sort => $1,
   );
};






