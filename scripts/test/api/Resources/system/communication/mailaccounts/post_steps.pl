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

Given qr/a mailaccount$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/communication/mailaccounts',
      Token   => S->{Token},
      Content => {
        MailAccount => {
            Login => "mail".rand(), 
            Password => "SomePassword".rand(), 
            Host => "pop3.example.com", 
            Type => "POP3", 
            IMAPFolder => "Some Folder", 
            Trusted => 0, 
            DispatchingBy => "Queue", 
            QueueID => 2, 
            Comment => "Test MailAccount", 
            ValidID => 1 
        } 
      }
   );
};

Given qr/(\d+) of mailaccount$/, sub {
    my $Password;
    my $Login;
    
    for ($i=0;$i<$1;$i++){
        if ( $i == 2 ) {
            $Login    = 'filter.test';
            $Password = 'filter password';
        }
        else { 
            $Login    = "mail".rand();
            $Password = "SomePassword".rand();      
        }

        ( S->{Response}, S->{ResponseContent} ) = _Post(
            URL     => S->{API_URL}.'/system/communication/mailaccounts',
            Token   => S->{Token},
            Content => {
                MailAccount => {
                    Login => $Login, 
                    Password => $Password, 
                    Host => "pop3.example.com", 
                    Type => "POP3", 
                    IMAPFolder => "Some Folder", 
                    Trusted => 0, 
                    DispatchingBy => "Queue", 
                    QueueID => 2, 
                    Comment => "Test MailAccount", 
                    ValidID => 1 
                } 
            }
         );
    }
};

When qr/I create a mailaccount$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/system/communication/mailaccounts',
      Token   => S->{Token},
      Content => {
        MailAccount => {
            Login => "mail".rand(), 
            Password => "SomePassword".rand(), 
            Host => "pop3.example.com", 
            Type => "POP3", 
            IMAPFolder => "Some Folder", 
            Trusted => 0, 
            DispatchingBy => "Queue", 
            QueueID => 2, 
            Comment => "Test MailAccount", 
            ValidID => 1 
        } 
      }
   );
};

When qr/I create a mailaccount failed type$/, sub {
    ( S->{Response}, S->{ResponseContent} ) = _Post(
        URL     => S->{API_URL}.'/system/communication/mailaccounts',
        Token   => S->{Token},
        Content => {
            MailAccount => {
                Login => "mail".rand(),
                Password => "SomePassword".rand(),
                Host => "pop3.example.com",
                Type => "XXX",
                IMAPFolder => "Some Folder",
                Trusted => 0,
                DispatchingBy => "Queue",
                QueueID => 2,
                Comment => "Test MailAccount",
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
