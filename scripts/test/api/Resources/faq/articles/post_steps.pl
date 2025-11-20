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

Given qr/a faq article$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/faq/articles',
      Token   => S->{Token},
      Content => {
        FAQArticle => {
            Title => "Some Text2".rand(), 
            CategoryID => 1, 
            Visibility => "internal", 
            Language => "en", 
            ContentType => "text/plain", 
            Number => "13402", 
            Keywords => [
                "some", 
                "keywords" 
            ], 
            Field1 => "Symptom...", 
            Field2 => "Problem...", 
            Field3 => "Solution...", 
            Field4 => "Field4...", 
            Field5 => "Field5...", 
            Field6 => "Comment...", 
            Approved => 1, 
            ValidID => 1
        }  
      }
   );
};

When qr/I create a faq article$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/faq/articles',
      Token   => S->{Token},
      Content => {
        FAQArticle => {
            Title => "Some Text2".rand(), 
            CategoryID => 1, 
            Visibility => "internal", 
            Language => "en", 
            ContentType => "text/plain", 
            Number => "13402", 
            Keywords => [
                "some", 
                "keywords" 
            ], 
            Field1 => "Symptom...", 
            Field2 => "Problem...", 
            Field3 => "Solution...", 
            Field4 => "Field4...", 
            Field5 => "Field5...", 
            Field6 => "Comment...", 
            Approved => 1, 
            ValidID => 1
        }  
      }
   );
};

Given qr/(\d+) of faq articles$/, sub {
    my $Title;

    for ($i=0;$i<$1;$i++){
        if ( $i == 2 ) {
            $Title = 'General information on how to work with KIX 18';
        }
        elsif ( $i == 3 ) {
            $Title = 'Information on how to work';
        }
        elsif ( $i == 4 ) {
            $Title = 'Title for FAQ Article';
        }
        else {
            $Title = "Some Text".rand();
        }
        ( S->{Response}, S->{ResponseContent} ) = _Post(
            URL     => S->{API_URL}.'/faq/articles',
            Token   => S->{Token},
            Content => {
                FAQArticle => {
                    Title => $Title,
                    CategoryID => 1,
                    Language => "de",
                    Field1 => "ahahahbhabshab hbah bshbsha bhab hbah ",
                    Field2 => "ahahahbhabshab hbah bshbsha bhab hbah ",
                    Field3 => "ahahahbhabshab hbah bshbsha bhab hbah ",
                    Field6 => "ahahahbhabshab hbah bshbsha bhab hbah "
                }
            }
        );
    }
};

When qr/I create a faq article with no categoryid$/, sub {
    ( S->{Response}, S->{ResponseContent} ) = _Post(
        URL     => S->{API_URL}.'/faq/articles',
        Token   => S->{Token},
        Content => {
            FAQArticle => {
                Title => "Some Text2".rand(),
                CategoryID => ,
                Visibility => "internal",
                Language => "en",
                ContentType => "text/plain",
                Number => "13402",
                Keywords => [
                    "some",
                    "keywords"
                ],
                Field1 => "Symptom...",
                Field2 => "Problem...",
                Field3 => "Solution...",
                Field4 => "Field4...",
                Field5 => "Field5...",
                Field6 => "Comment...",
                Approved => 1,
                ValidID => 1
            }
        }
    );
};



