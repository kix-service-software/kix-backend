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

Given qr/a reportdefinition$/, sub {
    ( S->{Response}, S->{ResponseContent} ) = _Post(
        URL     => S->{API_URL}.'/reporting/reportdefinitions',
        Token   => S->{Token},
        Content => {
            ReportDefinition => {
                DataSource => "GenericSQL",
                Name => "test".rand(),
                Config => {
                    DataSource => {
                        SQL => {
                             postgresql => "SELECT id, name, create_by FROM valid WHERE name LIKE '${Parameters.TestParameter}%'"
                        }
                    },
                    Parameters => [
                        {
                            Name => "TestParameter",
                            Label => "Name Pattern",
                            DataType => "STRING"
                        }
                    ],
                    OutputFormats => {
                        CSV => {
                            Columns => [
                                "id",
                                "name",
                                "CreatedByUser"
                            ],
                            IncludeColumnHeader => 1
                        }
                    }
                }
            }
        }
    );
};

When qr/I create a reportdefinition$/, sub {
    ( S->{Response}, S->{ResponseContent} ) = _Post(
        URL     => S->{API_URL}.'/reporting/reportdefinitions',
        Token   => S->{Token},
        Content => {
            ReportDefinition => {
                DataSource => "GenericSQL",
                Name => "test".rand(),
                Config => {
                    DataSource => {
                        SQL => {
                             postgresql => "SELECT id, name, create_by FROM valid WHERE name LIKE '${Parameters.TestParameter}%'"
                        }
                    },
                    Parameters => [
                        {
                            Name => "TestParameter",
                            Label => "Name Pattern",
                            DataType => "STRING"
                        }
                    ],
                    OutputFormats => {
                        CSV => {
                            Columns => [
                                "id",
                                "name",
                                "CreatedByUser"
                            ],
                            IncludeColumnHeader => 1
                        }
                    }
                }
            }
        }
   );
};



