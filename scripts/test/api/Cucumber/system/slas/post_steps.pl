use warnings;

use Cwd;
use lib cwd();
use lib cwd() . '/Kernel/cpan-lib';
use lib cwd() . '/Custom';
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

Given qr/a sla$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/slas',
      Token   => S->{Token},
      Content => {
            SLA  => {
                Name                    => 'SLATest1'.rand(),
                Calendar                => '...',
                FirstResponseTime       => 120,
                FirstResponseNotify     => 60,
                UpdateTime              => 180,
                UpdateNotify            => 80,
                SolutionTime            => 580,
                SolutionNotify          => 80,
                ValidID                 => 1,
                Comment                 => 'SLATest1Comment',
                TypeID                  => 2,
                MinTimeBetweenIncidents => 3443
            }
      }
   );
};

Given qr/(\d+) of sla$/, sub {
    my $Name;
    my $Comment;
    
    for ($i=0;$i<$1;$i++){
        if ( $i == 0 ) {
            $Name = 'SLATest_for_filter';
            $Comment = 'SLATestComment';
        }
        elsif ( $i == 2 ) {
            $Name = 'SLATest1_for_filter';
            $Comment = 'SLATest1Comment';
        }
        elsif ( $i == 3 ) {
            $Name = 'SLATest2_for_filter';
            $Comment = 'SLATest2Comment';
        }
        elsif ( $i == 4 ) {
            $Name = 'SLATest3_for_filter';
            $Comment = 'SLATest3Comment';
        }
        elsif ( $i == 5 ) {
            $Name = 'SLATest_4_for_filter';
            $Comment = 'SLATest4Comment';
        }
        else { 
            $Name = 'SLA_Test'.rand();
            $Comment = 'SLA_Test1Comment';     
        }

       ( S->{Response}, S->{ResponseContent} ) = _Post(
          URL     => S->{API_URL}.'/system/slas',
          Token   => S->{Token},
          Content => {
            SLA  => {
                Name                    => $Name,
                Calendar                => '...',
                FirstResponseTime       => 120,
                FirstResponseNotify     => 60,
                UpdateTime              => 180,
                UpdateNotify            => 80,
                SolutionTime            => 580,
                SolutionNotify          => 80,
                ValidID                 => 1,
                Comment                 => $Comment,
                TypeID                  => 2,
                MinTimeBetweenIncidents => 3443
            }
          }
       );
    }
};

When qr/I create a sla$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/slas',
      Token   => S->{Token},
      Content => {
            SLA  => {
                Name                    => 'SLATest1'.rand(),
                Calendar                => '...',
                FirstResponseTime       => 120,
                FirstResponseNotify     => 60,
                UpdateTime              => 180,
                UpdateNotify            => 80,
                SolutionTime            => 580,
                SolutionNotify          => 80,
                ValidID                 => 1,
                Comment                 => 'SLATest1Comment',
                TypeID                  => 2,
                MinTimeBetweenIncidents => 3443
            }
      }
   );
};

When qr/I create a sla with not existing type id$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/slas',
      Token   => S->{Token},
      Content => {
         SLA => {
            %Properties
         }
      }
   );
};

When qr/I create a sla with no type id$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/slas',
      Token   => S->{Token},
      Content => {
         SLA => {
            %Properties
         }
      }
   );
};

When qr/I create a sla with no name$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/slas',
      Token   => S->{Token},
      Content => {
         SLA => {
            %Properties
         }
      }
   );
};