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

When qr/I query the collection of faq articles keywords$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/faq/articles/keywords',
   );
};

Then qr/the response contains (\d+) items type of FAQKeyword$/, sub {
   my @FAQKeyword;

   foreach my $Row ( @{S->{ResponseContent}->{FAQKeyword}} ) {
      push (@FAQKeyword, $Row);
   }
   is(@FAQKeyword, $1, 'Check response item count');
   my $Anzahl = @FAQKeyword;
};

Then qr/the response contains the following items type of FAQKeyword$/, sub {
   my $Object = "FAQKeyword";
   my $Index = 0;
   my $Attribute = 'Keyword';
   my @Classes= ();

   for ($i=0;$i<@{S->{ResponseContent}->{FAQKeyword}};$i++){
      push(@Keyword, {Class => S->{ResponseContent}->{FAQKeyword}->[$i]});
   }
   my $KeywordHash = {@Keyword};
   foreach my $Attribute ( keys %KeywordHash) {
      C->dispatch( 'Then', "the attribute \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
   }
   $Index++
};
