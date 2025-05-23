# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --
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

When qr/I get a collection of dynamicfield types\s*$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/dynamicfields/types',
      Sort  => 'DynamicFieldType.Name:textual'
   );
};

Then qr/the dynamicfield types output is "(.*?)"/, sub {
   my $Name=$1;
   my $array=S->{ResponseContent}->{DynamicFieldType};
   my @AttributeValue =( "CheckList", "Date", "DateTime", "ITSMConfigItemReference", "Multiselect", "Table", "Text", "TextArea" );

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
