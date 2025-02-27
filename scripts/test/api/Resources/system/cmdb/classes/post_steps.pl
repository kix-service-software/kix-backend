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

Given qr/a configitem class$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/cmdb/classes',
      Token   => S->{Token},
      Content => {
        ConfigItemClass => {
            Name => "test ci class".rand(),
            Comment => "for testing purposes"
        }
      }
   );
};

When qr/I create a configitem class$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/cmdb/classes',
      Token   => S->{Token},
      Content => {
        ConfigItemClass => {
            Name => "test ci class".rand(),
            Comment => "for testing purposes"
        }
      }
   );
};

When qr/I create a (\w+) with not existing valid id$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/cmdb/'.$1.'es',
      Token   => S->{Token},
        ConfigItemClass => {
            Name => "test ci class".rand(),
            Comment => "for testing purposes"
        }
   );
};

When qr/I create a (\w+) with no valid id$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/cmdb/'.$1.'es',
      Token   => S->{Token},
      Content => {
         ConfigItemClass => {
            %Properties
         }
      }
   );
};

When qr/I create a (\w+) with no name$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/cmdb/'.$1.'es',
      Token   => S->{Token},
      Content => {
         ConfigItemClass => {
            %Properties
         }
      }
   );
};
