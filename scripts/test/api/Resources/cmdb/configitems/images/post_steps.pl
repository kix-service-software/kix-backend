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

Given qr/added image to a configitem$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/cmdb/configitems/'.S->{ConfigItemID}.'/images',
      Token   => S->{Token},
      Content => {
          Image => {
            Comment     => "this is a test",
            Content     => "....",
            ContentType => "image/jpeg",
            Filename    => "test123.jpg"
          }
      }
   );
};

When qr/added image to a configitem$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/cmdb/configitems/'.S->{ConfigItemID}.'/images',
      Token   => S->{Token},
      Content => {
	      Image => {
	        Comment     => "this is a test",
	        Content     => "....",
	        ContentType => "image/jpeg",
	        Filename    => "test123.jpg"
	      }
	  }
   );
};
