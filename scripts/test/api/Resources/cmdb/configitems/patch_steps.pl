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

When qr/I update this configitem$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Patch(
      URL     => S->{API_URL}.'/cmdb/configitems/'.S->{ResponseContent}->{ConfigItemID},
      Token   => S->{Token},
      Content => {
            ConfigItem => {
               ClassID => 4,
               Version => {
                  Name => "test ci xx1111",
                  DeplStateID => 16,
                  InciStateID => 2,
                  Data => {
                     Vendor => "testvendor",
                     NIC => [
                        {
                           NIC => "e1000",
                           IPoverDHCP => [
                              39
                           ],
                           IPAddress => [
                              "192.168.1.0",
                              "192.168.1.1",
                              "192.168.1.2",
                              "192.168.1.3"
                           ],
                           Attachment => [
                              {
                                 Content =>  "cdfrdrfde", 
                                 ContentType =>  "application/pdf", 
                                 Filename =>  "/tmp/Test2.pdf" 
                              }
                           ] 
                        }
                     ]
                  }
               },
               Images => [
                  {
                     Filename => "SomeImage.jpg",
                     ContentType => "image/jpeg",
                     Content => "..."
                  }
               ]
            }
        }
   );
};
