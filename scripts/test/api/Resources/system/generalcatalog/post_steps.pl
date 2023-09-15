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

Given qr/a generalcatalog item$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/generalcatalog',
      Token   => S->{Token},
      Content => {
            GeneralCatalogItem => {
                Class => "ITSM::ConfigItem::Computer::Type",
                Name => rand(2)."Tablet"
            }
      }
   );
};

When qr/I create a generalcatalog item$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/generalcatalog',
      Token   => S->{Token},
      Content => {
            GeneralCatalogItem => {
                Class => "ITSM::ConfigItem::Computer::Type",
                Name => rand(2)."Tablet"
            }
      }
   );
};

When qr/I create a generalcatalog item without class$/, sub {
    ( S->{Response}, S->{ResponseContent} ) = _Post(
        URL     => S->{API_URL}.'/system/generalcatalog',
        Token   => S->{Token},
        Content => {
            GeneralCatalogItem => {
                Class => ,
                Name => rand(2)."Tablet"
            }
        }
    );
};