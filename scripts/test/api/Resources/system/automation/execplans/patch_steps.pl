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

When qr/I update this automation execplan$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Patch(
      URL     => S->{API_URL}.'/system/automation/execplans/'.S->{ExecPlanID},
      Token   => S->{Token},
      Content => {
        ExecPlan => {
            Comment => "some comment update",
            Name => "new execution plan update",
            Parameters => {
                Weekday => {
                    Name => "Monday"
                },
            Time => "10:00:00"
            },
            Type => "TimeBased",
            ValidID => 1
        }
      }
   );
};