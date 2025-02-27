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

Given qr/a automation job post$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/automation/jobs',
      Token   => S->{Token},
      Content => {
        Job => {
            Comment => "some comment only",
            Name => "new job only post",
            Type => "Ticket",
            ValidID => 1
        }
      }
   );
};

Given qr/a automation job$/, sub {
    ( S->{Response}, S->{ResponseContent} ) = _Post(
        URL     => S->{API_URL}.'/system/automation/jobs',
        Token   => S->{Token},
        Content => {
            Job => {
                Comment => "some comment only".rand(),
                Name => "new job only".rand(),
                Type => "Ticket",
                ValidID => 1
            }
        }
    );
};

Given qr/(\d+) of automation jobs$/, sub {
    my $Name;
    my $Comment;
    my $Type;
    
    for ($i=0;$i<$1;$i++){
        if ( $i == 2 ) {
            $Name    = 'test_job_2';
            $Comment = 'test_job_2_comment';
            $Type    = 'FAQ';
        }
        elsif ( $i == 3 ) {
            $Name    = 'test_job_3';
            $Comment = 'test_job_2_comment';
            $Type    = 'Ticket';
        }
        elsif ( $i == 4 ) {
            $Name    = 'test_job_4';
            $Comment = 'test_job_4_comment';
            $Type    = 'Ticket';
        }    
        else { 
            $Name    = 'test_job_'.rand();
            $Comment = 'test_job_2_comment';
            $Type    = 'Ticket';        
        }

        ( S->{Response}, S->{ResponseContent} ) = _Post(
            URL     => S->{API_URL}.'/system/automation/jobs',
            Token   => S->{Token},
            Content => {
                Job => {
                    Comment => $Comment,
                    Name    => $Name,
                    Type    => $Type,
                    ValidID => 1
                }
            }
        );
    }
};

When qr/I create a automation job$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/automation/jobs',
      Token   => S->{Token},
      Content => {
        Job => {
            Comment => "some comment",
            Name => "new job",
            Type => "Ticket",
            ValidID => 1
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
