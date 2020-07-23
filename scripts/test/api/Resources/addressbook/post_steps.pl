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

Given qr/a addressbook$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/addressbook',
      Token   => S->{Token},
      Content => {
            Address => {
                EmailAddress => 'test'.rand().'@test.org',
            }
      }
   );
};

Given qr/(\d+) of addressbooks$/, sub {
    my $Address;
    
    for ($i=0;$i<$1;$i++){
        if ( $i == 2 ) {
            $Address = 'test_for_filter@test.org';
        }
        elsif ( $i == 3 ) {
            $Address = 'Thomas.Tester@test.org';
        }
        elsif ( $i == 4 ) {
            $Address = 'Thomas.Mustertester@test.org';
        }    
        else { 
            $Address = 'test'.rand().'@test.org';        
        }

        ( S->{Response}, S->{ResponseContent} ) = _Post(
            URL     => S->{API_URL}.'/addressbook',
            Token   => S->{Token},
            Content => {
                Address => {
                    EmailAddress => $Address,
                }
            }
        );
    }
};

When qr/added a addressbook$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/addressbook',
      Token   => S->{Token},
      Content => {
            Address => {
                EmailAddress => 'test'.rand().'@test.org',
            }
      }
   );
};

When qr/added a addressbook with address "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/addressbook',
      Token   => S->{Token},
      Content => {
            Address => {
                EmailAddress => $1,
            }
      }
   );
};



