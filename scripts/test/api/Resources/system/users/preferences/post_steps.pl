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

Given qr/a user preference$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }
  
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/users/'.S->{UserID}.'/preferences',
      Token   => S->{Token},
      Content => {
        UserPreference => {
            ID => "UserListLimit",
            Value => "10"
        }
      }
   );
};

When qr/added a user preference$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }
  
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/users/'.S->{UserID}.'/preferences',
      Token   => S->{Token},
      Content => {
        UserPreference => {
            ID => "UserListLimit",
            Value => "10"
        }
      }
   );
};