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

Given qr/a ticket priority with$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/priorities',
      Token   => S->{Token},
      Content => {
        Priority => {
            Name => "lowest".rand(),
            Comment => "just for testing purposes",
            ValidID => 1
        }
      }
   );
};

When qr/I create a ticket priority with$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/priorities',
      Token   => S->{Token},
      Content => {
        Priority => {
            Name => "lowest".rand(),
            Comment => "just for testing purposes",
            ValidID => 1
        }

      }
   );
};

When qr/I create a ticket priority with not existing valid id$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/priorities',
      Token   => S->{Token},
      Content => {
        Priority => {
            Name => "lowest".rand(),
            Comment => "just for testing purposes",
            ValidID => 22
        }
      }
   );
};

When qr/I create a ticket priority with no valid id$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/priorities',
      Token   => S->{Token},
      Content => {
        Priority => {
            Name => "lowest".rand(),
            Comment => "just for testing purposes",
            ValidID => 
        }
      }
   );
};

When qr/I create a ticket priority with no name$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/priorities',
      Token   => S->{Token},
      Content => {
        Priority => {
            Name => "",
            Comment => "just for testing purposes",
            ValidID => 1
        }
      }
   );
};
