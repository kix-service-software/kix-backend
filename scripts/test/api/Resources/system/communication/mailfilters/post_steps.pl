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

Given qr/a mailfilter$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/communication/mailfilters',
      Token   => S->{Token},
      Content => {
        MailFilter => {
            Comment => "...",
            Match => [
                {
                    Key => "From",
                    Value => "email\@example.com",
                    Not => 1
                },
                {
                    Key => "Subject",
                    Value => "Test"
                }
            ],
            Name => "new filter".rand(),
            Set => [
                {
                    Key => "X-KIX-Queue",
                    Value => "Some::Queue"
                }
            ],
            StopAfterMatch => 1,
            ValidID => 1
        
        }
      }
   );
};


When qr/I create a mailfilter$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/communication/mailfilters',
      Token   => S->{Token},
      Content => {
        MailFilter => {
            Comment => "...",
            Match => [
                {
                    Key => "From",
                    Value => "email\@example.com",
                    Not => 1
                },
                {
                    Key => "Subject",
                    Value => "Test"
                }
            ],
            Name => "new filter".rand(),
            Set => [
                {
                    Key => "X-KIX-Queue",
                    Value => "Some::Queue"
                }
            ],
            StopAfterMatch => 1,
            ValidID => 1
        
        }
      }
   );
};

