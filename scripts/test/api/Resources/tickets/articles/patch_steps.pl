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

When qr/I update this article$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Patch(
      URL     => S->{API_URL}.'/tickets/'.S->{TicketID}.'/articles/'.S->{ResponseContent}->{ArticleID},
      Token   => S->{Token},
      Content => {
		Article => {
			Subject => "Auto-created article update (Testcase KIX2018-T402) ",
			Body => "Test zum Inhalt Update",
			ContentType => "text/html; charset=utf8",
			MimeType => "text/html",
			Charset => "utf8",
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

When qr/I update this article with fail mimetype$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/tickets/'.S->{TicketID}.'/articles',
      Token   => S->{Token},
      Content => {
		Article => {
		    TimeUnit => 12,
#            To => "someone@cape-it.de",
            Subject => "A Channel 2 article",
			Body => "<p>I think I know exactly what you mean. Yeah. Lorraine. George, buddy. remember that girl I introduced you to, Lorraine. What are you writing? Oh, I sure like her, Marty, she is such a sweet girl. Isn't tonight the night of the big date?</p><p>Hey I'm talking to you, McFly, you Irish bug. Quiet. Of course I do. Just a second, let's see if I could find it. That's right. Biff, stop it. Biff, you're breaking his arm. Biff, stop.</p><p>It's <b>about the future</b>, isn't it? Hello, Jennifer. Biff, stop it. Biff, you're breaking his arm. Biff, stop. Just say anything, George, say what ever's natural, the first thing that comes to your mind. Yeah Mom, we know, you've told us this story a million times. You felt sorry for him so you decided to go with him to The Fish Under The Sea Dance.</p>",
			ContentType => "html/text; charset=utf8",
            MimeType => "html/text",
            Charset => "utf8",
            ChannelID => 1,
            SenderTypeID => 1,
            CustomerVisible => 1
        }
	  }
   );
};

When qr/I update this article with fail mimetype 2$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/tickets/'.S->{TicketID}.'/articles',
      Token   => S->{Token},
      Content => {
		Article => {
		    TimeUnit => 12,
#            To => "someone@cape-it.de",
            Subject => "Some Sample Subject",
			Body => "<!doctype html>\r\n<meta charset=\"utf8\">\r\n<html>\r\n<body>\r\n<h1>Headline<\/h1\/>\r\n<pr>Lorem ipsum dolor sit amet<\/p>\r\n<\/body>\r\n<\/html>\r\n",
			ContentType => "html/text; charset=utf8",
            MimeType => "html/text",
            Charset => "utf8",
            Attachment => {
                  Content => "VGhpcyBpcyBqdXN0IGEgdGVzdC4=",
                  ContentType => "text/pain; charset=utf8",
                  Filename => "test.txt"
            },
            ChannelID => 1,
            SenderTypeID => 1,
            CustomerVisible => 1
        }
	  }
   );
};





