#!perl

use strict;
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

use Kernel::System::ObjectManager;

$Kernel::OM = Kernel::System::ObjectManager->new();

# require our common library
require '_StepsLib.pl';

# feature specific steps 
Given qr/an empty request object/, sub {
   S->{AuthRequest} = {};
};

Given qr/I am an (.*?) user with login "(.*?)" and password "(.*?)"/, sub {
   S->{AuthRequest} = {
      UserType => ucfirst($1),
      UserLogin => $2, 
      Password => $3,
   };
};
 
When qr/I login$/, sub {
   my $ua = LWP::UserAgent->new();
   my $req = HTTP::Request->new('POST', S->{API_URL}.'/auth');
   $req->header('Content-Type' => 'application/json');
   $req->content(encode_json(S->{AuthRequest}));

   S->{Response} = $ua->request($req);
   S->{ResponseContent} = decode_json(S->{Response}->decoded_content);
};

Then qr/the response contains a valid token/, sub {
  isnt(S->{ResponseContent}->{Token}, '', 'Token exists');
};