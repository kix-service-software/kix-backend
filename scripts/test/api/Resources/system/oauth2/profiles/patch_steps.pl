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

When qr/I update this oauth2-profile$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Patch(
      URL     => S->{API_URL}.'/system/oauth2/profiles/'.S->{ResponseContent}->{ProfileID},
      Token   => S->{Token},
      Content => {
          Profile => {
              ClientID => "id of client update",
              ClientSecret => "secret of client update",
              Name => "OAuth2 Profile update",
              Scope => "scope to request for access token",
              URLAuth => "https://authorization-server.com/auth",
              URLRedirect => "https://localhost/authcode",
              URLToken => "https://authorization-server.com/token",
              ValidID => 1
          }

      }
   );
};

