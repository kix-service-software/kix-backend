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

Given qr/a ticket queue$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/queues',
      Token   => S->{Token},
      Content => {
        Queue => {
            Comment => "Postmaster queue.",
            FollowUpID => 1,
            FollowUpLock => 0,
            Name => "Postmaster".rand(),
            ParentID => 1,
            RealName => "KIX System",
            SystemAddressID => 1,
            UnlockTimeout => 0,
            ValidID => 1
        }
      }
   );
};

When qr/added a ticket queue$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/ticket/queues',
      Token   => S->{Token},
      Content => {
        Queue => {
            Comment => "Postmaster queue.".rand(),
            FollowUpID => 1,
            FollowUpLock => 0,
            Name => "Postmaster".rand(),
            ParentID => 1,
            RealName => "KIX System",
            SystemAddressID => 1,
            UnlockTimeout => 0,
            ValidID => 1
        }
      }
   );
};