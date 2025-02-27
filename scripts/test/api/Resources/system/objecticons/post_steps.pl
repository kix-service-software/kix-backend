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

Given qr/a objecticon$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/objecticons',
      Token   => S->{Token},
      Content => {
        ObjectIcon => {
            Content => "TestIcon".rand(),
            ContentType => "image/png",
            Object => "TicketType",
            ObjectID => "3".int(rand(20))
        }
      }
   );
};

When qr/added a objecticon$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/objecticons',
      Token   => S->{Token},
      Content => {
        ObjectIcon => {
            Content => "TestIcon".rand(),
            ContentType => "image/png",
            Object => "TicketType",
            ObjectID => "4".int(rand(20))
        }
      }
   );
};