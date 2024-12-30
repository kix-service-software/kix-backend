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

When qr/I query the collection of generalcatalog items$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/generalcatalog',
   );
};

Then qr/the response contains (\d+) items type GeneralCatalogItem of Class ITSM::ConfigItem::DeploymentState$/, sub {
    my @GeneralCatalogItem;

    foreach my $Row ( @{S->{ResponseContent}->{GeneralCatalogItem}} ) {
        if ($Row->{Class} eq "ITSM::ConfigItem::DeploymentState") {
            push (@GeneralCatalogItem, $Row->{Name});
        }
    } 
    is(@GeneralCatalogItem, $1, 'Check response item count');
    my $Anzahl = @GeneralCatalogItem;
};

Then qr/the response contains (\d+) items type GeneralCatalogItem of Class ITSM::Core::IncidentState$/, sub {
    my @GeneralCatalogItem;

    foreach my $Row ( @{S->{ResponseContent}->{GeneralCatalogItem}} ) {
        if ($Row->{Class} eq "ITSM::Core::IncidentState") {
            push (@GeneralCatalogItem, $Row->{Name});
        }
    }
 
    is(@GeneralCatalogItem, $1, 'Check response item count');
    my $Anzahl = @GeneralCatalogItem;
};

Then qr/the response contains the following items Class ITSM::ConfigItem::DeploymentState of type GeneralCatalogItem$/, sub {
    my $Object = "GeneralCatalogItem";
    my $Index = 0;
    my @GeneralCatalogItem;
    
    foreach my $Row ( @{S->{ResponseContent}->{GeneralCatalogItem}} ) {
        if ($Row->{Class} eq "ITSM::ConfigItem::DeploymentState") {
            push (@GeneralCatalogItem, $Row);
        }
    }
    
    S->{ResponseContent}->{GeneralCatalogItem} = \@GeneralCatalogItem;

    foreach my $Row ( @{ C->data } ) {
        foreach my $Attribute ( keys %{$Row}) {
            C->dispatch( 'Then', "the attribute \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
        }
        $Index++
    }
};

Then qr/the response contains the following items Class ITSM::Core::IncidentState of type GeneralCatalogItem$/, sub {
    my $Object = "GeneralCatalogItem";
    my $Index = 0;
    my @GeneralCatalogItem;
    
    foreach my $Row ( @{S->{ResponseContent}->{GeneralCatalogItem}} ) {
        if ($Row->{Class} eq "ITSM::Core::IncidentState") {
            push (@GeneralCatalogItem, $Row);
        }
    }

    S->{ResponseContent}->{GeneralCatalogItem} = \@GeneralCatalogItem;

    foreach my $Row ( @{ C->data } ) {
        foreach my $Attribute ( keys %{$Row}) {
            C->dispatch( 'Then', "the attribute \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
        }
        $Index++
    }
};

Then qr/the response contains (\d+) items type GeneralCatalogItem of Class (.*?)$/, sub {
    my @GeneralCatalogItem;

    foreach my $Row ( @{S->{ResponseContent}->{GeneralCatalogItem}} ) {
        if ($Row->{Class} eq $2) {
            push (@GeneralCatalogItem, $Row->{Name});
        }
    }

    is(@GeneralCatalogItem, $1, 'Check response item count');
    my $Anzahl = @GeneralCatalogItem;
};

Then qr/the response contains the following items Class (.*?) of type GeneralCatalogItem$/, sub {
    my $Object = "GeneralCatalogItem";
    my $Index = 0;
    my @GeneralCatalogItem;

    foreach my $Row ( @{S->{ResponseContent}->{GeneralCatalogItem}} ) {
        if ($Row->{Class} eq $1) {
            push (@GeneralCatalogItem, $Row);
        }
    }

    S->{ResponseContent}->{GeneralCatalogItem} = \@GeneralCatalogItem;

    foreach my $Row ( @{ C->data } ) {
        foreach my $Attribute ( keys %{$Row}) {
            C->dispatch( 'Then', "the attribute \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
        }
        $Index++
    }
};

When qr/I query the collection of generalcatalog items "(.*?)"$/, sub {
    ( S->{Response}, S->{ResponseContent} ) = _Get(
        Token  => S->{Token},
        URL    => S->{API_URL} . '/system/generalcatalog',
        Filter => '{  "GeneralCatalogItem":{ "AND":[  {"Field":"Class","Operator":"EQ","Type":"STRING","Value":"'.$1.'" }]}}',
        Sort   => 'GeneralCatalogItem.Name:textual'
    );
};

