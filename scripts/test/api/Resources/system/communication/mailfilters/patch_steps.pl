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

When qr/I update this mailfilter$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Patch(
      URL     => S->{API_URL}.'/system/communication/mailfilters/'.S->{MailFilterID},,
      Token   => S->{Token},
      Content => {
        MailFilter => {
            Comment => "...",
            Match => [
                {
                    Key => "From",
                    Value => "email\@example.com",
                    Not => 1
                },
                {
                    Key => "Subject",
                    Value => "TestUpdate"
                }
            ],
            Name => "new filter update".rand(),
            Set => [
                {
                    Key => "X-KIX-Queue",
                    Value => "Some::Queue"
                }
            ],
            StopAfterMatch => 1,
            ValidID => 1
        
        }
      }
   );
};


