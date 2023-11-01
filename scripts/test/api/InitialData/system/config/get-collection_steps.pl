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

When qr/I query the collection of config "(.*?)"$/, sub {
    ( S->{Response}, S->{ResponseContent} ) = _Get(
        Token  => S->{Token},
        URL    => S->{API_URL} . '/system/config/'.$1,
        Limit  => 0,
#        Filter => '{"SysConfigOption":{"AND":[{"Field":"Name","Operator":"LIKE","Value":"' . $1 . '"}]}}',
   );
};

When qr/I get the attribute in config "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
       Token  => S->{Token},
       URL    => S->{API_URL} . '/system/config/'.$1,
       Limit  => 0,
#       Filter => '{"SysConfigOption":{"AND":[{"Field":"Name","Operator":"LIKE","Value":"' . $1 . '"}]}}',
   );
};

Then qr/the response contains the following (.*?) key "(.*?)"$/, sub {
    my $Object = $1;
    my $Index = 0;

    foreach my $Row ( @{ C->data } ) {
        foreach my $Attribute ( keys %{$Row}) {
            C->dispatch( 'Then', "the values attribute \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
        }
        $Index++
    }
};
Then qr/the values attribute "(.*?)" of the "(.*?)" item (\d+) is "(.*?)"$/, sub {
    is(S->{ResponseContent}->{SysConfigOption}->[0]->{$1}, $4, 'Check attribute value in response');
};
#==================================values==============================================================
Then qr/the response contains the following "(.*?)" Values/, sub {
    my $Object = "Values";
    my $Index = 0;

    foreach my $Row ( @{ C->data } ) {
        foreach my $Attribute ( keys %{$Row}) {
            C->dispatch( 'Then', "the values \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
        }
        $Index++
    }
};

Then qr/the values "(.*?)" of the "(.*?)" item (\d+) is "(.*?)"$/, sub {
    is(S->{ResponseContent}->{SysConfigOption}->{Value}->{$1}, $4, 'Check attribute value in response');
};

#================================
Then qr/the response contains the following config (.*?)$/, sub {
    my $Object = $1;
    my $Index = 0;

    foreach my $Row ( @{ C->data } ) {
        foreach my $Attribute ( keys %{$Row}) {
            C->dispatch( 'Then', "the values \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
        }
        $Index++
    }
};

Then qr/the values "(.*?)" of the "(.*?)" item (\d+) is "(.*?)"$/, sub {
    is(S->{ResponseContent}->{$2}->{$1}, $4, 'Check attribute value in response');
};
