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

Given qr/a link$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/links',
      Token   => S->{Token},
      Content => {
        Link => {
            SourceObject => "Ticket", 
            SourceKey => "81426", 
            TargetObject => "Ticket", 
            TargetKey => "35674", 
            Type => "Normal"
        } 
      }
   );
};

When qr/I create a link$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/links',
      Token   => S->{Token},
      Content => {
        Link => {
            SourceObject => "Ticket", 
            SourceKey => "81426", 
            TargetObject => "Ticket", 
            TargetKey => "35674", 
            Type => "Normal"
        } 
      }
   );
};

When qr/I create a link with no (.*?)$/, sub {
    my $To;
    my $Type;
    my $Sk;

    if ( $1 eq "targetobject" ){
       $To = "",
       $Sk = "2",
       $Type = "ParentChild"
    }
    elsif ($1 eq "sourcekey") {
        $To = "Ticket",
        $Sk = '',
        $Type = "ParentChild"
    }
    elsif ($1 eq "type"){
        $To = "Ticket",
        $Sk = "2",
        $Type = ""
    }
    ( S->{Response}, S->{ResponseContent} ) = _Post(
        URL     => S->{API_URL}.'/links',
        Token   => S->{Token},
        Content => {
            Link => {
                SourceObject => "Ticket",
                SourceKey => $Sk,
                TargetObject => $To,
                TargetKey => "35674",
                Type => $Type
            }
        }
    );
};




