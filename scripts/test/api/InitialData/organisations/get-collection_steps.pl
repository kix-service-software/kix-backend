use warnings;

use Cwd;
use lib cwd();
use lib cwd() . '/Kernel/cpan-lib';
use lib cwd() . '/Custom';
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

When qr/I query the collection of organisations$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/organisations',
      Sort  => 'Organisation.ID:numeric'
   );
};

When qr/I query the collection of organisations with df$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
       Token => S->{Token},
       URL   => S->{API_URL}.'/organisations',
       Include  => 'DynamicFields'
   );
};

Then qr/the DynamicField attributes are$/, sub {
   my $Object = 'DynamicFields';
   my $Index = 0;

   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         C->dispatch( 'Then', "the DF \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
      }
      $Index++
   }
};

Then qr/the DF "(.*?)" of the "(.*?)" item (\d+) is "(.*?)"$/, sub {
   if ( defined( S->{ResponseContent}->{Organisation}->[0]->{$2}->[$3]->{$1}) ) {
      S->{ResponseContent}->{Organisation}->[0]->{$2}->[$3]->{$1}   =~ s/^\s+|\s+$//g;
      is(S->{ResponseContent}->{Organisation}->[0]->{$2}->[$3]->{$1}, $4, 'Check attribute value in response');
   }
   else{
      is('', $4, 'Check attribute value in response');
   }
};
