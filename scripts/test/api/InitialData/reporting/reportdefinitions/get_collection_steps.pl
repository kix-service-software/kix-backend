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

When qr/I query the reportdefinitions collection$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/reporting/reportdefinitions',
   );
};

Then qr/the reportdefinitions output is "(.*?)"/, sub {
   my $Name=$1;
   my $array=S->{ResponseContent}->{ReportDefinition};
   my @AttributeValue =( "Tickets Created In Date Range", "Tickets Closed In Date Range", "Number of tickets created within the last 7 days", "Number of open tickets by priority", "Number of open tickets by state", "Number of open tickets in teams by priority", "Number of open tickets by team", "Number of tickets closed within the last 7 days" );

   foreach $hash_ref (@$array) {
      if ($hash_ref->{Name} eq $Name ){
         is( $hash_ref->{Name}, $Name, 'Check attribute value in response' );
      }
      else{
         if ( "@AttributeValue" =~ /$hash_ref->{Name}/ && "@AttributeValue" =~ /$Name/ ) {

         }
         else{
            is( $hash_ref->{Name}, $Name, 'Check attribute value in response' );
         }
      }
   }
};

