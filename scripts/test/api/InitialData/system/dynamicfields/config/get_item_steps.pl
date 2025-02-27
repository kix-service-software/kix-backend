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
       URL   => S->{API_URL} . '/system/dynamicfields/' . S->{ResponseContent}->{DynamicField}->[0]->{ID} . '/config',
       Limit => 0,
   );
};

Then qr/the response contains the following attributes of (.*?)$/, sub {
    my $Object = $1;
    my $Index = 0;

    foreach my $Row ( sort @{ C->data } ) {
        foreach my $Attribute ( keys %{$Row}) {
            C->dispatch( 'Then', "the test attribute \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
        }
        $Index++
    }
};

Then qr/the test attribute "(.*?)" of the "(.*?)" item (\d+) is "(.*?)"$/, sub {
  is(S->{ResponseContent}->{$2}->[$3]->{$1}, $4, 'Check attribute value in response');
};

Then qr/the response contains the following PossibleValues/, sub {
    my $Object = "PossibleValues";
    my $Index = 0;

    foreach my $Row ( sort @{ C->data } ) {
        foreach my $Attribute ( keys %{$Row}) {
            C->dispatch( 'Then', "the PossibleValues \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
        }
        $Index++
    };
};

Then qr/the PossibleValues "(.*?)" of the "(.*?)" item (\d+) is "(.*?)"$/, sub {
    is(S->{ResponseContent}->{DynamicFieldConfig}->{$2}->{$1}, $4, 'Check attribute value in response');
};

Then qr/the response contains the following DefaultValue$/, sub {
    my $Object = "DefaultValue";
    my $Index = 0;

    foreach my $Row ( @{ C->data } ) {
        foreach my $Attribute ( keys %{$Row}) {
            C->dispatch( 'Then', "the DefValue \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
        }
        $Index++
    }
};

Then qr/the DefValue "(.*?)" of the "(.*?)" item (\d+) is "(.*?)"$/, sub {
    is(S->{ResponseContent}->{$2}->[$3]->{$1}, $4, 'Check attribute value in response');
};

# no arrayhash
Then qr/the response contains the following Config$/, sub {
    my $Object = "Config";
    my $Index = 0;

    foreach my $Row ( sort @{ C->data } ) {
        foreach my $Attribute ( keys %{$Row}) {
            C->dispatch( 'Then', "the Config \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
        }
        $Index++
    };
};

Then qr/the Config "(.*?)" of the "(.*?)" item (\d+) is "(.*?)"$/, sub {
    is(S->{ResponseContent}->{DynamicFieldConfig}->{$1}, $4, 'Check attribute value in response');
};










=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
