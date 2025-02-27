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
 
When qr/I query the collection of dynamicfields$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/dynamicfields',
      Sort  => 'DynamicField.Name:textual'
   );
};

Then qr/the dynamicfield output is "(.*?)"/, sub {
   my $Name=$1;
   my $array=S->{ResponseContent}->{DynamicField};
   my @AttributeValue =( "AddressDomainPattern", "AffectedAsset", "AffectedServices", "AnonymiseTicket", "ChildTickets", "CloseCode", "CreateFAQSuggestion", "MergeToTicket", "MobileProcessingChecklist010", "MobileProcessingChecklist020", "MobileProcessingState", "PlanBegin", "PlanEnd", "ParentTickets", "ParentTickets", "PlannedEffort", "RelatedAssets", "RelatedNewsTickets", "RelatedTickets", "RiskAssumptionRemark", "SatisfactionPoints", "SatisfactionRemark", "Source", "SysMonXAddress", "SysMonXAlias", "SysMonXHost", "SysMonXService", "SysMonXStateSysMonXState","Type", "WorkOrder" );

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

