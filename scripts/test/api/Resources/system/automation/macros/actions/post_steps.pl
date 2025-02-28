# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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

Given qr/a automation macro action$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/automation/macros/'.S->{MacroID}.'/actions',
      Token   => S->{Token},
      Content => {
        MacroAction => {
            Comment => "some comment given action",
            MacroID => S->{MacroID},
            Parameters => {
                Body => "The text of the new article.",
                ContactEmailOrID => "mamu@example.org",
                Priority => "5 very low",
                State => "new",
                Team => "Service Desk",
                Title => "Test macro actions"
            },
            Type => "TicketCreate",
            ValidID => 1
        }
      }
   );
};

Given qr/(\d+) of automation  macro action$/, sub {
    my $Name;
    my $Comment;
    my $Type;
    
    for ($i=0;$i<$1;$i++){
        if ( $i == 2 ) {
            $Name    = 'new macro action 2';
            $Comment = 'macro action 2 comment';
            $Type    = 'Ticket';
        }
        elsif ( $i == 3 ) {
            $Name    = 'new macro 3';
            $Comment = 'macro action 3 comment';
            $Type    = 'Ticket';
        }
        elsif ( $i   = 4 ) {
            $Name    = 'new macro action 4';
            $Comment = 'macro action 4 comment';
            $Type    = 'Ticket';
        }    
        else { 
            $Name    = 'new macro action'.rand();
            $Comment = 'test_macro_action_2_comment';
            $Type    = 'Ticket';        
        }

       ( S->{Response}, S->{ResponseContent} ) = _Post(
          URL     => S->{API_URL}.'/system/automation/macros/'.S->{MacroID}.'/actions',
          Token   => S->{Token},
          Content => {
            MacroAction => {
                Comment => $Comment,
                MacroID => S->{MacroID},
                Parameters => {
                    Body => "The text of the new article.",
                    ContactEmailOrID => "mamu@example.org",
                    Priority => "5 very low",
                    State => "new",
                    Team => "Service Desk",
                    Title => "Test macro actions"
                },
                Type => $Type,
                ValidID => 1
            }
          }
       );
    }
};

When qr/I create a automation macro action$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/automation/macros/'.S->{MacroID}.'/actions',
      Token   => S->{Token},
      Content => {
        MacroAction => {
            Comment => "some comment create action".rand(),
            MacroID => S->{MacroID},
            Parameters => {
                Body => "The text of the new article.",
                ContactEmailOrID => "mamu@example.org",
                Priority => "5 very low",
                State => "new",
                Team => "Service Desk",
                Title => "Test macro actions"
            },
            Type => "TicketCreate",
            ValidID => 1
        }
      }
   );
};

When qr/I create a automation macro action with no ContactEmailOrID$/, sub {
    ( S->{Response}, S->{ResponseContent} ) = _Post(
        URL     => S->{API_URL}.'/system/automation/macros/'.S->{MacroID}.'/actions',
        Token   => S->{Token},
        Content => {
            MacroAction => {
                Comment => "some comment create action".rand(),
                MacroID => S->{MacroID},
                Parameters => {
                    Body => "The text of the new article.",
                    Priority => "5 very low",
                    State => "new",
                    Team => "Service Desk",
                    Title => "Test macro actions"
                },
                Type => "TicketCreate",
                ValidID => 1
            }
        }
    );
};


