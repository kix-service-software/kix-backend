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

Given qr/a faq article attachment$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/faq/articles/'.S->{FAQArticleID}.'/attachments',
      Token   => S->{Token},
      Content => {
        Attachment => {
            Content => "TestAttachment3", 
            ContentType => "text/xml", 
            Filename => "Queue.xml", 
            Inline => 1 
        } 
      }
   );
};

When qr/I create a faq article attachment$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/faq/articles/'.S->{FAQArticleID}.'/attachments',
      Token   => S->{Token},
      Content => {
        Attachment => {
            Content => "TestAttachment3", 
            ContentType => "text/xml", 
            Filename => "Queue.xml", 
            Inline => 1 
        } 
      }
   );
};
