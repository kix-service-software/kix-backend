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
#require './_StepsLib.pl';

# feature specific steps 

########################################################################################################
# Permissions GET/SEARCH
########################################################################################################

#When qr/I query the collection of (\w+) (\w+)$/, sub {
#   ( S->{Response}, S->{ResponseContent} ) = _Get(
#      Token => S->{Token},
#      URL   => S->{API_URL}.'/'.$1.'/'.$2,
#   );
#};

When qr/I query the collection of (\w+) with roleid (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/roles/'.$2.'/'.$1,
   );
};

When qr/I query the collection of permissions with roleid (\d+) and filter target "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/roles/'.$1.'/permissions',
      Filter => '{"Permission": {"AND": [{"Field": "Target","Operator": "EQ","Value": "/system/cmdb/classes"}]}}',
   );
};

When qr/I query the collection of (\w+) with roleid (\d+) and a limit of (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/roles/'.$2.'/'.$1,
      Limit => $3,
   );
};

When qr/I query the collection of (\w+) with roleid (\d+) and a offset of (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token  => S->{Token},
      URL    => S->{API_URL}.'/system/roles/'.$2.'/'.$1,
      Offset => $3,
   );
};

When qr/I query the collection of (\w+) with roleid (\d+) and with a limit of (\d+) and an offset of (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token  => S->{Token},
      URL    => S->{API_URL}.'/system/roles/'.$2.'/'.$1,
      Limit  => $4,
      Offset => $4,
   );
};

When qr/I query the collection of (\w+) with roleid (\d+) and sorted by "(.*?)" and with a limit of (\d+) and an offset of (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token  => S->{Token},
      URL    => S->{API_URL}.'/system/roles/'.$2.'/'.$1,
      Sort   => $3,
      Limit  => $4,
      Offset => $5,
   );
};

When qr/I query the collection of (\w+) with roleid (\d+) and sorted by "(.*?)" and with a limit of (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token  => S->{Token},
      URL    => S->{API_URL}.'/system/roles/'.$2.'/'.$1,
      Sort   => $3,
      Limit  => $4,
   );
};

