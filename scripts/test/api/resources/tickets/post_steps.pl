use warnings;

use Cwd;
use lib cwd();
use lib cwd() . '/Kernel/cpan-lib';
use lib cwd() . '/plugins';
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

Given qr/a ticket$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/tickets',
      Token   => S->{Token},
      Content => {
        Ticket => {
            Title => "test ticket for unknown contact",
            ContactID => "test\@no-mail.com",
            OrganisationID => "test\@no-mail.com",
            StateID => 4,
            PriorityID => 3,
            QueueID => 1,
            TypeID => 2
        }
     }
   );
};

Given qr/a ticket for organisation test$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/tickets',
      Token   => S->{Token},
      Content => {
        Ticket => {
            Title => "test ticket for unknown contact",
            ContactID => "test\@no-mail.com",
            OrganisationID => "test\@no-mail.com",
            StateID => 4,
            PriorityID => 3,
            QueueID => 1,
            TypeID => 2
        }
     }
   );
};

Given qr/(\d+) of tickets$/, sub {
    my $Title;
    my $PriorityID;
    my $QueueID;

    for ($i=0;$i<$1;$i++){
        if ( $i == 2 ) {
            $Title = 'test ticket for filter';
            $PriorityID = 2;
            $QueueID = 3;
        }
        elsif ( $i == 3 ) { 
            $Title = 'test ticket for unknown contact';
            $PriorityID = 2;
            $QueueID = 2;
        }
        else { 
            $Title = 'test ticket for'.rand();
            $PriorityID = 3;
            $QueueID = 1;
        }

       ( S->{Response}, S->{ResponseContent} ) = _Post(
          URL     => S->{API_URL}.'/tickets',
          Token   => S->{Token},
          Content => {
            Ticket => {
                Title => $Title,
                ContactID => "test\@no-mail.com",
                OrganisationID => "test\@no-mail.com",
                StateID => 4,
                PriorityID => $PriorityID,
                QueueID => $QueueID,
                TypeID => 2
            }
          }
       );
    }
};

Given qr/a ticket with one article$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/tickets',
      Token   => S->{Token},
      Content => {
        Ticket => {
            Title => "test ticket for unknown contact",
            ContactID => "test\@no-mail.com",
            OrganisationID => "test\@no-mail.com",
            StateID => 4,
            PriorityID => 3,
            QueueID => 1,
            TypeID => 2,
            Articles => [
                {
                    Subject => "d  fsd fds ",
                    Body => "<p>sd fds sd</p>",
                    ContentType => "text/html; charset=utf8",
                    MimeType => "text/html",
                    Charset => "utf8",
                    ChannelID => 1,
                    SenderTypeID => 1,
                    From => "root\@nomail.org",
                    CustomerVisible => 0,
                    To => "contact222\@nomail.org"
                }
            ]
        }
     }
   );
};



Given qr/(\d+) of (\w+) with article$/, sub {
    for ($i=0;$i<$1;$i++){	
	   ( S->{Response}, S->{ResponseContent} ) = _Post(
	      URL     => S->{API_URL}.'/tickets',
	      Token   => S->{Token},
	      Content => {
            Ticket => {
                Title => "test ticket for unknown contact",
                ContactID => "test\@no-mail.com",
                OrganisationID => "test\@no-mail.com",
                StateID => 4,
                PriorityID => 3,
                QueueID => 1,
                TypeID => 2,
                Articles => [
                    {
                        Subject => "d  fsd fds ",
                        Body => "<p>sd fds sd</p>",
                        ContentType => "text/html; charset=utf8",
                        MimeType => "text/html",
                        Charset => "utf8",
                        ChannelID => 1,
                        SenderTypeID => 1,
                        From => "root\@nomailtest.org",
                        CustomerVisible => 0,
                        To => "contact222\@nomail.org"
                    }
                ]
            }
         }
	   );
   }
};

When qr/I create a ticket$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/tickets',
      Token   => S->{Token},
      Content => {
        Ticket => {
            Title => "test ticket for unknown contact",
            ContactID => "test\@no-mail.com",
            OrganisationID => "test\@no-mail.com",
            StateID => 4,
            PriorityID => 3,
            QueueID => 1,
            TypeID => 2
        }
      }
   );
};



