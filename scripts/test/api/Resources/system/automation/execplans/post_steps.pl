# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --
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

Given qr/a automation execplan$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/automation/execplans',
      Token   => S->{Token},
      Content => {
        ExecPlan => {
            Comment => "some comment",
            Name => "new execution plan".rand(),
            Parameters => {
                Weekday => {
                    Name => "Monday"
                },
            Time => "10:00:00"
            },
            Type => "TimeBased",
            ValidID => 1
        }
      }
   );
};

Given qr/a automation execplan for get$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/automation/execplans',
      Token   => S->{Token},
      Content => {
        ExecPlan => {
            Comment => "some comment fro get",
            Name => "new execution plan for get",
            Parameters => {
                Weekday => {
                    Name => "Monday"
                },
            Time => "10:00:00"
            },
            Type => "TimeBased",
            ValidID => 1
        }
      }
   );
};

Given qr/(\d+) of automation execplans$/, sub {
    my $Name;
    my $Comment;
    my $Event;
    
    for ($i=0;$i<$1;$i++){
        if ( $i == 2 ) {
            $Name    = 'new execution plan 2';
            $Comment = 'execution plan 2 comment';
            $Event    = 'TicketCreate';
        }
        elsif ( $i == 3 ) {
            $Name    = 'new execution plan 3';
            $Comment = 'execution plan 3 comment';
            $Event    = 'TicketCreate';
        }
        elsif ( $i   = 4 ) {
            $Name    = 'new execution plan 4';
            $Comment = 'execution plan 4 comment';
            $Event    = 'TicketCreate';
        }    
        else { 
            $Name    = 'new execution plan'.rand();
            $Comment = 'test_job_2_comment';
            $Event    = 'TicketCreate';        
        }

       ( S->{Response}, S->{ResponseContent} ) = _Post(
          URL     => S->{API_URL}.'/system/automation/execplans',
          Token   => S->{Token},
          Content => {
            ExecPlan => {
                Comment => "some comment",
                Name => "new execution plan",
                Parameters => {
                    Weekday => {
                        Name => "Monday"
                    },
                Time => "10:00:00"
                },
                Type => "TimeBased",
                ValidID => 1
            }
          }
       );
    }
};

When qr/I create a automation execplan$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/automation/execplans',
      Token   => S->{Token},
      Content => {
        ExecPlan => {
            Comment => "some comment",
            Name => "new execution plan".rand(),
            Parameters => {
                Weekday => {
                    Name => "Monday"
                },
            Time => "10:00:00"
            },
            Type => "TimeBased",
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
