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

When qr/I query the collection of generalcatalog classes\s*$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
       Token => S->{Token},
       URL   => S->{API_URL} . '/system/generalcatalog/classes',
       Sort  =>  "ConfigItemClass.Name",
   );
};

Then qr/items of "(.*?)"$/, sub {
   my $Object = $1;
   my $Index = 0;

   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute (keys %{$Row}) {
         C->dispatch( 'Then', "the generalcatalogclasses \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
      }
      $Index++
   }
};

Then qr/the generalcatalogclasses "(.*?)" of the "(.*?)" item (\d+) is "(.*?)"$/, sub {
   is(S->{ResponseContent}->{$2}->[$3], $4, 'Check attribute value in response');
};

