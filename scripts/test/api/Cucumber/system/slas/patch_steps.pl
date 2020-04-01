use warnings;

use Cwd;
use lib cwd();
use lib cwd() . '/Kernel/cpan-lib';
use lib cwd() . '/plugins';
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

When qr/I update this sla$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Patch(
      URL     => S->{API_URL}.'/system/slas/'.S->{ResponseContent}->{SLAID},
      Token   => S->{Token},
      Content => {
            SLA  => {
                Name                    => 'SLATest1Update'.rand(),
                Calendar                => '...',
                FirstResponseTime       => 120,
                FirstResponseNotify     => 60,
                UpdateTime              => 180,
                UpdateNotify            => 80,
                SolutionTime            => 580,
                SolutionNotify          => 80,
                ValidID                 => 1,
                Comment                 => 'SLATest1CommentUpdate',
                TypeID                  => 2,
                MinTimeBetweenIncidents => 3443
            }
      }
   );
};

