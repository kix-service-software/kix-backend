use warnings;

use Cwd;
use lib cwd();
use lib cwd() . '/Kernel/cpan-lib';
use lib cwd() . '/Custom';
use lib cwd() . '/scripts/test/api/Cucumber';

use LWP::UserAgent;
use HTTP::Request;
use JSON::XS qw(encode_json decode_json);
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

When qr/I update this article$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Patch(
      URL     => S->{API_URL}.'/tickets/'.S->{TicketID}.'/articles/'.S->{ResponseContent}->{ArticleID},
      Token   => S->{Token},
      Content => {
		Article => {
			Subject => "Auto-created article update (Testcase KIX2018-T402) ",
			Body => "Test zum Inhalt Update",
			ContentType => "text/html; charset=utf-8",
			ArticleTypeID => 1,
			SenderTypeID => 1,
	#		From => "root@localhost",
	#		To => "test1@example2.com, test2@example2.com, test3@example2.com, test4@example2.com, test5@example2.com, test6@example2.com, test7@example2.com, test8@example2.com, test9@example2.com, test10@example2.com, test11@example2.com, test12@example2.com, test13@example2.com, test14@example2.com",
	#		Cc => "test1@test.com, test2@test.com, test3@test.com, test4@test.com, test5@test.com, test6@test.com, test7@test.com, test8@test.com, test9@test.com, test10@test.com, test11@test.com, test12@test.com, test13@test.com, test14@test.com, test15@test.com, test16@test.com",
	#		Bcc => "secret@testtest.com, secret2@testtest.com, secret3@testtest.com, secret4@testtest.com, secret5@testtest.com, secret6@testtest.com, secret7@testtest.com, secret8@testtest.com, secret9@testtest.com, secret10@testtest.com, secret11@testtest.com" 
		}
	  }
   );
};