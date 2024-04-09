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

When qr/I query the collection of automation macro type "(.*?)" actiontypes$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/automation/macros/types/'.$1.'/actiontypes',
   );
};

Then qr/the macroactiontype output is "(.*?)"/, sub {
   my $Name=$1;
   my $array=S->{ResponseContent}->{MacroActionType};
   my @AttributeValue =( "ArticleCreate", "ArticleDelete", "AssembleObject", "Conditional", "ContactSet", "CreateReport", "DynamicFieldSet", "ExecuteMacro", "ExtractText", "FetchAssetAttributes", "LockSet", "Loop", "OrganisationSet", "OwnerSet", "PrioritySet", "ResponsibleSet", "StateSet", "TeamSet", "TicketCreate", "TicketDelete", "TitleSet", "TypeSet", "VariableSet" );

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


