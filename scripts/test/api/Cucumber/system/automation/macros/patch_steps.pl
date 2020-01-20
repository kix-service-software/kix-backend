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

When qr/I update this automation macro$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Patch(
      URL     => S->{API_URL}.'/system/automation/macros/'.S->{MacroID},
      Token   => S->{Token},
      Content => {
        Macro => {
            Actions => [
                {
                    Comment => "some comment update",
                    Name => "new macro update",
                    Parameters => {},
                    Type => "Ticket",
                    ValidID => 1
                }
            ],
            Comment => "some comment update",
            Name => "new macro update",
            Type => "Ticket",
            ValidID => 1
        }
      }
   );
};