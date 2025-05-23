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

Given qr/a article$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/tickets/'.S->{TicketID}.'/articles',
      Token   => S->{Token},
      Content => {
		Article => {
			Subject => "Auto-created article (Testcase KIX2018-T402) ",
			Body => "Test zum Inhalt The printer responsed with &lt;b&gt;Error 123&lt;/b&gt;.",
			ContentType => "text/html; charset=utf8",
			MimeType => "text/html",
			Charset => "utf8",
			ArticleTypeID => 1,
			SenderTypeID => 1, #		From => "root@localhost",
	#		To => "test1@example2.com, test2@example2.com, test3@example2.com, test4@example2.com, test5@example2.com, test6@example2.com, test7@example2.com, test8@example2.com, test9@example2.com, test10@example2.com, test11@example2.com, test12@example2.com, test13@example2.com, test14@example2.com",
	#		Cc => "test1@test.com, test2@test.com, test3@test.com, test4@test.com, test5@test.com, test6@test.com, test7@test.com, test8@test.com, test9@test.com, test10@test.com, test11@test.com, test12@test.com, test13@test.com, test14@test.com, test15@test.com, test16@test.com",
	#		Bcc => "secret@testtest.com, secret2@testtest.com, secret3@testtest.com, secret4@testtest.com, secret5@testtest.com, secret6@testtest.com, secret7@testtest.com, secret8@testtest.com, secret9@testtest.com, secret10@testtest.com, secret11@testtest.com" 
		}
	  }
   );
};

Given qr/(\d+) of articles$/, sub {
    
    for ($i=0;$i<$1;$i++){    
       ( S->{Response}, S->{ResponseContent} ) = _Post(
          URL     => S->{API_URL}.'/tickets/'.S->{TicketID}.'/articles',
          Token   => S->{Token},
          Content => {
            Article => {
                Subject => "Auto-created article (Testcase KIX2018-T402)".rand(),
                Body => "Test zum  The printer responsed with &lt;b&gt;Error 123&lt;/b&gt;.".rand(),
                ContentType => "text/html; charset=utf8",
                MimeType => "text/html",
                Charset => "utf8",
                ArticleTypeID => 1,
                SenderTypeID => 1, #       From => "root@localhost",
        #       To => "test1@example2.com, test2@example2.com, test3@example2.com, test4@example2.com, test5@example2.com, test6@example2.com, test7@example2.com, test8@example2.com, test9@example2.com, test10@example2.com, test11@example2.com, test12@example2.com, test13@example2.com, test14@example2.com",
        #       Cc => "test1@test.com, test2@test.com, test3@test.com, test4@test.com, test5@test.com, test6@test.com, test7@test.com, test8@test.com, test9@test.com, test10@test.com, test11@test.com, test12@test.com, test13@test.com, test14@test.com, test15@test.com, test16@test.com",
        #       Bcc => "secret@testtest.com, secret2@testtest.com, secret3@testtest.com, secret4@testtest.com, secret5@testtest.com, secret6@testtest.com, secret7@testtest.com, secret8@testtest.com, secret9@testtest.com, secret10@testtest.com, secret11@testtest.com" 
            }
          }
       );
    }
};

When qr/I create a article$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/tickets/'.S->{TicketID}.'/articles',
      Token   => S->{Token},
      Content => {
		Article => {
			Subject => "Auto-created article (Testcase KIX2018-T402) ",
			Body => "Test zum Inhalt The printer responsed with &lt;b&gt;Error 123&lt;/b&gt;.",
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

When qr/I create a article with fail mimetype$/, sub {
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

When qr/I create a article with fail mimetype 2$/, sub {
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

When qr/I create a article with inline pic$/, sub {
	( S->{Response}, S->{ResponseContent} ) = _Post(
		URL     => S->{API_URL}.'/tickets/'.S->{TicketID}.'/articles',
		Token   => S->{Token},
		Content => {
			Article =>{
                Subject =>"Test mit Inlineimage 2.api",
                Body =>"<img src=\"cid:inline908365.782562451.1717154478.5897968.14714663@kixdesk.com>\"/>",
                ContentType =>"text/html; charset=utf8",
                MimeType =>"text/html",
                Charset =>"utf8",
                ChannelID =>2,
                SenderTypeID =>2,
				     Attachments => [
					     {
						 ContentType => "image/png; name=\"grafik.png\"",
						 ContentID => "<inline908365.782562451.1717154478.5897968.14714663@kixdesk.com>",
						 Disposition => "inline",
						 Filename => "grafik.png",
						 Filesize => "79 Bytes",
                         FilesizeRaw => 79,
						 Content => "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jd+ewhJL964G37//MbtzynBjUlGQxTert+JM6kislzOaxTvJ/KEFXTuH10YLfu3pmuxg25YjF1dz1GHYbFgcpZSZQXRIjefI5x+xO8+JWXGW796ZybzN+RcfYIsnteN5vvook7PlJq68nSz56xusO3NxNzCI6NyNyJ2fsOpQMW6zjBNfvMXMFfso8+xahxGSQvf2R1mz6iBFbpOi/at475MjOIISvIxrUnT6MFnnyjA9Tygi8gumAERERERERERERHxV4ytB8CN+5BTGf7SU5S8+xKuFFViCm9Ku+zXcdWMXggw34Ob8ly9xz1e1VRSWpldyx9WnOdC8K2Mi6lZXBJDYNYnSJZs5fGO7Ou21jPAIwvK/YfcJFyP7TGRS7kIWP/cgb7kCie46gtuHxWKhpM4RgXQeeyfn3l3IzEcWUObXjJShkxif5AceK1NZWl7JpPFFLHhnBg8UuAmJ683NE64gyoDci7vWMiLpf1s6efMW8MwDBbjD2nPFbRPpFBAIlxoXB3vef4nlUffx9E0JqgwREZ+hShAREREREREREfFVRl5engng51e984WIiIiIiIiIiIiIiMg/VkVFhWfTRZYtW0Z6erpnMxkZGfW2N4SXxatEREQqK0FERERERERERER8kUIQERHxSkthiYiIiIiIiIiIr1IIIiIiXqkSREREREREREREfJVCEBER8UqVICIiIiIiIiIi4qsUgoiIiFeqBBEREREREREREV+lEERERLxSJYiIiIiIiIiIiPgqhSAiIuKVKkFERERERERERMRXKQQRERGvVAkiIiIiIiIiIiK+SiGIiIh4pUoQERERERERERHxVQpBRETEK1WCiIiIiIiIiIiIr7JVvwgMDKzbLiIiAkB2djbR0dGezSIiIiIiIiIiIo1SUVHh2fRPp0oQERHxSgGIiIiIiIiIiIj4KoUgIiLiVXZ2tmeTiIiIiIiIiIiIT6hZDktERKQ+jakEKf9+Fne/kcPwx59gdNvqR4yLH+Y/zAL7vTxxQ6ufL313buKVu19hUwWAG7cbDIsFA7BED+fxp8fQ1upxzKWYJexYtoCc3ulc1bqhB4mIiIiIiIiIyP81hSAiIuJVo/cEMU+yat4qej98Ha1+zrzA7cRp2LAZVT/benH3GxkAmGdW8vRTWQyfdRc9LuvJV8GFI/s42dGzXUREREREREREfskuaypIRET+dTQqAAFsKUMZXPop89f25HdXNf9R5Yfz3FaWvb2Y9YdyMaOSuWp8OtenhOHeP5+HlzXnwYeGEmWA68BCHl3SlAceGkoUJRxZPY93PttBdmkgsb1Hkz6uPzGWXcz+/RpajW3ChsVn+PfHpnFVZHUK4o2bgr0fMWfhWvblVGBvfwU3pf+Kbo5Pefa/j3L143fTJ9zB/vnTmWv9DROClrD8hwuUn/4job99mBuTfs50R0RERERERERELpfn3JSIiMhFGr0niC2WYRMGUvjBQtbnmhe/5zrBypfncKzzb3n25Vk8OaYJG157h42FHv0uYlK8ZS5/XRvA9Y/8hZefn0qPs+/yykdZuAAqdrFmZxsmPfNfDQxAwDz/FW+8tp2Y8U/x15efJb3dPjL+/iXnY65mfN8zLHt/NwVZn7JwVzLjbkgi5YYpjEqK5N8mKQAREREREREREfElCkFERMSrxlaCgIFfu+FM6HOaZe9mUlAn33CfyiSzuCfXD2lLsNVGZLfhDGqxj+2HXLWdfsTBng07iR4yiu6RNqzBbRhybSpFu3aR4wYskfQY2p/Y4IY+0kzytm3kaPJ1jOgQhtVqp8PwoSRk7WBfkY32w8fRdf8c/vjqd8SMvZFOwQ0LVkRERERERERE5JdHy2GJiIhXjd4TBMAIJGnUOLo8MZelOzvQr6rZnZ9LXv5WZj+xh9p6igiS3c6an2qZmABmMXn5Do58+ByPfl4bSIQ2jabCBIwmRDZpaAAC4KYgLx/HroVMf2RpbXPTOCwVgL0Dg/oG8cXaRG7rakcRiIiIiIiIiIiI71IIIiIiXjU6AKliBHfhVzcn8NTCFUQlmmAHI9SOvdkAJs8YQ1srQDm5x0/hbBYAWVATfADu4iJKaAZGECEhASQPfpx7+wYDYBaf5kheMDHWY4CB0aikwkJIaAihPX/NjPTOlQ9CVwGnskoIjzAwCzL58FsLHZps5YOvhpFUz74mIiIiIiIiIiLiGzSvIyIiXjV6T5AaBmE9b+LGlhv56Lt83IA1tjtd3etZ8fVxSt1uivavYOaLKznqAoIC8TtzkEMFJpSfYu3qbZSYAEGk9Ejk8Ccr2JHrxCw/wzcZL/D2pryLh2swg8iuqURu/5CVB4pwmWUcW/Uaf16ym1KzmJ1LlnC2/yTunzQEx8fvsiGvKpYxnTid3vYuERERERERERGRXxqFICIi4tXlVoIAYETSb9woEqxVy13ZEhg9dQwRG2bx4NSpPDb3JN0nj6dniIE1diAjU8+x6NEp3DXlOTIjUoixABhE9Evnzp7nWDzjPqZMe56vg0dxx3VxdZbUahxL9NXcdVs8B2Y/xj1Tfs/fdrZmYvogQn9YzsJDqYy7pjX+rYYwrk82y5Zup5hgWrULY8sbT/Hefm/7l4iIiIiIiIiIyC+JkZdX+RVXu93u+Z6IiMjl7Qnyv2E6KXNAQKBN+3GIiIiIiIiIiPw/UlhY6Nl0kWXLlpGenu7ZTEZGRr3tDfE/NGrbAAh9haUAAAAASUVORK5CYII="
					}
				]
            }
        }
	);
};

When qr/I get the article with attachments\s*$/, sub {
	( S->{Response}, S->{ResponseContent} ) = _Get(
		Token => S->{Token},
		URL   => S->{API_URL}.'/tickets/'.S->{TicketID}.'/articles/'.S->{ResponseContent}->{ArticleID}.'?include=Attachments',
	);
};



