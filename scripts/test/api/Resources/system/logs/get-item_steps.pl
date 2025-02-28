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

When qr/I get the first log\s*$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/logs/'.S->{ResponseContent}->{LogFile}->[0]->{ID},
   );
};

When qr/I get the last log\s*$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/logs/'.S->{ResponseContent}->{LogFile}->[2]->{ID},
   );
};

When qr/I get the last log include content\s*$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/logs?include=Content',
   );
};

Then qr/the response contains the following items of type (.*?)$/, sub {
    my @Array;
  foreach my $Attribute ( sort keys %{ S->{ResponseContent}->{LogFile}->[2] } ) {
    if ($Attribute eq 'Content'){
    C->dispatch('Then', "the Attribute Content is available");   
    }; 
  };
};
    
Then qr/the Attribute (.*?) is available\s*$/, sub {
   is(S->{ResponseContent}->{LogFile}->[2], $1, 'Check attribute value in response');
};
