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

Given qr/a textmodule$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/textmodules',
      Token   => S->{Token},
      Content => {
            TextModule => {
                Name => "textmodul_".rand(4), 
                Text => "this is a also a test", 
                Keywords => "", 
                Comment => "", 
                Subject => "testsubject", 
                Language => "en", 
                Category => "Testing", 
                AgentFrontend => 1, 
                CustomerFrontend => 0, 
                PublicFrontend => 0, 
                ValidID => 1
            } 
      } 
   );
};

When qr/added a textmodule$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/textmodules',
      Token   => S->{Token},
      Content => {
	    TextModule => {
	        Name => "textmodul_".rand(4), 
	        Text => "this is a also a test", 
	        Keywords => "", 
	        Comment => "", 
	        Subject => "testsubject", 
	        Language => "en", 
	        Category => "Testing", 
	        AgentFrontend => 1, 
	        CustomerFrontend => 0, 
	        PublicFrontend => 0, 
	        ValidID => 1
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
