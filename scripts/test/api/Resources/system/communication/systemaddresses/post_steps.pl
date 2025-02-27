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

Given qr/a systemaddress$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/communication/systemaddresses',
      Token   => S->{Token},
      Content => {
        SystemAddress => {
            Name => rand()."support\@cape-it.de",
            Realname => "Helpdesk"
        }
      }
   );
};

When qr/I create a systemaddress$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/communication/systemaddresses',
      Token   => S->{Token},
      Content => {
        SystemAddress => {
            Name => rand()."support\@cape-it.de",
            Realname => "Helpdesk RealName"
        }
      }
   );
};

When qr/I create a systemaddress with not existing valid id$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/communication/systemaddresses',
      Token   => S->{Token},
      Content => {
         Service => {
            %Properties
         }
      }
   );
};

When qr/I create a systemaddress with no valid id$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/communication/systemaddresses',
      Token   => S->{Token},
      Content => {
         Service => {
            %Properties
         }
      }
   );
};

When qr/I create a systemaddress with no name$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/communication/systemaddresses',
      Token   => S->{Token},
      Content => {
         Service => {
            %Properties
         }
      }
   );
};
