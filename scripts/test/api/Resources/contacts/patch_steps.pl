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

When qr/I update this contact$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Patch(
      URL     => S->{API_URL}.'/contacts/'.S->{ContactID},
      Token   => S->{Token},
      Content => {
         Contact => {
            Email => rand(2)."mamu\@example.org",
            Firstname => "Max",
            Lastname => "Mustermann",
            Login => "mamu".rand(2),
            OrganisationIDs => [
                  S->{OrganisationID}
            ],
            PrimaryOrganisationID => S->{OrganisationID}
         }
      }
   );
};