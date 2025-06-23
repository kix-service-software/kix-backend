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

Given qr/a clientregistration$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/clientregistrations',
      Token   => S->{Token},
      Content => {
        ClientRegistration => {
            ClientID => "KIX-Frontend".rand(),
            Authorization => "test123",
            NotificationURL => "http://kix-frontend.example.org/notifications",
            NotificationInterval => 30
        }
      }
   );
};

When qr/added a clientregistration ohne authorization$/, sub {
    ( S->{Response}, S->{ResponseContent} ) = _Post(
        URL     => S->{API_URL}.'/clientregistrations',
        Token   => S->{Token},
        Content => {
            ClientRegistration => {
                ClientID => "KIX-Frontend".rand(),
                Authorization => "",
                NotificationURL => "http://kix-frontend.example.org/notifications",
                NotificationInterval => 30
            }
        }
    );
};

Given qr/(\d+) of clientregistrations$/, sub {
    my $ClientID;
        
    for ($i=0;$i<$1;$i++){
        if ( $i == 2 ) {
            $ClientID = 'KIX-Frontend_Test_Filter';
        }
        else { 
            $ClientID = "KIX-Frontend".rand();        
        }

       ( S->{Response}, S->{ResponseContent} ) = _Post(
          URL     => S->{API_URL}.'/clientregistrations',
          Token   => S->{Token},
          Content => {
                ClientRegistration => {
                    ClientID => $ClientID,
                    Authorization => "test123",
                    NotificationURL => "http://kix-frontend.example.org/notifications",
                    NotificationInterval => 30
                }
           }
        );
    }
};

When qr/added a clientregistration$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/clientregistrations',
      Token   => S->{Token},
      Content => {
        ClientRegistration => {
            ClientID => "KIX-Frontend".rand(),
            Authorization => "test123",
            NotificationURL => "http://kix-frontend.example.org/notifications",
            NotificationInterval => 30
        }
      }
   );
};