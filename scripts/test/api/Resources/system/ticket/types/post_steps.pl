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

Given qr/a tickettype$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/types',
      Token   => S->{Token},
      Content => {
        TicketType => {
            Name => "Change Request".rand(),
            Comment => "just for testing purposes",
            ValidID => 1
        }
      }
   );
};

When qr/I create a tickettype$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/types',
      Token   => S->{Token},
      Content => {
        TicketType => {
            Name => "Change Request".rand(),
            Comment => "just for testing purposes",
            ValidID => 1
        }
      }
   );
};

When qr/I create a tickettype with not existing valid id$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/types',
      Token   => S->{Token},
      Content => {
         TicketType => {
            %Properties
         }
      }
   );
};

When qr/I create a tickettype with no valid id$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/types',
      Token   => S->{Token},
      Content => {
         TicketType => {
            %Properties
         }
      }
   );
};

When qr/I create a tickettype with no name$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/types',
      Token   => S->{Token},
      Content => {
         TicketType => {
            %Properties
         }
      }
   );
};
