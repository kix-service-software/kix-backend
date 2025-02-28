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

When qr/I query the collection of faq articles\s*$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/faq/articles',
   );
};

When qr/I query the collection of faq articles (\d+) searchlimit\s*$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
       Token => S->{Token},
       URL   => S->{API_URL}.'/faq/articles?searchlimit='.$1,
   );
};

When qr/I query the collection of faq articles (\d+) searchlimit object\s*$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
       Token => S->{Token},
       URL   => S->{API_URL}.'/faq/articles?searchlimit=FAQArticle:'.$1,
   );
};

When qr/I query the collection of faq articles with filter of "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/faq/articles',
      Filter => '{"FAQArticle": {"AND": [{"Field": "Title","Operator": "STARTSWITH","Value": "'.$1.'"}]}}',
   );
};

When qr/I query the collection of faq articles with limit (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/faq/articles',
      Limit => $1,
   );
};

When qr/I query the collection of faq articles with sorted by "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/faq/articles',
      Sort => $1,
   );
};

When qr/I query the collection of faq articles with offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/faq/articles',
      Offset => $1,
   );
};

When qr/I query the collection of faq articles with limit (\d+) and offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token  => S->{Token},
      URL    => S->{API_URL}.'/faq/articles',
      Limit  => $1,
      Offset => $2,
   );
};

When qr/I query the collection of faq articles with sorted by "(.*?)" limit (\d+) and offset (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/faq/articles',
      Limit  => $2,
      Offset => $3,
      Sort => $1,
   );
};