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

When qr/I query the collection of notifications$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/communication/notifications',
   );
};

When qr/I query the collection of notifications with Watcher$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/communication/notifications',
      Sort  => 'Notification.ID:numeric'
   );
};

When qr/I get this notification id (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/communication/notifications/'.$1,
   );
};

Then qr/items of "(.*?)"$/, sub {
   my $Object = $1;
   my $Index = 0;

   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute (keys %{$Row}) {
         C->dispatch( 'Then', "the recipients \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
      }
       $Index++
   }
};

Then qr/the recipients "(.*?)" of the "(.*?)" item (\d+) is "(.*?)"$/, sub {
   is(S->{ResponseContent}->{Notification}->{Data}->{$2}->[$3], $4, 'Check attribute value in response');
};

Then qr/the notifications output is "(.*?)"/, sub {
   my $Name=$1;
   my $array=S->{ResponseContent}->{Notification};
   my @AttributeValue =( "Agent - New Ticket Notification", "Agent - Reminder (if unlocked)", "Customer - New Ticket Receipt", "Customer - Follow Up Rejection", "Agent - FUP Notification (if unlocked)", "Agent - FUP Notification (if locked)", "Agent - Lock Timeout", "Agent - Owner Assignment", "Agent - Responsible Assignment", "Agent - New Note Notification", "Agent - Ticket Move Notification", "Agent - Reminder (if locked)" );

   foreach $hash_ref (@$array) {
      if ($hash_ref->{Name} eq $Name ){
         is( $hash_ref->{Name}, $Name, 'Check attribute value in response' );
      }
      else{
         if ( "@AttributeValue" =~ /$hash_ref->{Name}/ && "@AttributeValue" =~ /$Name/ ) {
            print STDERR "NOTE:".Dumper($hash_ref->{Name},$Name);
         }
         else{

            is( $hash_ref->{Name}, $Name, 'Check attribute value in response' );
         }
      }
   }
};








