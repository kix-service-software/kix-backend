# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars qw($Self);

# get needed objects
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# ------------------------------------------------------------ #
# make preparations
# ------------------------------------------------------------ #

# create needed users
my @UserIDs;
{
    for my $Counter ( 1 .. 2 ) {

        # create new users for the tests
        my $UserID = $Kernel::OM->Get('User')->UserAdd(
            UserLogin    => 'UnitTest-ImportExport-' . $Counter . $Helper->GetRandomID(),
            ValidID      => 1,
            ChangeUserID => 1,
            IsAgent      => 1,
        );

        push @UserIDs, $UserID;
    }

}

# create needed random template names
my @TemplateName;

for my $Counter ( 1 .. 5 ) {

    push @TemplateName, 'UnitTest' . $Helper->GetRandomID();
}

# create needed random object names
my @ObjectName;
push @ObjectName, 'UnitTest' . $Helper->GetRandomID();

# create needed format names
my @FormatName = ('CSV');

# get original template list for later checks (all elements)
my $TemplateList1All = $Kernel::OM->Get('ImportExport')->TemplateList(
    UserID => 1,
);

# get original template list for later checks (all elements)
my $TemplateList1Object = $Kernel::OM->Get('ImportExport')->TemplateList(
    Object => $ObjectName[0],
    UserID => 1,
);

# ------------------------------------------------------------ #
# define general tests
# ------------------------------------------------------------ #

my $ItemData = [

    # this template is NOT complete and must not be added
    {
        Add => {
            Format  => $FormatName[0],
            Name    => $TemplateName[0],
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },

    # this template is NOT complete and must not be added
    {
        Add => {
            Object  => $ObjectName[0],
            Name    => $TemplateName[0],
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },

    # this template is NOT complete and must not be added
    {
        Add => {
            Object  => $ObjectName[0],
            Format  => $FormatName[0],
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },

    # this template is NOT complete and must not be added
    {
        Add => {
            Object => $ObjectName[0],
            Format => $FormatName[0],
            Name   => $TemplateName[0],
            UserID => 1,
            Silent  => 1,
        },
    },

    # this template is NOT complete and must not be added
    {
        Add => {
            Object  => $ObjectName[0],
            Format  => $FormatName[0],
            Name    => $TemplateName[0],
            ValidID => 1,
            Silent  => 1,
        },
    },

    # this template must be inserted successfully
    {
        Add => {
            Object  => $ObjectName[0],
            Format  => $FormatName[0],
            Name    => $TemplateName[0],
            ValidID => 1,
            UserID  => 1,
        },
        AddGet => {
            Object   => $ObjectName[0],
            Format   => $FormatName[0],
            Name     => $TemplateName[0],
            ValidID  => 1,
            Comment  => '',
            CreateBy => 1,
            ChangeBy => 1,
        },
    },

    # this template have the same name as one test before and must not be added
    {
        Add => {
            Object  => $ObjectName[0],
            Format  => $FormatName[0],
            Name    => $TemplateName[0],
            ValidID => 1,
            UserID  => 1,
            Silent  => 1,
        },
    },

    # this template must be inserted successfully
    {
        Add => {
            Object  => $ObjectName[0],
            Format  => $FormatName[0],
            Name    => $TemplateName[1],
            ValidID => 1,
            Comment => 'TestComment',
            UserID  => 1,
        },
        AddGet => {
            Object   => $ObjectName[0],
            Format   => $FormatName[0],
            Name     => $TemplateName[1],
            ValidID  => 1,
            Comment  => 'TestComment',
            CreateBy => 1,
            ChangeBy => 1,
        },
    },

    # the template one add-test before must be NOT updated (template update arguments NOT complete)
    {
        Update => {
            ValidID => 2,
            UserID  => $UserIDs[0],
            Silent  => 1,
        },
    },

    # the template one add-test before must be NOT updated (template update arguments NOT complete)
    {
        Update => {
            Name   => $TemplateName[1] . 'UPDATE1',
            UserID => $UserIDs[0],
            Silent => 1,
        },
    },

    # the template one add-test before must be NOT updated (template update arguments NOT complete)
    {
        Update => {
            Name    => $TemplateName[1] . 'UPDATE2',
            ValidID => 2,
            Silent  => 1,
        },
    },

    # the template one add-test before must be updated (template update arguments are complete)
    {
        Update => {
            Name    => $TemplateName[1] . 'UPDATE3',
            Comment => 'TestComment UPDATE3',
            ValidID => 2,
            UserID  => $UserIDs[0],
        },
        UpdateGet => {
            Name     => $TemplateName[1] . 'UPDATE3',
            ValidID  => 2,
            Comment  => 'TestComment UPDATE3',
            CreateBy => 1,
            ChangeBy => $UserIDs[0],
        },
    },

    # the template one add-test before must be updated (template update arguments are complete)
    {
        Update => {
            Name    => $TemplateName[1] . 'UPDATE4',
            ValidID => 1,
            Comment => '',
            UserID  => 1,
        },
        UpdateGet => {
            Name     => $TemplateName[1] . 'UPDATE4',
            ValidID  => 1,
            Comment  => '',
            CreateBy => 1,
            ChangeBy => 1,
        },
    },

    # this template must be inserted successfully (check string cleaner function)
    {
        Add => {
            Object  => " \t \n \r " . $ObjectName[0] . " \t \n \r ",
            Format  => " \t \n \r " . $FormatName[0] . " \t \n \r ",
            Name    => " \t \n \r " . $TemplateName[2] . " \t \n \r ",
            ValidID => 1,
            Comment => " \t \n \r Test Comment \t \n \r ",
            UserID  => 1,
        },
        AddGet => {
            Object   => $ObjectName[0],
            Format   => $FormatName[0],
            Name     => $TemplateName[2],
            ValidID  => 1,
            Comment  => 'Test Comment',
            CreateBy => 1,
            ChangeBy => 1,
        },
    },

    # the template one add-test before must be updated (check string cleaner function)
    {
        Update => {
            Name    => " \t \n \r " . $TemplateName[2] . "UPDATE1 \t \n \r ",
            ValidID => 1,
            Comment => " \t \n \r Test Comment UPDATE1 \t \n \r ",
            UserID  => 1,
        },
        UpdateGet => {
            Name     => $TemplateName[2] . 'UPDATE1',
            ValidID  => 1,
            Comment  => 'Test Comment UPDATE1',
            CreateBy => 1,
            ChangeBy => 1,
        },
    },

    # this template must be inserted successfully (Unicode checks)
    {
        Add => {
            Object  => ' ƕ Ƙ ' . $ObjectName[0] . ' Ƶ ƻ ',
            Format  => ' Ǔ ǣ ' . $FormatName[0] . ' ǥ Ǯ ',
            Name    => ' Ƿ Ȝ ' . $TemplateName[3] . ' Ȟ Ƞ ',
            ValidID => 2,
            Comment => ' Ѡ Ѥ TestComment5 Ϡ Ω ',
            UserID  => 1,
        },
        AddGet => {
            Object   => 'ƕƘ' . $ObjectName[0] . 'Ƶƻ',
            Format   => 'Ǔǣ' . $FormatName[0] . 'ǥǮ',
            Name     => 'Ƿ Ȝ ' . $TemplateName[3] . ' Ȟ Ƞ',
            ValidID  => 2,
            Comment  => 'Ѡ Ѥ TestComment5 Ϡ Ω',
            CreateBy => 1,
            ChangeBy => 1,
        },
    },
];

# ------------------------------------------------------------ #
# run general tests
# ------------------------------------------------------------ #

my $TestCount = 1;
my @AddedTemplateIDs;

TEMPLATE:
for my $Item ( @{$ItemData} ) {

    if ( $Item->{Add} ) {

        # add new template
        my $TemplateID = $Kernel::OM->Get('ImportExport')->TemplateAdd(
            %{ $Item->{Add} },
        );

        if ($TemplateID) {
            push @AddedTemplateIDs, $TemplateID;
        }

        # check if template was added successfully or not
        if ( $Item->{AddGet} ) {
            $Self->True(
                $TemplateID,
                "Test $TestCount: TemplateAdd() - TemplateKey: $TemplateID"
            );
        }
        else {
            $Self->False( $TemplateID, "Test $TestCount: TemplateAdd()" );
        }
    }

    if ( $Item->{AddGet} ) {

        # get template data to check the values after template was added
        my $TemplateGet = $Kernel::OM->Get('ImportExport')->TemplateGet(
            TemplateID => $AddedTemplateIDs[-1],
            UserID     => $Item->{Add}->{UserID} || 1,
        );

        # check template data after creation of template
        for my $TemplateAttribute ( sort keys %{ $Item->{AddGet} } ) {
            $Self->Is(
                $TemplateGet->{$TemplateAttribute} || '',
                $Item->{AddGet}->{$TemplateAttribute} || '',
                "Test $TestCount: TemplateGet() - $TemplateAttribute",
            );
        }
    }

    if ( $Item->{Update} ) {

        # check last template id variable
        if ( !$AddedTemplateIDs[-1] ) {
            $Self->False(
                1,
                "Test $TestCount: NO LAST ITEM ID GIVEN. Please add a template first."
            );
            last TEMPLATE;
        }

        # update the template
        my $UpdateSucess = $Kernel::OM->Get('ImportExport')->TemplateUpdate(
            %{ $Item->{Update} },
            TemplateID => $AddedTemplateIDs[-1],
        );

        # check if template was updated successfully or not
        if ( $Item->{UpdateGet} ) {
            $Self->True(
                $UpdateSucess,
                "Test $TestCount: TemplateUpdate() - TemplateKey: $AddedTemplateIDs[-1]",
            );
        }
        else {
            $Self->False(
                $UpdateSucess,
                "Test $TestCount: TemplateUpdate()",
            );
        }
    }

    if ( $Item->{UpdateGet} ) {

        # get template data to check the values after the update
        my $TemplateGet = $Kernel::OM->Get('ImportExport')->TemplateGet(
            TemplateID => $AddedTemplateIDs[-1],
            UserID     => $Item->{Update}->{UserID} || 1,
        );

        # check template data after update
        for my $TemplateAttribute ( sort keys %{ $Item->{UpdateGet} } ) {
            $Self->Is(
                $TemplateGet->{$TemplateAttribute} || '',
                $Item->{UpdateGet}->{$TemplateAttribute} || '',
                "Test $TestCount: TemplateGet() - $TemplateAttribute",
            );
        }
    }
}
continue {

    # increment the counter
    $TestCount++;
}

# ------------------------------------------------------------ #
# TemplateList test 1 (check array references)
# ------------------------------------------------------------ #

# list must be an empty array reference
$Self->True(
    ref $TemplateList1All eq 'ARRAY' && ref $TemplateList1Object eq 'ARRAY',
    "Test $TestCount: TemplateList() - array references",
);

$TestCount++;

# ------------------------------------------------------------ #
# TemplateList test 2 (list must be empty)
# ------------------------------------------------------------ #

# list must be an empty list
$Self->True(
    scalar @{$TemplateList1Object} eq 0,
    "Test $TestCount: TemplateList() - empty list",
);

$TestCount++;

# ------------------------------------------------------------ #
# TemplateList test 2 (check correct number of new items)
# ------------------------------------------------------------ #

# get template list with all elements
my $TemplateList2 = $Kernel::OM->Get('ImportExport')->TemplateList(
    UserID => 1,
);

# list must be an array reference
$Self->True(
    ref $TemplateList2 eq 'ARRAY',
    "Test $TestCount: TemplateList() - array reference",
);

my $TemplateListCount = scalar @{$TemplateList2} - scalar @{$TemplateList1All};

# check correct number of new items
$Self->True(
    $TemplateListCount eq scalar @AddedTemplateIDs,
    "Test $TestCount: TemplateList() - correct number of new items",
);

$TestCount++;

# ------------------------------------------------------------ #
# TemplateDelete test 1 (add one template and delete it)
# ------------------------------------------------------------ #

# get template list with all elements
my $TemplateDelete1List1 = $Kernel::OM->Get('ImportExport')->TemplateList(
    Object => $ObjectName[0],
    UserID => 1,
);

# add a test template
my $TemplateDeleteID = $Kernel::OM->Get('ImportExport')->TemplateAdd(
    Object  => $ObjectName[0],
    Format  => $FormatName[0],
    Name    => $TemplateName[4],
    ValidID => 1,
    UserID  => 1,
);

# get template list with all elements
my $TemplateDelete1List2 = $Kernel::OM->Get('ImportExport')->TemplateList(
    Object => $ObjectName[0],
    UserID => 1,
);

# list must have one element more
$Self->True(
    scalar @{$TemplateDelete1List1} eq ( scalar @{$TemplateDelete1List2} ) - 1,
    "Test $TestCount: TemplateDelete() - number of listed elements",
);

# delete the new template
my $TemplateDelete1 = $Kernel::OM->Get('ImportExport')->TemplateDelete(
    TemplateID => $TemplateDeleteID,
    UserID     => 1,
);

# list must be successful
$Self->True(
    $TemplateDelete1,
    "Test $TestCount: TemplateDelete()",
);

# get template list with all elements
my $TemplateDelete1List3 = $Kernel::OM->Get('ImportExport')->TemplateList(
    Object => $ObjectName[0],
    UserID => 1,
);

# list must have the original number of elements
$Self->True(
    scalar @{$TemplateDelete1List1} eq scalar @{$TemplateDelete1List3},
    "Test $TestCount: TemplateDelete() - number of listed elements",
);

$TestCount++;

# ------------------------------------------------------------ #
# TemplateDelete test 2 (delete all unit test templates)
# ------------------------------------------------------------ #

for my $TemplateID (@AddedTemplateIDs) {

    # delete the template
    my $Success = $Kernel::OM->Get('ImportExport')->TemplateDelete(
        TemplateID => $TemplateID,
        UserID     => 1,
    );

    # check success
    $Self->True(
        $Success,
        "Test $TestCount: TemplateDelete() TemplateID $TemplateID",
    );

    $TestCount++;
}

# ------------------------------------------------------------ #
# ObjectList test 1 (check general functionality)
# ------------------------------------------------------------ #

# define test list
my $ObjectList1TestList = {
    UnitTest1 => {
        Module => 'ImportExport::ObjectBackend::UnitTest1',
        Name   => 'Unit Test 1',
    },
    UnitTest2 => {
        Module => 'ImportExport::ObjectBackend::UnitTest2',
        Name   => 'Unit Test 2',
    },
};

# get original object list
my $ObjectListOrg = $Kernel::OM->Get('Config')->Get('ImportExport::ObjectBackendRegistration');

# set test list
$Kernel::OM->Get('Config')->Set(
    Key   => 'ImportExport::ObjectBackendRegistration',
    Value => $ObjectList1TestList,
);

# get object list
my $ObjectList1 = $Kernel::OM->Get('ImportExport')->ObjectList();

# list must be a hash reference
$Self->True(
    ref $ObjectList1 eq 'HASH',
    "Test $TestCount: ObjectList() - hash reference",
);

# check the list
KEY:
for my $Key ( sort keys %{$ObjectList1} ) {

    if ( !$ObjectList1TestList->{$Key} ) {
        $ObjectList1TestList->{Dummy} = 1;
    }

    next KEY if $ObjectList1->{$Key} ne $ObjectList1TestList->{$Key}->{Name};

    delete $ObjectList1TestList->{$Key};
}

$Self->True(
    !%{$ObjectList1TestList},
    "Test $TestCount: ObjectList() - content is valid",
);

# restore original object list
$Kernel::OM->Get('Config')->Set(
    Key   => 'ImportExport::ObjectBackendRegistration',
    Value => $ObjectListOrg,
);

$TestCount++;

# ------------------------------------------------------------ #
# FormatList test 1 (check general functionality)
# ------------------------------------------------------------ #

# define test list
my $FormatList1TestList = {
    UnitTest1 => {
        Module => 'ImportExport::FormatBackend::UnitTest1',
        Name   => 'Unit Test 1',
    },
    UnitTest2 => {
        Module => 'ImportExport::FormatBackend::UnitTest2',
        Name   => 'Unit Test 2',
    },
};

# get original format list
my $FormatListOrg =
    $Kernel::OM->Get('Config')->Get('ImportExport::FormatBackendRegistration');

# set test list
$Kernel::OM->Get('Config')->Set(
    Key   => 'ImportExport::FormatBackendRegistration',
    Value => $FormatList1TestList,
);

# get format list
my $FormatList1 = $Kernel::OM->Get('ImportExport')->FormatList();

# list must be a hash reference
$Self->True(
    ref $FormatList1 eq 'HASH',
    "Test $TestCount: FormatList() - hash reference",
);

# check the list
KEY:
for my $Key ( sort keys %{$FormatList1} ) {

    if ( !$FormatList1TestList->{$Key} ) {
        $FormatList1TestList->{Dummy} = 1;
    }

    next KEY if $FormatList1->{$Key} ne $FormatList1TestList->{$Key}->{Name};

    delete $FormatList1TestList->{$Key};
}

$Self->True(
    !%{$FormatList1TestList},
    "Test $TestCount: FormatList() - content is valid",
);

# restore original format list
$Kernel::OM->Get('Config')->Set(
    Key   => 'ImportExport::FormatBackendRegistration',
    Value => $FormatListOrg,
);

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
