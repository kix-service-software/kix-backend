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

When qr/I patch this config object definitions "(.*?)"\s*$/, sub {
    ( S->{Response}, S->{ResponseContent} ) = _Patch(
        Token => S->{Token},
        URL   => S->{API_URL}.'/system/config/definitions/'.$1,
        Content => {
            SysConfigOptionDefinition => {
                Description => "this is a test",
                IsRequired => 1
            }

        }
    );
};