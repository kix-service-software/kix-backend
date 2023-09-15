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

When qr/I query the collection of generalcatalog class$/, sub {
   my $Object = "GeneralCatalogClass";
   my $Index = 0;

   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/generalcatalog/classes',
   );
};

Then qr/the response contains (\d+) items type of GeneralCatalogClass$/, sub {
   my @GeneralCatalogClass;

   foreach my $Row ( @{S->{ResponseContent}->{GeneralCatalogClass}} ) {
      push (@GeneralCatalogClass, $Row);
   }
   is(@GeneralCatalogClass, $1, 'Check response item count');
   my $Anzahl = @GeneralCatalogClass;
};

Then qr/response contains the following items type GeneralCatalogClass$/, sub {
    my $Object = "GeneralCatalogClass";
    my $Index = 0;
    my $Attribute = 'Class';
    my @Classes= ();

    for ($i=0;$i<@{S->{ResponseContent}->{GeneralCatalogClass}};$i++){
       push(@Classes, {Class => S->{ResponseContent}->{GeneralCatalogClass}->[$i]});
    }
    my $ClassHash = {@Classes};
    foreach my $Attribute ( keys %ClassHash) {
          C->dispatch( 'Then', "the attribute \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
    }
    $Index++
};

