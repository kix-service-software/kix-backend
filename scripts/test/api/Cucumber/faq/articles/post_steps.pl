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

Given qr/a faq article$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/faq/articles',
      Token   => S->{Token},
      Content => {
        FAQArticle => {
            Title => "Some Text2".rand(), 
            CategoryID => 1, 
            Visibility => "internal", 
            Language => "en", 
            ContentType => "text/plain", 
            Number => "13402", 
            Keywords => [
                "some", 
                "keywords" 
            ], 
            Field1 => "Symptom...", 
            Field2 => "Problem...", 
            Field3 => "Solution...", 
            Field4 => "Field4...", 
            Field5 => "Field5...", 
            Field6 => "Comment...", 
            Approved => 1, 
            ValidID => 1
        }  
      }
   );
};

When qr/I create a faq article$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/faq/articles',
      Token   => S->{Token},
      Content => {
        FAQArticle => {
            Title => "Some Text2".rand(), 
            CategoryID => 1, 
            Visibility => "internal", 
            Language => "en", 
            ContentType => "text/plain", 
            Number => "13402", 
            Keywords => [
                "some", 
                "keywords" 
            ], 
            Field1 => "Symptom...", 
            Field2 => "Problem...", 
            Field3 => "Solution...", 
            Field4 => "Field4...", 
            Field5 => "Field5...", 
            Field6 => "Comment...", 
            Approved => 1, 
            ValidID => 1
        }  
      }
   );
};
