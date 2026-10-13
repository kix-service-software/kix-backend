# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
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

When qr/I delete this contact$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Delete(
      Token => S->{Token},
      URL   => S->{API_URL}.'/contacts/'.S->{ContactID},
   );
};

When qr/delete all this contacts$/, sub {
    for ($i=0;$i<@{S->{ContactIDArray}};$i++){ 
        ( S->{Response}, S->{ResponseContent} ) = _Delete(
            Token => S->{Token},
            URL   => S->{API_URL}.'/contacts/'.S->{ContactIDArray}->[$i],
        );
    }

    S->{ContactIDArray} = ();

};

When qr/delete all of "(.*?)" and "(.*?)"$/, sub {
    my $LCOrg = lc($2).'s';
    my $LCCont = lc($1).'s';

    ( S->{Response}, S->{ResponseContent} ) = _Get(
        Token => S->{Token},
        URL   => S->{API_URL}.'/'.$LCCont,
    );
    my $Anzahl = @{S->{ResponseContent}->{$1}};
        print STDERR "ContactAnzahl:".Dumper($Anzahl);
    if ( $Anzahl ) {
        print STDERR "ContDRIN!!!!!!!!!!!:";
            foreach my $Row ( @{S->{ResponseContent}->{$1}} ) {
#                print STDERR "ContactRow:" . Dumper( $Row );
                if ( $Row->{ID} != 1 ) {
                    ( S->{Response}, S->{ResponseContent} ) = _Delete(
                        Token => S->{Token},
                        URL   => S->{API_URL} . '/' . $LCCont . '/' . $Row->{ID},
                    );
                }
            }
    }

        ( S->{Response}, S->{ResponseContent} ) = _Get(
            Token => S->{Token},
            URL   => S->{API_URL} . '/' . $LCOrg,
        );
    my $OrgAnzahl = @{S->{ResponseContent}->{$2}};
        print STDERR "OrgAnzahl:".Dumper($OrgAnzahl);
    if ($OrgAnzahl ) {
    print STDERR "OrgaDRIN!!!!!!!!!!!:";
        foreach my $Row ( @{S->{ResponseContent}->{$2}} ) {
            ( S->{Response}, S->{ResponseContent} ) = _Delete(
                Token => S->{Token},
                URL   => S->{API_URL} . '/' . $LCOrg . '/' . $Row->{ID},
            );
        }
    }
};
	