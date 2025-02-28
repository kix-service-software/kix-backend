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

Given qr/a role$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/roles',
      Token   => S->{Token},
      Content => {
        Role => {
            Name         => "the new stats role GET".rand(),
            Comment      => "...",
            ValidID      => 1,
            UsageContext => 1
        }
      }
   );
};

Given qr/a role with Name "the new stats role GET"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
       URL     => S->{API_URL}.'/system/roles',
       Token   => S->{Token},
       Content => {
           Role => {
               Name         => "the new stats role GET",
               Comment      => "...",
               ValidID      => 1,
               UsageContext => 1
           }
       }
   );
};


When qr/I create a role$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/roles',
      Token   => S->{Token},
      Content => {
        Role => {
            Name => "the new stats role".rand(),
            Comment => "...",
            ValidID => 1,
            UsageContext => 1
        }
      }
   );
};

When qr/I create a role with not existing valid id$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/roles',
      Token   => S->{Token},
      Content => {
         Role => {
            %Properties
         }
      }
   );
};

When qr/I create a role with no valid id$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/roles',
      Token   => S->{Token},
      Content => {
         Role => {
            %Properties
         }
      }
   );
};

When qr/I create a role with no name$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/roles',
      Token   => S->{Token},
      Content => {
         Role => {
            %Properties
         }
      }
   );
};

When qr/I get the role with ID (\d+)\s*$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/roles/'.$1,
   );
};

