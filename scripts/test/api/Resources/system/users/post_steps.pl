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
            UserEmail => "john.doe1".rand()."\@example.com",
            UserFirstname => "John",
            UserLastname => "Doe",
            UserLogin => "jdoe".rand(),
            UserPw => "secret1".rand(),
            UserTitle => "DR.",
            IsAgent => 1,
            IsCustomer => 0,
            ValidID => 1
        }
      }
   );
};

Given qr/(\d+) of users$/, sub {
    my $UserEmail;
    my $UserLogin;
    my $UserLastname;
    my $UserFirstname;

    for ($i=0;$i<$1;$i++){
        if ( $i == 2 ) {
            $UserEmail = 'test_for_filter.doe2@test.org';
            $UserLogin = 'jdoe_test_for_filter';
            $UserFirstname = 'John';
            $UserLastname = 'Doe';
        }
        elsif ( $i == 3 ) {
            $UserEmail = 'Max.Mustermann@test.org';
            $UserLogin = 'mmamu';
            $UserFirstname = 'Max';
            $UserLastname = 'Mustermann';
        }
        elsif ( $i == 4 ) {
            $UserEmail = 'Frank.Zander@test.org';
            $UserLogin = 'fzander';
            $UserFirstname = 'Frank';
            $UserLastname = 'Zander';
        }
        elsif ( $i == 5 ) {
            $UserEmail = 'Max.Müller@test.org';
            $UserLogin = 'mmamu';
            $UserFirstname = 'Max';
            $UserLastname = 'Müller';
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
                    UserEmail => $UserEmail,
                    UserFirstname => $UserFirstname,
                    UserLastname => $UserLastname,
                    UserLogin => $UserLogin,
                    UserPw => "secret1".rand(),
                    UserTitle => "DR.",
                    IsAgent => 1,
                    IsCustomer => 0,
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
            UserEmail => "john.doe2".rand()."\@example.com",
            UserFirstname => "John",
            UserLastname => "Doe",
            UserLogin => "jdoe".rand(),
            UserPw => "secret2".rand(),
            UserTitle => "DR.",
            IsAgent => 1,
            IsCustomer => 0,
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



