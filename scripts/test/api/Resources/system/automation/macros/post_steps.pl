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

Given qr/a automation macro$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/automation/macros',
      Token   => S->{Token},
      Content => {
        Macro => {
#            Actions => [
#                {
#                    Comment => "some comment".rand(),
#                    Name => "new macro".rand(),
#                    Parameters => {},
#                    Type => "Ticket",
#                    ValidID => 1
#                }
#            ],
            Comment => "some comment".rand(),
            Name => "new macro".rand(),
            Type => "Ticket",
            ValidID => 1
        }
      }
   );
};

Given qr/a automation macro without action$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/automation/macros',
      Token   => S->{Token},
      Content => {
        Macro => {
            Comment => "some comment".rand(),
            Name => "new macro".rand(),
            Type => "Ticket",
            ValidID => 1
        }
      }
   );
};

Given qr/(\d+) of automation  macros$/, sub {
    my $Name;
    my $Comment;
    my $Type;
    
    for ($i=0;$i<$1;$i++){
        if ( $i == 2 ) {
            $Name    = 'new macro 2';
            $Comment = 'macro 2 comment';
            $Type    = 'Ticket';
        }
        elsif ( $i == 3 ) {
            $Name    = 'new macro 3';
            $Comment = 'macro 3 comment';
            $Type    = 'Ticket';
        }
        elsif ( $i   = 4 ) {
            $Name    = 'new macro 4';
            $Comment = 'macro 4 comment';
            $Type    = 'Ticket';
        }    
        else { 
            $Name    = 'new macro'.rand();
            $Comment = 'test_macro_2_comment'.rand();
            $Type    = 'Ticket';        
        }

       ( S->{Response}, S->{ResponseContent} ) = _Post(
          URL     => S->{API_URL}.'/system/automation/macros',
          Token   => S->{Token},
          Content => {
            Macro => {
#                Actions => [
#                    {
#                    Comment => "some comment".rand(),
#                    Name => "new macro".rand(),
#                    Parameters => {},
#                    Type => "Ticket",
#                    ValidID => 1
#                    }
#                ],
                Comment => $Comment,
                Name => $Name,
                Type => $Type,
                ValidID => 1
            }
          }
       );
    }
};

When qr/I create a automation macro$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/automation/macros',
      Token   => S->{Token},
      Content => {
        Macro => {
            Comment => "some comment",
            Name => "new macro",
            Type => "Ticket",
            ValidID => 1
        }
      }
   );
};

