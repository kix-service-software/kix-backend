# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --
use warnings;
use strict;

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

When qr/I query the collection of users$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/users',
   );
};

When qr/I query the collection of users with filter of UserEmail "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/users',
      Filter => '{"User": {"AND": [{"Field": "UserEmail","Operator": "STARTSWITH","Value": "'.$1.'"}]}}',
   );
};

When qr/I query the collection of users with AND-filter of UserEmail "(.*?)" and UserLastname "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/users',
      Filter => '{"User": {"AND": [{"Field": "UserLastname","Operator": "STARTSWITH","Value": "'.$1.'"},{"Field": "UserFirstname","Operator": "STARTSWITH","Value": "'.$2.'"}]}}',
   );
};

When qr/I query the collection of users with AND-filter of UserEmail "(.*?)" and UserIDs and UserFirstname "(.*?)"$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/users',
      Filter => '{"User": {"AND": [{"Field": "UserEmail","Operator": "CONTAINS","Value": "'.$1.'"},{"Field": "UserID","Operator": "IN","Value": [ 1, 2, 3 ],"Type": "numeric"},{"Field": "UserFirstname","Operator": "STARTSWITH","Value": "'.$2.'","Not": true}]}}',
   );
};

When qr/I query the collection of users with a limit of (\d+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/users',
      Limit => $1,
   );
};

When qr/I query the collection of users with include (\w+)$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Get(
      Token => S->{Token},
      URL   => S->{API_URL}.'/system/users?include='.$1
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
