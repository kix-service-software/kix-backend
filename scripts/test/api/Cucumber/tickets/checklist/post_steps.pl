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

Given qr/a ticket checklist$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/tickets/'.S->{TicketID}.'/checklist',
      Token   => S->{Token},
      Content => {
        ChecklistItem => {
            Text     => 'TestCheckList'.rand(),
            State    => 'open',
            Position => 1
        },
     }
   );
};



Given qr/(\d+) of (\w+) with$/, sub {
    for ($i=0;$i<$1;$i++){	
	   ( S->{Response}, S->{ResponseContent} ) = _Post(
	      URL     => S->{API_URL}.'/tickets/'.S->{TicketID}.'/checklist',
	      Token   => S->{Token},
	      Content => {
            ChecklistItem => {
                Text     => 'TestCheckList'.rand(),
                State    => 'open',
                Position => 1
            }
     }
	   );
   }
};


When qr/I create a ticket checklist$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/tickets/'.S->{TicketID}.'/checklist',
      Token   => S->{Token},
      Content => {
        ChecklistItem => {
            Text     => 'TestCheckList'.rand(),
            State    => 'open',
            Position => 1
        },
      }
   );
};

