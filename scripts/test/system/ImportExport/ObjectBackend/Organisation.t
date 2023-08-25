# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars qw($Self);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# ------------------------------------------------------------ #
# make preparations
# ------------------------------------------------------------ #

# add some test templates for later checks
my @TemplateIDs;
for ( 1 .. 30 ) {

    # add a test template for later checks
    my $TemplateID = $Kernel::OM->Get('ImportExport')->TemplateAdd(
        Object  => 'Organisation',
        Format  => 'UnitTest' . int rand 1_000_000,
        Name    => 'UnitTest' . int rand 1_000_000,
        ValidID => 1,
        UserID  => 1,
    );

    push @TemplateIDs, $TemplateID;
}

my $TestCount = 1;


# ------------------------------------------------------------ #
# ObjectList test 1 (check CSV item)
# ------------------------------------------------------------ #

# get object list
my $ObjectList1 = $Kernel::OM->Get('ImportExport')->ObjectList();

# check object list
$Self->True(
    $ObjectList1 && ref $ObjectList1 eq 'HASH' && $ObjectList1->{Organisation},
    "Test $TestCount: ObjectList() - Organisation exists",
);

$TestCount++;

# ------------------------------------------------------------ #
# MappingObjectAttributesGet test 1 (check attribute hash)
# ------------------------------------------------------------ #

# get mapping object attributes
my $MappingObjectAttributesGet1 = $Kernel::OM->Get('ImportExport')->MappingObjectAttributesGet(
    TemplateID => $TemplateIDs[0],
    UserID     => 1,
);

# check mapping object attribute reference
$Self->True(
    $MappingObjectAttributesGet1 && ref $MappingObjectAttributesGet1 eq 'ARRAY',
    "MappingObjectAttributesGet() - check array reference",
);

# ------------------------------------------------------------ #
# MappingObjectAttributesGet test 2 (check with non existing template)
# ------------------------------------------------------------ #

# get mapping object attributes
my $MappingObjectAttributesGet2 = $Kernel::OM->Get('ImportExport')->MappingObjectAttributesGet(
    TemplateID => $TemplateIDs[-1] + 1,
    UserID     => 1,
    Silent     => 1
);

# check false return
$Self->False(
    $MappingObjectAttributesGet2,
    "MappingObjectAttributesGet() - check false return",
);

my @UpdataData = (
    {
        Zip     => '01234',
        City    => 'Test Town',
        Street  => 'Test Street',
        Country => 'UnitTest',
    },
    {
        Zip     => '"";;::..--__##',
        City    => "Test;:_°^!\"§\$%&/()=?´`*+Test",
        Street  => "><@~\'}{[]\\",
        Country => "Test;:_°^!\"§\$%&/()=?´`*+Test",
    },
    {
        Zip     => '01584',
        City    => 'Unittest Town',
        Street  => 'Unittest Way',
        Country => 'KIXUnitTest',
    },
    {
        Zip     => '01235',
        City    => 'Test Town',
        Street  => 'Test Street',
        Country => 'UnitTest',
    },
    {
        Zip     => '01594',
        City    => 'Unittest Town',
        Street  => 'Unittest Way',
        Country => 'KIXUnitTest',
    },
    {
        Zip     => 'ↂ ⅻ ⅛ ☄ ↮ ↹ →',
        City    => '₤ ₡ ₩ ₯ ₵ か げ を',
        Street  => '♊ ♈ ♉ ♊ ♋ ♍ ♑',
        Country => '✈ ❤ ☮ Պ Մ Հ ® ©',
    },
    {
        Zip     => '01234',
        City    => 'Test Town',
        Street  => 'Test Street',
        Country => 'UnitTest',
    },
    {
        Zip     => '01234',
        City    => 'Test Town',
        Street  => 'Test Street',
        Country => 'UnitTest',
    },
    {
        Zip     => '01584',
        City    => 'Unittest Town',
        Street  => 'Unittest Path',
        Country => 'KIXUnitTest',
    },
    {}, # empty
);

# create some random Organisations
my @Organisations;
for ( 1 .. 10 ) {
    my $OrgaID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
        %{$UpdataData[$_-1]},
        Number  => $Helper->GetRandomID(),
        Name    => 'UnitTest' . $_,
        ValidID => 1,
        UserID  => 1
    );

    my %Orga = $Kernel::OM->Get('Organisation')->OrganisationGet(
        ID => $OrgaID,
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'Organisation'
        ]
    );

    push @Organisations, \%Orga;
}

# ------------------------------------------------------------ #
# define general ExportDataGet tests
# ------------------------------------------------------------ #

my @ExportDataTests = (

    # 1 ImportDataGet doesn't contains all data (check required attributes)
    {
        SourceExportData => {
            ExportDataGet => {
                UserID => 1,
                Silent => 1
            },
        },
    },

    # 2 ImportDataGet doesn't contains all data (check required attributes)
    {
        SourceExportData => {
            ExportDataGet => {
                TemplateID => $TemplateIDs[1],
                Silent => 1
            },
        },
    },

    # 3 no existing template id is given (check return false)
    {
        SourceExportData => {
            ExportDataGet => {
                TemplateID => $TemplateIDs[-1] + 1000,
                UserID     => 1,
                Silent     => 1
            },
        },
    },

    # 4 mapping list is empty (check return false)
    {
        SourceExportData => {
            ExportDataGet => {
                TemplateID => $TemplateIDs[3],
                UserID     => 1,
                Silent     => 1
            },
        },
    },

    # 5  invalid object data is given (check return false)
    {
        SourceExportData => {
            ObjectData => {
                DynamicField => undef,
            },
            ExportDataGet => {
                TemplateID => $TemplateIDs[2],
                UserID     => 1,
                Silent     => 1
            },
        },
    },

    # 6 all required values are given (number search check)
    {
        SourceExportData => {
            ObjectData => {
                DynamicField => 0,
            },
            MappingObjectData => [
                {
                    Key => 'Number',
                },
            ],
            SearchData => {
                Number => $Organisations[0]->{Number},
            },
            ExportDataGet => {
                TemplateID => $TemplateIDs[5],
                UserID     => 1,
            },
        },
        ReferenceExportData => [
            [ $Organisations[0]->{Number} ],
        ],
    },

    # 7 all required values are given (name search check)
    {
        SourceExportData => {
            ObjectData => {
                DynamicField => 0,
            },
            MappingObjectData => [
                {
                    Key => 'Number',
                },
            ],
            SearchData => {
                Name => 'UnitTest1',
            },
            ExportDataGet => {
                TemplateID => $TemplateIDs[5],
                UserID     => 1,
            },
        },
        ReferenceExportData => [
            [ $Organisations[0]->{Number} ],
        ],
    },

    # 8 all required values are given (case insensitive name search check)
    {
        SourceExportData => {
            ObjectData => {
                DynamicField => 0,
            },
            MappingObjectData => [
                {
                    Key => 'Number',
                },
            ],
            SearchData => {
                Name => 'unittest1',
            },
            ExportDataGet => {
                TemplateID => $TemplateIDs[5],
                UserID     => 1,
            },
        },
        ReferenceExportData => [
            [ $Organisations[0]->{Number} ],
        ],
    },

    # 9 all required values are given (wildcard name search check)
    {
        SourceExportData => {
            ObjectData => {
                DynamicField => 0,
            },
            MappingObjectData => [
                {
                    Key => 'Number',
                },
            ],
            SearchData => {
                Name => 'UnitTest1*',
            },
            ExportDataGet => {
                TemplateID => $TemplateIDs[5],
                UserID     => 1,
            },
        },
        ReferenceExportData => [
            [
                $Organisations[0]->{Number}
            ],
            [
                $Organisations[9]->{Number}
            ]
        ],
    },

    # 10 all required values are given (name and zip search check)
    {
        SourceExportData => {
            ObjectData => {
                DynamicField => 0,
            },
            MappingObjectData => [
                {
                    Key => 'Number',
                },
            ],
            SearchData => {
                Search => '01584',
                Name   => 'UnitTest*',
            },
            ExportDataGet => {
                TemplateID => $TemplateIDs[5],
                UserID     => 1,
            },
        },
        ReferenceExportData => [
            [ $Organisations[2]->{Number} ],
            [ $Organisations[8]->{Number} ],
        ],
    },

    # 11 all required values are given (url search check no result)
    {
        SourceExportData => {
            ObjectData => {
                DynamicField => 0,
            },
            MappingObjectData => [
                {
                    Key => 'Number',
                },
            ],
            SearchData => {
                Url  => 'https://',
            },
            ExportDataGet => {
                TemplateID => $TemplateIDs[5],
                UserID     => 1,
            },
        },
        ReferenceExportData => [],
    },

    # 12 all required values are given (check the returned array)
    {
        SourceExportData => {
            ObjectData => {
                DynamicField => 0,
            },
            MappingObjectData => [
                {
                    Key => 'Number',
                },
                {
                    Key => 'Name',
                },
                {
                    Key => 'Street',
                },
                {
                    Key => 'Zip',
                },
                {
                    Key => 'City',
                },
                {
                    Key => 'Country',
                },
                {
                    Key => 'Url',
                }
            ],
            SearchData => {
                Name => $Organisations[0]->{Name},
            },
            ExportDataGet => {
                TemplateID => $TemplateIDs[6],
                UserID     => 1,
            },
        },
        ReferenceExportData => [
            [
                $Organisations[0]->{Number},
                $Organisations[0]->{Name},
                'Test Street',
                '01234',
                'Test Town',
                'UnitTest',
                undef
            ],
        ],
    },

    # 13 all required values are given (double element checks)
    {
        SourceExportData => {
            ObjectData => {
                DynamicField => 0,
            },
            MappingObjectData => [
                {
                    Key => 'Number',
                },
                {
                    Key => 'Number',
                },
                {
                    Key => 'Name',
                },
                {
                    Key => 'Name',
                },
                {
                    Key => 'Street',
                },
                {
                    Key => 'Street',
                },
                {
                    Key => 'Zip',
                },
                {
                    Key => 'Zip',
                },
                {
                    Key => 'City',
                },
                {
                    Key => 'City',
                },
                {
                    Key => 'Country',
                },
                {
                    Key => 'Country',
                },
                {
                    Key => 'Url',
                },
                {
                    Key => 'Url',
                }
            ],
            SearchData => {
                Name => $Organisations[0]->{Name},
            },
            ExportDataGet => {
                TemplateID => $TemplateIDs[6],
                UserID     => 1,
            },
        },
        ReferenceExportData => [
            [
                $Organisations[0]->{Number},
                $Organisations[0]->{Number},
                $Organisations[0]->{Name},
                $Organisations[0]->{Name},
                'Test Street',
                'Test Street',
                '01234',
                '01234',
                'Test Town',
                'Test Town',
                'UnitTest',
                'UnitTest',
                undef,
                undef
            ],
        ],
    },

    # 14 all required values are given (special character checks)
    {
        SourceExportData => {
            ObjectData => {
                DynamicField => 0,
            },
            MappingObjectData => [
                {
                    Key => 'Number',
                },
                {
                    Key => 'Name',
                },
                {
                    Key => 'Street',
                },
                {
                    Key => 'Zip',
                },
                {
                    Key => 'City',
                },
                {
                    Key => 'Country',
                },
                {
                    Key => 'Url',
                }
            ],
            SearchData => {
                Name => $Organisations[1]->{Name},
            },
            ExportDataGet => {
                TemplateID => $TemplateIDs[8],
                UserID     => 1,
            },
        },
        ReferenceExportData => [
            [
                $Organisations[1]->{Number},
                $Organisations[1]->{Name},
                "><@~\'}{[]\\",
                '"";;::..--__##',
                "Test;:_°^!\"§\$%&/()=?´`*+Test",
                "Test;:_°^!\"§\$%&/()=?´`*+Test",
                undef
            ],
        ],
    },

    # 15 all required values are given (UTF-8 checks)
    {
        SourceExportData => {
            ObjectData => {
                DynamicField => 0,
            },
            MappingObjectData => [
                {
                    Key => 'Number',
                },
                {
                    Key => 'Name',
                },
                {
                    Key => 'Street',
                },
                {
                    Key => 'Zip',
                },
                {
                    Key => 'City',
                },
                {
                    Key => 'Country',
                },
                {
                    Key => 'Url',
                }
            ],
            SearchData => {
                Name => $Organisations[5]->{Name},
            },
            ExportDataGet => {
                TemplateID => $TemplateIDs[9],
                UserID     => 1,
            },
        },
        ReferenceExportData => [
            [
                $Organisations[5]->{Number},
                $Organisations[5]->{Name},
                '♊ ♈ ♉ ♊ ♋ ♍ ♑',
                'ↂ ⅻ ⅛ ☄ ↮ ↹ →',
                '₤ ₡ ₩ ₯ ₵ か げ を',
                '✈ ❤ ☮ Պ Մ Հ ® ©',
                undef
            ],
        ],
    },
);

# ------------------------------------------------------------ #
# run general ExportDataGet tests
# ------------------------------------------------------------ #

my $ExportTestCount = 1;
TEST:
for my $Test (@ExportDataTests) {

    # check SourceExportData attribute
    if (
        !$Test->{SourceExportData}
        || ref $Test->{SourceExportData} ne 'HASH'
    ) {

        $Self->True(
            0,
            "ExportTest $ExportTestCount: No SourceExportData found for this test."
        );

        next TEST;
    }

    # set the object data
    if (
        $Test->{SourceExportData}->{ObjectData}
        && ref $Test->{SourceExportData}->{ObjectData} eq 'HASH'
        && $Test->{SourceExportData}->{ExportDataGet}->{TemplateID}
    ) {

        # save object data
        $Kernel::OM->Get('ImportExport')->ObjectDataSave(
            TemplateID => $Test->{SourceExportData}->{ExportDataGet}->{TemplateID},
            ObjectData => $Test->{SourceExportData}->{ObjectData},
            UserID     => 1,
        );
    }

    # set the mapping object data
    if (
        $Test->{SourceExportData}->{MappingObjectData}
        && ref $Test->{SourceExportData}->{MappingObjectData} eq 'ARRAY'
        && $Test->{SourceExportData}->{ExportDataGet}->{TemplateID}
    ) {

        # delete all existing mapping data
        $Kernel::OM->Get('ImportExport')->MappingDelete(
            TemplateID => $Test->{SourceExportData}->{ExportDataGet}->{TemplateID},
            UserID     => 1,
        );

        # add the mapping object rows
        MAPPINGOBJECTDATA:
        for my $MappingObjectData ( @{ $Test->{SourceExportData}->{MappingObjectData} } ) {

            # add a new mapping row
            my $MappingID = $Kernel::OM->Get('ImportExport')->MappingAdd(
                TemplateID => $Test->{SourceExportData}->{ExportDataGet}->{TemplateID},
                UserID     => 1,
            );

            # add the mapping object data
            $Kernel::OM->Get('ImportExport')->MappingObjectDataSave(
                MappingID         => $MappingID,
                MappingObjectData => $MappingObjectData,
                UserID            => 1,
            );
        }
    }

    # add the search data
    if (
        $Test->{SourceExportData}->{SearchData}
        && ref $Test->{SourceExportData}->{SearchData} eq 'HASH'
        && $Test->{SourceExportData}->{ExportDataGet}->{TemplateID}
     ) {

        # save search data
        $Kernel::OM->Get('ImportExport')->SearchDataSave(
            TemplateID => $Test->{SourceExportData}->{ExportDataGet}->{TemplateID},
            SearchData => $Test->{SourceExportData}->{SearchData},
            UserID     => 1,
        );
    }

    # get export data
    my $ExportData = $Kernel::OM->Get('Kernel::System::ImportExport::ObjectBackend::Organisation')->ExportDataGet(
        %{ $Test->{SourceExportData}->{ExportDataGet} },
    );

    if ( !$Test->{ReferenceExportData} ) {

        $Self->False(
            $ExportData,
            "ExportTest $ExportTestCount: ExportDataGet() - return false",
        );

        next TEST;
    }

    if ( ref $ExportData ne 'ARRAY' ) {

        # check array reference
        $Self->True(
            0,
            "ExportTest $ExportTestCount: ExportDataGet() - return value is an array reference",
        );

        next TEST;
    }

    # check number of rows
    $Self->Is(
        scalar @{$ExportData},
        scalar @{ $Test->{ReferenceExportData} },
        "ExportTest $ExportTestCount: ExportDataGet() - correct number of rows",
    );

    # check content of export data
    # ignore sort from exported data, just check if it is included
    my @SortedExport    = sort { $a->[0] cmp $b->[0] } @{$ExportData};
    my @SortedReference = sort { $a->[0] cmp $b->[0] } @{$Test->{ReferenceExportData}};

    my $CounterRow = 0;
    ROW:
    for my $ExportRow ( @SortedExport ) {

        # extract reference row
        my $ReferenceRow = $SortedReference[$CounterRow];

        if ( ref $ExportRow ne 'ARRAY' || ref $ReferenceRow ne 'ARRAY' ) {

            # check array reference
            $Self->True(
                0,
                "ExportTest $ExportTestCount: ExportDataGet() - export row and reference row matched",
            );

            next TEST;
        }

        # check number of columns
        $Self->Is(
            scalar @{$ExportRow},
            scalar @{$ReferenceRow},
            "ExportTest $ExportTestCount: ExportDataGet() - correct number of columns",
        );

        my $CounterColumn = 0;
        for my $Cell ( @{$ExportRow} ) {

            # set content if values are undef
            if ( !defined $Cell ) {
                $Cell = 'UNDEF-unittest';
            }
            if ( !defined $ReferenceRow->[$CounterColumn] ) {
                $ReferenceRow->[$CounterColumn] = 'UNDEF-unittest';
            }

            # check cell data
            $Self->Is(
                $Cell,
                $ReferenceRow->[$CounterColumn],
                "ExportTest $ExportTestCount: ExportDataGet() ",
            );

            $CounterColumn++;
        }

        $CounterRow++;
    }
}
continue {
    $ExportTestCount++;
}


# ------------------------------------------------------------ #
# define general ImportDataSave tests
# ------------------------------------------------------------ #

my @ImportDataTests = (

    # 1 ImportDataSave doesn't contains all data (check required attributes)
    {
        SourceImportData => {
            ImportDataSave => {
                ImportDataRow => [],
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 2 ImportDataSave doesn't contains all data (check required attributes)
    {
        SourceImportData => {
            ImportDataSave => {
                TemplateID => $TemplateIDs[20],
                UserID     => 1,
                Silent     => 1
            },
        },
    },

    # 3 ImportDataSave doesn't contains all data (check required attributes)
    {
        SourceImportData => {
            ImportDataSave => {
                TemplateID    => $TemplateIDs[20],
                ImportDataRow => [],
                Silent        => 1
            },
        },
    },

    # 4 import data row must be an array reference (check return false)
    {
        SourceImportData => {
            ImportDataSave => {
                TemplateID    => $TemplateIDs[20],
                ImportDataRow => q{},
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 5 import data row must be an array reference (check return false)
    {
        SourceImportData => {
            ImportDataSave => {
                TemplateID    => $TemplateIDs[20],
                ImportDataRow => {},
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 6 no existing template id is given (check return false)
    {
        SourceImportData => {
            ImportDataSave => {
                TemplateID    => $TemplateIDs[-1] + 1,
                ImportDataRow => ['Dummy'],
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 7 no class id is given (check return false)
    {
        SourceImportData => {
            ImportDataSave => {
                TemplateID    => $TemplateIDs[21],
                ImportDataRow => ['Dummy'],
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 8 invalid class id is given (check return false)
    {
        SourceImportData => {
            ObjectData => {
                DynamicField => undef,
                Silent       => 1
            },
            ImportDataSave => {
                TemplateID    => $TemplateIDs[22],
                ImportDataRow => ['Dummy'],
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 9 mapping list is empty (check return false)
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            ImportDataSave => {
                TemplateID    => $TemplateIDs[23],
                ImportDataRow => ['Dummy'],
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 10 more than one identifier with the same name (check return false)
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            MappingObjectData => [
                {
                    Key        => 'Name',
                    Identifier => 1,
                },
                {
                    Key        => 'Name',
                    Identifier => 1,
                },
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[23],
                ImportDataRow => [ '123', '321' ],
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 11 identifier is empty (check return false)
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            MappingObjectData => [
                {
                    Key        => 'Name',
                    Identifier => 1,
                },
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[23],
                ImportDataRow => [q{}],
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 12 identifier is undef (check return false)
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            MappingObjectData => [
                {
                    Key        => 'Name',
                    Identifier => 1,
                },
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[23],
                ImportDataRow => [undef],
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 13 both identifiers are empty (check return false)
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            MappingObjectData => [
                {
                    Key        => 'Number',
                    Identifier => 1,
                },
                {
                    Key        => 'Name',
                    Identifier => 1,
                },
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[23],
                ImportDataRow => [ q{}, q{} ],
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 14 both identifiers are undef (check return false)
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            MappingObjectData => [
                {
                    Key        => 'Number',
                    Identifier => 1,
                },
                {
                    Key        => 'Name',
                    Identifier => 1,
                },
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[23],
                ImportDataRow => [ undef, undef ],
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 15 one identifiers is empty, one is undef (check return false)
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            MappingObjectData => [
                {
                    Key        => 'Number',
                    Identifier => 1,
                },
                {
                    Key        => 'Name',
                    Identifier => 1,
                },
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[23],
                ImportDataRow => [ q{}, undef ],
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 16 one of the identifiers is empty (check return false)
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            MappingObjectData => [
                {
                    Key        => 'Number',
                    Identifier => 1,
                },
                {
                    Key        => 'Name',
                    Identifier => 1,
                },
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[23],
                ImportDataRow => [ $Organisations[6]->{Number}, q{} ],
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 17 one of the identifiers is undef (check return false)
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            MappingObjectData => [
                {
                    Key        => 'Number',
                    Identifier => 1,
                },
                {
                    Key        => 'Name',
                    Identifier => 1,
                },
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[23],
                ImportDataRow => [ $Organisations[6]->{Number}, undef ],
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 18 one of the identifiers is empty (check return false)
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            MappingObjectData => [
                {
                    Key        => 'Number',
                    Identifier => 1,
                },
                {
                    Key        => 'Name',
                    Identifier => 1,
                },
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[23],
                ImportDataRow => [ q{}, $Organisations[6]->{Name} ],
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 19 one of the identifiers is empty (check return false)
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            MappingObjectData => [
                {
                    Key        => 'Number',
                    Identifier => 1,
                },
                {
                    Key        => 'Name',
                    Identifier => 1,
                },
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[23],
                ImportDataRow => [ undef, $Organisations[6]->{Name} ],
                UserID        => 1,
                Silent        => 1
            },
        },
    },

    # 20 all required values are given (a NEW organisation must be created)
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            MappingObjectData => [
                {
                    Key => 'Number',
                },
                {
                    Key => 'Name',
                },
                {
                    Key => 'Street',
                },
                {
                    Key => 'Zip',
                },
                {
                    Key => 'City',
                },
                {
                    Key => 'Country',
                },
                {
                    Key => 'Url',
                },
                {
                    Key => 'Comment',
                },
                {
                    Key => 'ValidID',
                }
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[25],
                ImportDataRow => [
                    'UnitTest12345678',
                    'Importtest1',
                    undef,
                    undef,
                    undef,
                    undef,
                    undef,
                    "Test3\nTextArray3\nTest3",
                    1,
                ],
                UserID => 1,
            },
        },
        ReferenceImportData => {
            Number  => 'UnitTest12345678',
            Name    => 'Importtest1',
            Comment => "Test3\nTextArray3\nTest3",
            ValidID => 1
        },
    },

    # 21 all required values are given (a second NEW organisation must be created)
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            MappingObjectData => [
                {
                    Key => 'Number',
                },
                {
                    Key => 'Name',
                },
                {
                    Key => 'Street',
                },
                {
                    Key => 'Zip',
                },
                {
                    Key => 'City',
                },
                {
                    Key => 'Country',
                },
                {
                    Key => 'Url',
                },
                {
                    Key => 'Comment',
                },
                {
                    Key => 'ValidID',
                }
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[25],
                ImportDataRow => [
                    'UnitTest12345689',
                    'Importtest2',
                    undef,
                    undef,
                    undef,
                    'Germany',
                    undef,
                    "Test3\nTextArray3\nTest3",
                    1,
                ],
                UserID => 1,
            },
        },
        ReferenceImportData => {
            Number  => 'UnitTest12345689',
            Name    => 'Importtest2',
            Comment => "Test3\nTextArray3\nTest3",
            Country => 'Germany',
            ValidID => 1
        },
    },

    # 22 all required values are given (a update first test organisation)
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            MappingObjectData => [
                {
                    Key        => 'Number',
                    Identifier => 1
                },
                {
                    Key => 'Name',
                },
                {
                    Key => 'Street',
                },
                {
                    Key => 'Zip',
                },
                {
                    Key => 'City',
                },
                {
                    Key => 'Country',
                },
                {
                    Key => 'Url',
                },
                {
                    Key => 'Comment',
                },
                {
                    Key => 'ValidID',
                }
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[25],
                ImportDataRow => [
                    'UnitTest12345678',
                    'Importtest1',
                    'Unit Test',
                    '01234',
                    'UnitTest Town',
                    'Germany',
                    undef,
                    "Test3\nTextArray3\nTest3",
                    1,
                ],
                UserID => 1,
            },
        },
        ReferenceImportData => {
            Number  => 'UnitTest12345678',
            Name    => 'Importtest1',
            Comment => "Test3\nTextArray3\nTest3",
            ValidID => 1,
            Street  => 'Unit Test',
            Zip     => '01234',
            City    => 'UnitTest Town',
            Country => 'Germany'
        },
    },

    # 23 all required values are given (special character checks)
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            MappingObjectData => [
                {
                    Key        => 'Number',
                    Identifier => 1
                },
                {
                    Key => 'Name',
                },
                {
                    Key => 'Street',
                },
                {
                    Key => 'Zip',
                },
                {
                    Key => 'City',
                },
                {
                    Key => 'Country',
                },
                {
                    Key => 'Url',
                },
                {
                    Key => 'Comment',
                },
                {
                    Key => 'ValidID',
                }
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[25],
                ImportDataRow => [
                    'UnitTest12345678',
                    'Importtest1',
                    '"";;::..--__##',
                    '01234',
                    "Test;:_°^!\"§\$%&/()=?´`*+Test",
                    "><@~\'}{[]\\",
                    undef,
                    "Test3\nTextArray3\nTest3",
                    1,
                ],
                UserID => 1,
            },
        },
        ReferenceImportData => {
            Number  => 'UnitTest12345678',
            Name    => 'Importtest1',
            Comment => "Test3\nTextArray3\nTest3",
            ValidID => 1,
            Street  => '"";;::..--__##',
            Zip     => '01234',
            City    => "Test;:_°^!\"§\$%&/()=?´`*+Test",
            Country => "><@~\'}{[]\\"
        },
    },

    # 24 all required values are given (UTF-8 checks)
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            MappingObjectData => [
                {
                    Key        => 'Number',
                    Identifier => 1
                },
                {
                    Key => 'Name',
                },
                {
                    Key => 'Street',
                },
                {
                    Key => 'Zip',
                },
                {
                    Key => 'City',
                },
                {
                    Key => 'Country',
                },
                {
                    Key => 'Url',
                },
                {
                    Key => 'Comment',
                },
                {
                    Key => 'ValidID',
                }
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[25],
                ImportDataRow => [
                    'UnitTest12345678',
                    'Importtest1',
                    'π χ Ϙ Ϻ ϱ Ϯ',
                    '01234',
                    'ɯ ʓ ʠ ʬ ʯ',
                    'й ф щ',
                    'Ϋ δ λ',
                    'њ ё Ѭ Ѧ',
                    1,
                ],
                UserID => 1,
            },
        },
        ReferenceImportData => {
            Number  => 'UnitTest12345678',
            Name    => 'Importtest1',
            Comment => 'њ ё Ѭ Ѧ',
            ValidID => 1,
            Url     => 'Ϋ δ λ',
            Street  => 'π χ Ϙ Ϻ ϱ Ϯ',
            Zip     => '01234',
            City    => 'ɯ ʓ ʠ ʬ ʯ',
            Country => 'й ф щ'
        },
    },

    # 25 import an empty value for title, with EmptyFieldsLeaveTheOldValues turned on
    # no changes should be given
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 1,
            },
            MappingObjectData => [
                {
                    Key        => 'Number',
                    Identifier => 1
                },
                {
                    Key => 'Name',
                },
                {
                    Key => 'Street',
                },
                {
                    Key => 'Zip',
                },
                {
                    Key => 'City',
                },
                {
                    Key => 'Country',
                },
                {
                    Key => 'Url',
                },
                {
                    Key => 'Comment',
                },
                {
                    Key => 'ValidID',
                }
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[25],
                ImportDataRow => [
                    'UnitTest12345678',
                    'Importtest1',
                    'π χ Ϙ Ϻ ϱ Ϯ',
                    '01234',
                    'ɯ ʓ ʠ ʬ ʯ',
                    'й ф щ',
                    q{},
                    'њ ё Ѭ Ѧ',
                    1,
                ],
                UserID => 1,
            },
        },
        ReferenceImportData => {
            Number  => 'UnitTest12345678',
            Name    => 'Importtest1',
            Comment => 'њ ё Ѭ Ѧ',
            ValidID => 1,
            Url     => 'Ϋ δ λ',
            Street  => 'π χ Ϙ Ϻ ϱ Ϯ',
            Zip     => '01234',
            City    => 'ɯ ʓ ʠ ʬ ʯ',
            Country => 'й ф щ'
        },
    },

    # 26 import an empty value for title, with EmptyFieldsLeaveTheOldValues turned off
    # an update should be changed the value of title
    {
        SourceImportData => {
            ObjectData => {
                EmptyFieldsLeaveTheOldValues => 0,
            },
            MappingObjectData => [
                {
                    Key        => 'Number',
                    Identifier => 1
                },
                {
                    Key => 'Name',
                },
                {
                    Key => 'Street',
                },
                {
                    Key => 'Zip',
                },
                {
                    Key => 'City',
                },
                {
                    Key => 'Country',
                },
                {
                    Key => 'Url',
                },
                {
                    Key => 'Comment',
                },
                {
                    Key => 'ValidID',
                }
            ],
            ImportDataSave => {
                TemplateID    => $TemplateIDs[25],
                ImportDataRow => [
                    'UnitTest12345678',
                    'Importtest1',
                    'π χ Ϙ Ϻ ϱ Ϯ',
                    '01234',
                    'ɯ ʓ ʠ ʬ ʯ',
                    'й ф щ',
                    q{},
                    'њ ё Ѭ Ѧ',
                    1,
                ],
                UserID => 1,
            },
        },
        ReferenceImportData => {
            Number  => 'UnitTest12345678',
            Name    => 'Importtest1',
            Comment => 'њ ё Ѭ Ѧ',
            ValidID => 1,
            Url     => q{},
            Street  => 'π χ Ϙ Ϻ ϱ Ϯ',
            Zip     => '01234',
            City    => 'ɯ ʓ ʠ ʬ ʯ',
            Country => 'й ф щ'
        },
    },
);

# ------------------------------------------------------------ #
# run general Import tests
# ------------------------------------------------------------ #

my $ImportTestCount = 1;
TEST:
for my $Test (@ImportDataTests) {

    # check SourceImportData attribute
    if (
        !$Test->{SourceImportData}
        || ref $Test->{SourceImportData} ne 'HASH'
    ) {

        $Self->True(
            0,
            "ImportTest $ImportTestCount: No SourceImportData found for this test."
        );

        next TEST;
    }

    # set the object data
    if (
        $Test->{SourceImportData}->{ObjectData}
        && ref $Test->{SourceImportData}->{ObjectData} eq 'HASH'
        && $Test->{SourceImportData}->{ImportDataSave}->{TemplateID}
    ) {

        # save object data
        $Kernel::OM->Get('ImportExport')->ObjectDataSave(
            TemplateID => $Test->{SourceImportData}->{ImportDataSave}->{TemplateID},
            ObjectData => $Test->{SourceImportData}->{ObjectData},
            UserID     => 1,
        );
    }

    # set the mapping object data
    if (
        $Test->{SourceImportData}->{MappingObjectData}
        && ref $Test->{SourceImportData}->{MappingObjectData} eq 'ARRAY'
        && $Test->{SourceImportData}->{ImportDataSave}->{TemplateID}
    ) {

        # delete all existing mapping data
        $Kernel::OM->Get('ImportExport')->MappingDelete(
            TemplateID => $Test->{SourceImportData}->{ImportDataSave}->{TemplateID},
            UserID     => 1,
        );

        # add the mapping object rows
        MAPPINGOBJECTDATA:
        for my $MappingObjectData ( @{ $Test->{SourceImportData}->{MappingObjectData} } ) {

            # add a new mapping row
            my $MappingID = $Kernel::OM->Get('ImportExport')->MappingAdd(
                TemplateID => $Test->{SourceImportData}->{ImportDataSave}->{TemplateID},
                UserID     => 1,
            );

            # add the mapping object data
            $Kernel::OM->Get('ImportExport')->MappingObjectDataSave(
                MappingID         => $MappingID,
                MappingObjectData => $MappingObjectData,
                UserID            => 1,
            );
        }
    }

    # import data save
    my ( $OrganisationID, $RetCode ) = $Kernel::OM->Get('Kernel::System::ImportExport::ObjectBackend::Organisation')->ImportDataSave(
        %{ $Test->{SourceImportData}->{ImportDataSave} },
        Counter => $ImportTestCount,
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'Organisation'
        ]
    );

    if ( !$Test->{ReferenceImportData} ) {

        $Self->False(
            $OrganisationID,
            "ImportTest $ImportTestCount: ImportDataSave() - return no OrganisationID"
        );
        $Self->False(
            $RetCode,
            "ImportTest $ImportTestCount: ImportDataSave() - return no RetCode"
        );

        next TEST;
    }

    $Self->True(
        $OrganisationID,
        "ImportTest $ImportTestCount: ImportDataSave() - return OrganisationID"
    );
    $Self->True(
        $RetCode,
        "ImportTest $ImportTestCount: ImportDataSave() - return RetCode"
    );

    my %Organisation = $Kernel::OM->Get('Organisation')->OrganisationGet(
        ID => $OrganisationID
    );

    for my $Attribute ( sort keys %{$Test->{ReferenceImportData}} ) {
        $Self->Is(
            $Organisation{$Attribute},
            $Test->{ReferenceImportData}->{$Attribute},
            "ImportTest $ImportTestCount: ImportDataSave() $Attribute is identical",
        );
    }

}
continue {
    $ImportTestCount++;
}

# rollback transaction on database
$Helper->Rollback();

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
