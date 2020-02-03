use warnings;

use Cwd;
use lib cwd();
use lib cwd() . '/Kernel/cpan-lib';
use lib cwd() . '/Custom';
use lib cwd() . '/scripts/test/api/Cucumber';

use LWP::UserAgent;
use HTTP::Request;
use JSON::XS qw(encode_json decode_json);
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

When qr/I query the collection of dynamicfield (.*?)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/dynamicfields',
      Filter => '{"DynamicField": {"AND": [{"Field": "Name","Operator": "STARTSWITH","Value": "'.$1.'"}]}}',
   );
};

When qr/I get this dynamicfield config$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/dynamicfields/'.S->{ResponseContent}->{DynamicField}->[0]->{ID}.'/config',
   );
};

Then qr/the response contains the following attributes$/, sub {
    my $Object = $1;
    my $Index = 0;
 
    foreach my $Row ( sort keys %{S->{ResponseContent}->{DynamicFieldConfig}} ) {
        foreach my $Attribute ( keys %{$Row}) {
            C->dispatch( 'Then', "the attribute \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
        }
        $Index++
    }
};

Then qr/the response contains the following PossibleValues$/, sub {
    my $Object = $1;
    my $Index = 0;
 
    foreach my $Row ( sort keys %{S->{ResponseContent}->{DynamicFieldConfig}->{PossibleValues}} ) {
        foreach my $Attribute ( keys %{$Row}) {
            C->dispatch( 'Then', "the attribute \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
        }
        $Index++
    }
};