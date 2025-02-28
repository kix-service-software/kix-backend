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

Given qr/a ticketstate$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/states',
      Token   => S->{Token},
      Content => {
        TicketState => {
            Name => "closed with workaround create".rand(),
            Comment => "just for testing purposes",
            TypeID => 3,
            ValidID => 1
        }
      }
   );
};

When qr/I create a ticketstate$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/states',
      Token   => S->{Token},
      Content => {
        TicketState => {
            Name => "closed with workaround create".rand(),
            Comment => "just for testing purposes",
            TypeID => 3,
            ValidID => 1
        }
      }
   );
};

When qr/I create a ticketstate with not existing valid id$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/states',
      Token   => S->{Token},
      Content => {
        TicketState => {
            Name => "closed with workaround create",
            Comment => "just for testing purposes",
            TypeID => 3,
            ValidID => 1
        }
      }
   );
};

When qr/I create a ticketstate with no valid id$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/states',
      Token   => S->{Token},
      Content => {
        TicketState => {
            Name => "closed with workaround create",
            Comment => "just for testing purposes",
            TypeID => 3,
            ValidID => 1
        }
      }
   );
};

When qr/I create a ticketstate with no name$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/states',
      Token   => S->{Token},
      Content => {
        TicketState => {
            Name => "closed with workaround create",
            Comment => "just for testing purposes",
            TypeID => 3,
            ValidID => 1
        }
      }
   );
};
