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

Given qr/a service with$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/services',
      Token   => S->{Token},
      Content => {
        Service => {
            Comment => "ServicesComment",
            Criticality => "3 normal",
            Name => "testservice".rand(),
            ParentID => 1,
            TypeID => 1,
            ValidID => 1
        }
      }
   );
};

Given qr/(\d+) of service$/, sub {
    my $Name;
    
    for ($i=0;$i<$1;$i++){
        if ( $i == 2 ) {
            $Name = 'testservice_for_filter';
        }
        elsif ( $i == 3 ) {
            $Name = 'testservice_for_filter2';
        }
        elsif ( $i == 4 ) {
            $Name = 'testservice_for_filter3';
        }
        elsif ( $i == 5 ) {
            $Name = 'testservice_for_filter4';
        }
        else { 
            $Name = "testservice".rand();        
        }

       ( S->{Response}, S->{ResponseContent} ) = _Post(
          URL     => S->{API_URL}.'/system/services',
          Token   => S->{Token},
          Content => {
            Service => {
                Comment => "ServicesComment",
                Criticality => "3 normal",
                Name => $Name,
                ParentID => 1,
                TypeID => 1,
                ValidID => 1
            }
          }
       );
    }
};

When qr/create a service with$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/services',
      Token   => S->{Token},
      Content => {
        Service => {
            Comment => "ServicesComment",
            Criticality => "3 normal",
            Name => "testservice".rand(),
            ParentID => 1,
            TypeID => 1,
            ValidID => 1
        }
      }
   );
};
#When qr/I create a service with not existing valid id$/, sub {
#   my %Properties;
#   foreach my $Row ( @{ C->data } ) {
#      foreach my $Attribute ( keys %{$Row}) {
#         $Properties{$Attribute} = $Row->{$Attribute};
#      }
#   }
#
#   ( S->{Response}, S->{ResponseContent} ) = _Post(
#      URL     => S->{API_URL}.'/services',
#      Token   => S->{Token},
#      Content => {
#         Service => {
#            %Properties
#         }
#      }
#   );
#};

#When qr/I create a service with no valid id$/, sub {
#   my %Properties;
#   foreach my $Row ( @{ C->data } ) {
#      foreach my $Attribute ( keys %{$Row}) {
#         $Properties{$Attribute} = $Row->{$Attribute};
#      }
#   }
 #
#   ( S->{Response}, S->{ResponseContent} ) = _Post(
#      URL     => S->{API_URL}.'/services',
#      Token   => S->{Token},
#      Content => {
#         Service => {
#            %Properties
#         }
#      }
#   );
#};

#When qr/I create a service with no name$/, sub {
#   my %Properties;
#   foreach my $Row ( @{ C->data } ) {
#      foreach my $Attribute ( keys %{$Row}) {
#         $Properties{$Attribute} = $Row->{$Attribute};
#      }
#   }
#
#   ( S->{Response}, S->{ResponseContent} ) = _Post(
#      URL     => S->{API_URL}.'/services',
#      Token   => S->{Token},
#      Content => {
#         Service => {
#            %Properties
#         }
#      }
#   );
#};
