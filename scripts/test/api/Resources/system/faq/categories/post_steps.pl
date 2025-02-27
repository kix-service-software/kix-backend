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

Given qr/a faq category$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/faq/categories',
      Token   => S->{Token},
      Content => {
            FAQCategory => {
                Comment => 'TestComment',
                ParentID => undef,
                ValidID => 1,
                Name => 'KIX18-Funktionen given',
                Fullname => 'KIX18-Funktionen',
            }
      }
   );
};

When qr/I create a faq category$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/faq/categories',
      Token   => S->{Token},
      Content => {
            FAQCategory => {
                Comment => 'TestComment',
                ParentID => undef,
                ValidID => 1,
                Name => 'KIX18-Funktionen'.rand(),
                Fullname => 'KIX18-Funktionen',
            }
      }
   );
};
