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

When qr/I query the collection of config$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/config',
   );
};

Then qr/the response contains the following (.*?) key "(.*?)"$/, sub {
    my $Object = $1;
    my $Index = 0;
    my @SysConfigOptionArray;
    
    foreach my $Row ( @{S->{ResponseContent}->{SysConfigOption}} ) {
        if ($Row->{Name} eq "$2") {
            push (@SysConfigOptionArray, $Row);
        }
    }

    S->{ResponseContent}->{SysConfigOption} = \@SysConfigOptionArray;

    foreach my $Row ( @{ C->data } ) {
        foreach my $Attribute ( keys %{$Row}) {
            C->dispatch( 'Then', "the attribute \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
        }
        $Index++
    }
};





