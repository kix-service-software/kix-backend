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

Given qr/a organisation$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/organisations',
      Token   => S->{Token},
      Content => {
        Organisation => {
            Number => "K12345678_test".rand(),
            Name => "Test Organisation_cu".rand()
        }
      }
   );
};

Given qr/a organisation with Number "(.*?)"$/, sub {
    ( S->{Response}, S->{ResponseContent} ) = _Post(
        URL     => S->{API_URL}.'/organisations',
        Token   => S->{Token},
        Content => {
            Organisation => {
                Number => $1,
                Name => "Test Organisation_cu"
            }
        }
    );
};

Given qr/(\d+) of organisations$/, sub {
    my $Organisation;

    for ($i=0;$i<$1;$i++){
        if ( $i == 2 ) {
            $Organisation = 'K12345678_test_for_filter';
        }
        elsif ( $i == 3 ) {
            $Organisation = 'abc-ambulanz';
        }
        elsif ( $i == 4 ) {
            $Organisation = 'Fritz Meier KG';
        }
        else { 
            $Organisation = "K12345678".rand();        
        }

        ( S->{Response}, S->{ResponseContent} ) = _Post(
            URL     => S->{API_URL}.'/organisations',
            Token   => S->{Token},
            Content => {
                Organisation => {
                    Number => $Organisation,
                    Name => "Test Organisation ".rand()
                }
            }
        );
    }
};

When qr/added a organisation$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/organisations',
      Token   => S->{Token},
      Content => {
        Organisation => {
            Number => "K1234".rand(),
            Name => "Test Organisation ".rand()
        }
      }
   );
};

When qr/added a organisation without number$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/organisations',
      Token   => S->{Token},
      Content => {
        Organisation => {
            Number => "",
            Name => "Test Organisation ".rand()
        }
      }
   );
};



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
