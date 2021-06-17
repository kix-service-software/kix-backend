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

When qr/I query the collection of config optiontypes$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/config/optiontypes',
   );
};

Then qr/the response contains the following SysConfigOptionType array$/, sub {
   my $Object = "SysConfigOptionType";
   my $Index = 0;
print STDERR "SysConfigOptionType".Dumper(S->{ResponseContent}->{SysConfigOptionType});

   foreach my $Attribute ( S->{ResponseContent}->{SysConfigOptionType} ) {
      print STDERR "SysConfigOptionTypeAttr" . Dumper($Attribute);
      print STDERR "ATTRIBUTE".Dumper(@$Attribute);
      foreach my $test ( @$Attribute ) {
         print STDERR "SysConfigOptionTypeAttr2" . Dumper($test);
#         C->dispatch('Then', "the OptionTypes of the \"$Object\" item " . $Index . " is \"$test\"");
      $Index++
      }
   }
};