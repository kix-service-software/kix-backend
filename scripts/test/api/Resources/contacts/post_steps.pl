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

Given qr/a contact$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/contacts',
      Token   => S->{Token},
      Content => {
         Contact => {
            Email => "mamu".rand(2)."\@example.org",
            Firstname => "Max",
            Lastname => "Mustermann",
            Login => "mamu".rand(2),
            OrganisationIDs => [
                  S->{OrganisationID}
            ],
            PrimaryOrganisationID => S->{OrganisationID}
         }
      }
   );
};

Given qr/(\d+) of contact$/, sub {
    my $Email;
    my $Login;
    my $Firstname;
    my $Lastname;
    
    for ($i=0;$i<$1;$i++){
        if ( $i == 2 ) {
            $Email = "mamu_test_filter\@example.org";
            $Login = "mamu_test_filter";
            $Firstname = "Max";
            $Lastname  = "Mustermann"
        }
        elsif ( $i == 3 ) {
            $Email = "tmeier_test_filter\@example.org";
            $Login = "tmeier";
            $Firstname = "Tom";
            $Lastname  = "Meier"
        }
        elsif ( $i == 4 ) {
            $Email = "maxi.mustermann\@example.org";
            $Login = "mamuster";
            $Firstname = "Maxi";
            $Lastname  = "Mustermann"
        }
        else { 
            $Email = "mamu".rand(2)."\@example.org";
            $Login = "mamu".rand(2);
            $Firstname = "Max";
            $Lastname  = "Mustermann";     
        }
       ( S->{Response}, S->{ResponseContent} ) = _Post(
          URL     => S->{API_URL}.'/contacts',
          Token   => S->{Token},
              Content => {
                 Contact => {
                    Email => $Email,
                    Firstname => $Firstname,
                    Lastname => $Lastname,
                    Login => $Login,
                    OrganisationIDs => [
                          S->{OrganisationID}
                    ],
                    PrimaryOrganisationID => S->{OrganisationID}
                 }
              }
        );
    }
};

Given qr/(\d+) of contact with diffrent organisation$/, sub {
    my $Email;
    my $Login;
    my $Firstname;
    my $Lastname;
    my $Organisation;
        
    for ($i=0;$i<$1;$i++){
        if ( $i == 2 ) {
            $Email = "max.mustermann\@example.org";
            $Login = "mamuster";
            $Firstname = "Max";
            $Lastname  = "Mustermann";
            $Organisation = S->{OrganisationIDArray}->[3];
        }
        elsif ( $i == 3 ) {
            $Email = "tmeier_test_filter\@example.org";
            $Login = "tmeier";
            $Firstname = "Tom";
            $Lastname  = "Meier";
            $Organisation = S->{OrganisationIDArray}->[3];
        }
        else { 
            $Email = "maxmu".rand(2)."\@example.org";
            $Login = "maxmu".rand(2);
            $Firstname = "Maximilian";
            $Lastname  = "Mustermann";
            $Organisation  = S->{OrganisationIDArray}->[0];    
        }
        ( S->{Response}, S->{ResponseContent} ) = _Post(
            URL     => S->{API_URL}.'/contacts',
            Token   => S->{Token},
            Content => {
                 Contact => {
                    Email => $Email,
                    Firstname => $Firstname,
                    Lastname => $Lastname,
                    Login => $Login,
                    OrganisationIDs => [
                          $Organisation
                    ],
                    PrimaryOrganisationID => $Organisation
                 }
              }
        );
    }
};


When qr/added a contact$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/contacts',
      Token   => S->{Token},
      Content => {
         Contact => {
            Email => "mamu\@example.org",
            Firstname => "Max",
            Lastname => "Mustermann",
            Login => "mamu",
            OrganisationIDs => [
                S->{OrganisationID}
            ],
            PrimaryOrganisationID => S->{OrganisationID}
         }
      }
   );
};

When qr/added a contact with a email that already exists$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/contacts',
      Token   => S->{Token},
      Content => {
         Contact => {
            Email => "mamu\@example.org",
            Firstname => "Max",
            Lastname => "Mustermann",
            Login => "mamu".rand(2),
            OrganisationIDs => [
                  S->{OrganisationID}
            ],
            PrimaryOrganisationID => S->{OrganisationID}
         }
      }
   );
};

When qr/added a contact with a login that already exists$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/contacts',
      Token   => S->{Token},
      Content => {
         Contact => {
            Email => "mamu".rand(2)."\@example.org",
            Firstname => "Max",
            Lastname => "Mustermann",
            Login => "mamu",
            OrganisationIDs => [
                  S->{OrganisationID}
            ],
            PrimaryOrganisationID => S->{OrganisationID}
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
