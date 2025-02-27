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

Given qr/a ticket$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/tickets',
      Token   => S->{Token},
      Content => {
        Ticket => {
            Title => "test ticket for unknown contact",
            ContactID => 1,
            OrganisationID => 1,
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
            ContactID => 1,
            OrganisationID => 1,
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
            $Title = 'test ticket given for unknown contact';
            $PriorityID = 2;
            $QueueID = 2;
        }
        elsif ( $i>8 && $i<10 ) {
            $Title = 'test ticket given for multible sort';
            $PriorityID = 3;
            $QueueID = 3;
        }
        elsif ( $i>10 && $i<12 ) {
            $Title = 'test ticket given for multible sort';
            $PriorityID = 1;
            $QueueID = 1;
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
                ContactID => 1,
                OrganisationID => 1,
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
            ContactID => 1,
            OrganisationID => 1,
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
                    From => 'root@nomail.org',
                    CustomerVisible => 0,
                    To => 'contact222@nomail.org'
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
                ContactID => 1,
                OrganisationID => 1,
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
                        From => 'root@nomailtest.org',
                        CustomerVisible => 0,
                        To => 'contact222@nomail.org'
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
            ContactID => 1,
            OrganisationID => 1,
            StateID => 4,
            PriorityID => 3,
            QueueID => 1,
            TypeID => 2
        }
      }
   );
};

When qr/I create a complete ticket$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/tickets',
      Token   => S->{Token},
      Content => {
            Ticket => {
                Articles => [
                    {
                        Attachment => [
                            {
                                Content => "base64encodedContentString",
                                ContentType => "image/png",
                                Filename => "printer-error.png"
                            }
                        ],
                        Body => "The printer responsed with &lt;b&gt;Error 123&lt;/b&gt;.",
                        ChannelID => 2,
                        Charset => "utf8",
                        ContentType => "text/html; charset=utf8",
                        CustomerVisible => 1,
                        ForceNotificationToUserID => [
                            3
                        ],
                        From => "someone@somecorp.com",
                        MimeType => "text/html",
                        SenderTypeID => 3,
                        Subject => "The printer does not work!",
                        TimeUnits => 12345,
                        To => "someoneelse@somecorp.com,'another one' &lt;anotherone@anothercorp.com&gt;"
                    }
                ],
                ContactID => 2,
                DynamicField => [
                    {
                        Name => "RelevantAssets",
                        Value => [
                            3,
                            156
                        ]
                    },
                    {
                        Name => "DueDate",
                        Value => [
                            "2020-05-02 12:00:00"
                        ]
                    }
                ],
                LockID => 1,
                OrganisationID => 2,
                OwnerID => 4,
                PriorityID => 1,
                QueueID => 13,
                ResponsibleID => 4,
                ServiceID => 2,
                StateID => 3,
                Title => "The printer does not work!",
                TypeID => 6
            }
      }
   );
};

When qr/I create a ticket placeholder$/, sub {
    ( S->{Response}, S->{ResponseContent} ) = _Post(
        URL     => S->{API_URL}.'/tickets',
        Token   => S->{Token},
        Content => {
            Ticket => {
                Title => "test KIX_CONFIG_DefaultUsedLanguages: <KIX_CONFIG_DefaultUsedLanguages> ticket for unknown contact",
                ContactID => 1,
                OrganisationID => 1,
                StateID => 4,
                PriorityID => 3,
                QueueID => 1,
                TypeID => 2,
                Articles => [
                    {
                        Subject => "d  fsd fds ",
                        Body => "Calendar: <KIX_TICKET_SLACriteria_FirstResponse_Calendar>, BusinessTimeDeviaton: <KIX_TICKET_SLACriteria_FirstResponse_BusinessTimeDeviaton>, TargetTime: <KIX_TICKET_SLACriteria_FirstResponse_TargetTime>, KIX_CONFIG_Ticket::Hook: <KIX_CONFIG_Ticket::Hook>,KIX_CONFIG_PGP::Key::Password: <KIX_CONFIG_PGP::Key::Password>,KIX_CONFIG_ContactSearch::UseWildcardPrefix: <KIX_CONFIG_ContactSearch::UseWildcardPrefix>",
                        ContentType => "text/html; charset=utf8",
                        MimeType => "text/html",
                        Charset => "utf8",
                        ChannelID => 1,
                        SenderTypeID => 1,
                        From => 'root@nomail.org',
                        CustomerVisible => 0,
                        To => 'contact222@nomail.org'
                    }
                ]
            }
        }
    );
};

Then qr/the response contains the following article placeholder$/, sub {
    my $Object = $1;
    my $Index = 0;

    foreach my $Row ( sort keys %{S->{ResponseContent}->{Ticket}->{Articles}->[0]} ) {
        foreach my $Attribute ( keys %{$Row}) {
            C->dispatch( 'Then', "the placeholder \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
        }
        $Index++
    }
};

Then qr/the placeholder "(.*?)" of the "(.*?)" item (\d+) is "(.*?)"$/, sub {
    if ( defined( S->{ResponseContent}->{$2}->[$3]->{$1}) ) {
#        S->{ResponseContent}->{$2}->[$3]->{$1} =~ s/<.+?>/ /g;
        is(S->{ResponseContent}->{$2}->[$3]->{$1}, $4, 'Check attribute value in response');
    }
    else{
        is('', $4, 'Check attribute value in response');
    }
};

When qr/added a user with no organisation$/, sub {
	( S->{Response}, S->{ResponseContent} ) = _Post(
		URL     => S->{API_URL}.'/system/users',
		Token   => S->{Token},
		Content => {
			User => {
				UserEmail => "lili@lulu.de",
				UserFirstname => "li",
				UserLastname => "li",
				UserLogin => "lili",
				UserPw => "secret2".rand(),
				UserTitle => "DR.",
				IsAgent => 0,
				IsCustomer => 1,
				ValidID => 1
			}
		}
	);
};

When qr/I create a complete ticket no organisation$/, sub {
    ( S->{Response}, S->{ResponseContent} ) = _Post(
        URL     => S->{API_URL}.'/tickets',
        Token   => S->{Token},
        Content => {
            Ticket => {
                Title => "test none orga",
		        ContactID => "lili\@lulu.de",
                OrganisationID => '',
		        OwnerID => 1,
		        QueueID => 1,
		        Articles => [
			        {
				        Subject => "test one orga",
				        to => "recipient1@example.com",
				        Cc => "test\@byom.de",
				        Body => "test one orgatest none orga",
				        ContentType => "text/plain; charset=utf8",
				        MimeType => "text/plain",
				        Charset => "utf8",
				        SenderType => "external",
				        Channel => "note"
			        }
		        ]
            }
        }
    );
};
