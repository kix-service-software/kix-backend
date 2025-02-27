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

Given qr/a definition with classid (\d+)$/, sub {
my $random = int (rand 151) + 50;
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/cmdb/classes/'.$1.'/definitions',
      Token   => S->{Token},
      Content => {
	    "ConfigItemClassDefinition"=> {
	        "DefinitionString"=> "[ { 'Input' => { 'MaxLength' => $random, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'Vendor', 'Name' => 'Vendor', 'Searchable' => 1 }, { 'Input' => { 'MaxLength' => 50, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'Model', 'Name' => 'Model', 'Searchable' => 1 }, { 'Input' => { 'Type' => 'TextArea' }, 'Key' => 'Description', 'Name' => 'Description', 'Searchable' => 1 }, { 'Input' => { 'Class' => 'ITSM::ConfigItem::Computer::Type', 'Translation' => 1, 'Type' => 'GeneralCatalog' }, 'Key' => 'Type', 'Name' => 'Type', 'Searchable' => 1 }, { 'Input' => { 'Type' => 'Organisation' }, 'Key' => 'Owner', 'Name' => 'Assigned owner', 'Searchable' => 1 }, { 'Input' => { 'MaxLength' => 100, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'SerialNumber', 'Name' => 'Serial Number', 'Searchable' => 1 }, { 'Input' => { 'MaxLength' => 100, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'OperatingSystem', 'Name' => 'Operating System' }, { 'CountMax' => 16, 'Input' => { 'MaxLength' => 100, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'CPU', 'Name' => 'CPU' }, { 'CountMax' => 10, 'Input' => { 'MaxLength' => 100, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'Ram', 'Name' => 'Ram' }, { 'CountMax' => 10, 'Input' => { 'MaxLength' => 100, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'HardDisk', 'Name' => 'Hard Disk', 'Sub' => [ { 'Input' => { 'MaxLength' => 10, 'Size' => 20, 'Type' => 'Text' }, 'Key' => 'Capacity', 'Name' => 'Capacity' } ] }, { 'Input' => { 'MaxLength' => 100, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'FQDN', 'Name' => 'FQDN', 'Searchable' => 1 }, { 'CountDefault' => 1, 'CountMax' => 10, 'CountMin' => 0, 'Input' => { 'MaxLength' => 100, 'Required' => 1, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'NIC', 'Name' => 'Network Adapter', 'Sub' => [ { 'Input' => { 'Class' => 'ITSM::ConfigItem::YesNo', 'Required' => 1, 'Translation' => 1, 'Type' => 'GeneralCatalog' }, 'Key' => 'IPoverDHCP', 'Name' => 'IP over DHCP' }, { 'CountDefault' => 0, 'CountMax' => 20, 'CountMin' => 0, 'Input' => { 'MaxLength' => 40, 'Required' => 1, 'Size' => 40, 'Type' => 'Text' }, 'Key' => 'IPAddress', 'Name' => 'IP Address', 'Searchable' => 1 } ] }, { 'Input' => { 'MaxLength' => 100, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'GraphicAdapter', 'Name' => 'Graphic Adapter' }, { 'CountDefault' => 0, 'CountMin' => 0, 'Input' => { 'Required' => 1, 'Type' => 'TextArea' }, 'Key' => 'OtherEquipment', 'Name' => 'Other Equipment' }, { 'Input' => { 'Type' => 'Date', 'YearPeriodFuture' => 10, 'YearPeriodPast' => 20 }, 'Key' => 'WarrantyExpirationDate', 'Name' => 'Warranty Expiration Date', 'Searchable' => 1 }, { 'CountDefault' => 0, 'CountMin' => 0, 'Input' => { 'Required' => 1, 'Type' => 'Date', 'YearPeriodFuture' => 10, 'YearPeriodPast' => 20 }, 'Key' => 'InstallDate', 'Name' => 'Install Date', 'Searchable' => 1 }, { 'CountDefault' => 0, 'CountMin' => 0, 'Input' => { 'Required' => 1, 'Type' => 'TextArea' }, 'Key' => 'Note', 'Name' => 'Note', 'Searchable' => 1}  ];"
	    }
	  }
   );
};

When qr/I create a definition with classid (\d+)$/, sub {
	my $random = int (rand 151) + 50;
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/cmdb/classes/'.$1.'/definitions',
      Token   => S->{Token},
      Content => {
	    "ConfigItemClassDefinition"=> {
	        "DefinitionString"=> "[ { 'Input' => { 'MaxLength' => $random, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'Vendor', 'Name' => 'Vendor', 'Searchable' => 1 }, { 'Input' => { 'MaxLength' => 50, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'Model', 'Name' => 'Model', 'Searchable' => 1 }, { 'Input' => { 'Type' => 'TextArea' }, 'Key' => 'Description', 'Name' => 'Description', 'Searchable' => 1 }, { 'Input' => { 'Class' => 'ITSM::ConfigItem::Computer::Type', 'Translation' => 1, 'Type' => 'GeneralCatalog' }, 'Key' => 'Type', 'Name' => 'Type', 'Searchable' => 1 }, { 'Input' => { 'Type' => 'Organisation' }, 'Key' => 'Owner', 'Name' => 'Assigned owner', 'Searchable' => 1 }, { 'Input' => { 'MaxLength' => 100, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'SerialNumber', 'Name' => 'Serial Number', 'Searchable' => 1 }, { 'Input' => { 'MaxLength' => 100, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'OperatingSystem', 'Name' => 'Operating System' }, { 'CountMax' => 16, 'Input' => { 'MaxLength' => 100, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'CPU', 'Name' => 'CPU' }, { 'CountMax' => 10, 'Input' => { 'MaxLength' => 100, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'Ram', 'Name' => 'Ram' }, { 'CountMax' => 10, 'Input' => { 'MaxLength' => 100, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'HardDisk', 'Name' => 'Hard Disk', 'Sub' => [ { 'Input' => { 'MaxLength' => 10, 'Size' => 20, 'Type' => 'Text' }, 'Key' => 'Capacity', 'Name' => 'Capacity' } ] }, { 'Input' => { 'MaxLength' => 100, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'FQDN', 'Name' => 'FQDN', 'Searchable' => 1 }, { 'CountDefault' => 1, 'CountMax' => 10, 'CountMin' => 0, 'Input' => { 'MaxLength' => 100, 'Required' => 1, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'NIC', 'Name' => 'Network Adapter', 'Sub' => [ { 'Input' => { 'Class' => 'ITSM::ConfigItem::YesNo', 'Required' => 1, 'Translation' => 1, 'Type' => 'GeneralCatalog' }, 'Key' => 'IPoverDHCP', 'Name' => 'IP over DHCP' }, { 'CountDefault' => 0, 'CountMax' => 20, 'CountMin' => 0, 'Input' => { 'MaxLength' => 40, 'Required' => 1, 'Size' => 40, 'Type' => 'Text' }, 'Key' => 'IPAddress', 'Name' => 'IP Address', 'Searchable' => 1 } ] }, { 'Input' => { 'MaxLength' => 100, 'Size' => 50, 'Type' => 'Text' }, 'Key' => 'GraphicAdapter', 'Name' => 'Graphic Adapter' }, { 'CountDefault' => 0, 'CountMin' => 0, 'Input' => { 'Required' => 1, 'Type' => 'TextArea' }, 'Key' => 'OtherEquipment', 'Name' => 'Other Equipment' }, { 'Input' => { 'Type' => 'Date', 'YearPeriodFuture' => 10, 'YearPeriodPast' => 20 }, 'Key' => 'WarrantyExpirationDate', 'Name' => 'Warranty Expiration Date', 'Searchable' => 1 }, { 'CountDefault' => 0, 'CountMin' => 0, 'Input' => { 'Required' => 1, 'Type' => 'Date', 'YearPeriodFuture' => 10, 'YearPeriodPast' => 20 }, 'Key' => 'InstallDate', 'Name' => 'Install Date', 'Searchable' => 1 }, { 'CountDefault' => 0, 'CountMin' => 0, 'Input' => { 'Required' => 1, 'Type' => 'TextArea' }, 'Key' => 'Note', 'Name' => 'Note', 'Searchable' => 1}  ];"
	    }
	  }
   );
};

