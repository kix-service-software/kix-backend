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

When qr/I query the collection of tickets$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets',
   );
};

When qr/I query the collection of tickets with filter of "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets',
      Filter => '{"Ticket": {"AND": [{"Field": "Title","Operator": "STARTSWITH","Value": "'.$1.'"}]}}',
   );
};

When qr/I query the collection of tickets with filter contains of "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets',
      Filter => '{"Ticket": {"AND": [{"Field": "Title","Operator": "CONTAINS","Value": "'.$1.'"}]}}',
   );
};

When qr/I query the collection of tickets with AND-filter of Title "(.*?)" and PriorityID (\d+) and QueueID (\d+)$/, sub {  
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets',
      Filter => '{"Ticket": {"AND": [{"Field": "Title","Operator": "CONTAINS","Value": "'.$1.'"},{"Field": "PriorityID","Operator": "IN","Value": [1,3,4],"Type": "numeric"},{"Field": "QueueID","Operator": "EQ","Value": "'.$3.'","Type": "numeric"}, "Not": true}]}}',
   );
};

When qr/I query the collection of tickets with limit (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets',
      Limit => $1,
   );
};

When qr/I query the collection of tickets with offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets',
      Filter => '{"Ticket": {"AND": [{"Field": "StateID","Operator": "EQ","Value": "6","Not": true}]}}',
      Offset => $1,
   );
};

When qr/I query the collection of tickets with limit (\d+) and offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets',
      Filter => '{"Ticket": {"AND": [{"Field": "StateID","Operator": "EQ","Value": "6","Not": true}]}}',
      Limit  => $1,
      Offset => $2,
   );
};

When qr/I query the collection of tickets with sorted by "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets',
      Filter => '{"Ticket": {"AND": [{"Field": "StateID","Operator": "EQ","Value": "6","Not": true}]}}',
      Sort => $1,
   );
};

When qr/I query the collection of tickets with sorted by "(.*?)" limit (\d+) and offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets',
      Filter => '{"Ticket": {"AND": [{"Field": "StateID","Operator": "EQ","Value": "6","Not": true}]}}',
      Sort => $1,
      Limit  => $2,
      Offset => $3,
   );
};

When qr/I query the collection of tickets (\d+) searchlimit$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets?searchlimit='.$1,
#      Filter => '{"Ticket": {"AND": [{"Field": "StateID","Operator": "EQ","Value": "6","Not": true}]}}',
   );
};

When qr/I query the collection of tickets (\d+) searchlimit object$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/tickets?searchlimit=Ticket:'.$1,
#      Filter => '{"Ticket": {"AND": [{"Field": "StateID","Operator": "EQ","Value": "6","Not": true}]}}',
   );
};

When qr/I query the collection of tickets with multiplesort by "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
       Token => S->{Token},
       URL   => S->{API_URL}.'/tickets',
       Sort => $1,
       #      Filter => '{"Ticket": {"AND": [{"Field": "StateID","Operator": "EQ","Value": "6","Not": true}]}}',
   );
};


Then qr/the response now contains (\d+) items of type "(.*?)"$/, sub {
   is(@{S->{ResponseContent}->{$2}}, $1, 'Check response item count');
   my $Anzahl = @{S->{ResponseContent}->{$2}};
   print STDERR "AnzahlTickets:".Dumper($Anzahl);
};