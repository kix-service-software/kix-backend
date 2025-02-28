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

When qr/I get this ticket queue$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/ticket/queues/'.S->{QueueID},
   );
};

When qr/I get the ticket queue include subqueues with ID (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/ticket/queues/'.$1,
      Include => SubQueues,
   );
};

Then qr/the response contains the following queueid of type "(.*?)"$/, sub {
    my $Object = $1;
    my $Index = 0;    

    my %Row = ( SubQueue => S->{ResponseContent}->{Queue}->{SubQueues}->[0] );
    foreach my $Attribute ( keys %{$Row}) {
        C->dispatch( 'Then', "the attribute \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
    }
    $Index++
};

When qr/I get the ticket queue include and expand subqueues with ID (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/ticket/queues/'.$1.'?include=SubQueues&expand=SubQueues',
   );
};

Then qr/the response contains the following queue items of type "(.*?)"$/, sub {
    my $Object = $1;
    my $Index = 0;

    foreach my $Row ( sort keys %{S->{ResponseContent}->{Queue}->{SubQueues}->[0]} ) {
        foreach my $Attribute ( keys %{$Row}) {
            if ($Attribute eq 'SubQueue'){next;};
            C->dispatch( 'Then', "the attribute \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
        }
        $Index++
    }
};


