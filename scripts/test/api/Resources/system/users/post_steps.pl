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

Given qr/a user$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/users',
      Token   => S->{Token},
      Content => {
        User => {
            UserLogin => "jdoe".rand(),
            UserPw => "secret1".rand(),
            IsAgent => 1,
            IsCustomer => 0,
            RoleIDs => [
                3,5,8
            ],
            ValidID => 1
        }
      }
   );
};

Given qr/(\d+) of users$/, sub {
    my $UserLogin;

    for ($i=0;$i<$1;$i++){
        if ( $i == 2 ) {
            $UserLogin = 'jdoe_test_for_filter';
        }
        elsif ( $i == 3 ) {
            $UserLogin = 'mmamu';
        }
        elsif ( $i == 4 ) {
            $UserLogin = 'fzander';
        }
        elsif ( $i == 5 ) {
            $UserLogin = 'mmamu';
        }
        else {
            $UserEmail = "john.doe1".rand()."\@example.com";
            $UserLogin = "jdoe".rand();
        }

        ( S->{Response}, S->{ResponseContent} ) = _Post(
            URL     => S->{API_URL}.'/system/users',
            Token   => S->{Token},
            Content => {
                User => {
                    UserLogin => $UserLogin,
                    UserPw => "secret1".rand(),
                    IsAgent => 1,
                    IsCustomer => 0,
                    RoleIDs => [
                        3,5,8
                    ],
                    ValidID => 1
                }
            }
         );
    }
};

When qr/added a user$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/users',
      Token   => S->{Token},
      Content => {
        User => {
            UserLogin => "jdoe".rand(),
            UserPw => "secret2".rand(),
            IsAgent => 1,
            IsCustomer => 0,
            RoleIDs => [
                3
            ],
            ValidID => 1
        }
      }
   );
};

When qr/added a user with roles$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/users',
      Token   => S->{Token},
      Content => {
        User => {
            UserLogin => "jdoe_roleid",
            UserPw => "secret2".rand(),
            IsAgent => 1,
            IsCustomer => 0,
            RoleIDs => [
                3,5,8
            ],
            ValidID => 1
        }
      }
   );
};



