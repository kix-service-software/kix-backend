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

When qr/I query the collection of ticket priorities$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/ticket/priorities',
      Limit => $1,
   );
};

When qr/I query the collection of ticket priorities with a limit of (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/ticket/priorities',
      Limit => $1,
   );
};

When qr/I query the collection of ticket priorities and with a limit of (\d+) and an offset of (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token  => S->{Token},
      URL    => S->{API_URL}.'/system/ticket/priorities',
      Limit  => $1,
      Offset => $2,
   );
};

When qr/I query the collection of ticket priorities sorted by "(.*?)" and with a limit of (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token  => S->{Token},
      URL    => S->{API_URL}.'/system/ticket/priorities',
      Sort   => $1,
      Limit  => $2,
   );
};

When qr/I query the collection of ticket priorities sorted by "(.*?)" and with a limit of (\d+) and an offset of (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token  => S->{Token},
      URL    => S->{API_URL}.'/system/ticket/priorities',
      Sort   => $1,
      Limit  => $2,
      Offset => $3,
   );
};

Then qr/the priorities output is "(.*?)"/, sub {
   my $Name=$1;
   my $array=S->{ResponseContent}->{Priority};
   my @AttributeValue =( "5 very low", "4 low", "3 normal" , "2 high", "1 very high" );

   foreach $hash_ref (@$array) {
      if ($hash_ref->{Name} eq $Name ){
         is( $hash_ref->{Name}, $Name, 'Check attribute value in response' );
      }
      else{
         if ( "@AttributeValue" =~ /$hash_ref->{Name}/ && "@AttributeValue" =~ /$Name/ ) {

         }
         else{
            is( $hash_ref->{Name}, $Name, 'Check attribute value in response' );
         }
      }
   }
};

