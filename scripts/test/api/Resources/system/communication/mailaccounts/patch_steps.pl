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

When qr/I update this mailaccount$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Patch(
      URL     => S->{API_URL}.'/system/communication/mailaccounts/'.S->{MailAccountID},
      Token   => S->{Token},
      Content => {
        MailAccount => {
            Login => "mail".rand(), 
            Password => "SomePassword".rand(), 
            Host => "pop3.example.com", 
            Type => "POP3", 
            IMAPFolder => "Some Folder", 
            Trusted => 0, 
            DispatchingBy => "Queue", 
            QueueID => 2, 
            Comment => "Test MailAccount Update", 
            ValidID => 1 
        } 
      }
   );
};
