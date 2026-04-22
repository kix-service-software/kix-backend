# --
# Modified version of the work: Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/ 
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

use vars (qw($Self));

use MIME::Base64;

# get object icon object
my $ObjectIconObject = $Kernel::OM->Get('ObjectIcon');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my @ObjectIconIDListOrg = @{ $ObjectIconObject->ObjectIconList() };

my $SVGContent = <<END;
<!DOCTYPE html>
<html>
<body>

<h2>SVG circle Element</h2>

<svg height="100" width="100" xmlns="http://www.w3.org/2000/svg">
  <circle r="45" cx="50" cy="50" fill="red" />
  Sorry, your browser does not support inline SVG.  
</svg> 
 
</body>
</html>
END

my $SVGContent_Update = <<END;
<!DOCTYPE html>
<html>
<body>

<h2>SVG rect Element</h2>

<svg width="300" height="130" xmlns="http://www.w3.org/2000/svg">
  <rect width="200" height="100" x="10" y="10" rx="20" ry="20" fill="blue" />
  Sorry, your browser does not support inline SVG.  
</svg>
 
</body>
</html>
END

my @CreateTests = (
    {
        Name   => 'ObjectIconAdd(): invalid data - no data',
        Data   => {},
        Expect => undef,
    },
    {
        Name   => 'ObjectIconAdd(): invalid data - no Object',
        Data   => {
            ObjectID    => 'objectid1',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
            UserID      => 1,
        },
        Expect => undef,
    },
    {
        Name   => 'ObjectIconAdd(): invalid data - no ObjectID',
        Data   => {
            Object      => 'object1',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
            UserID      => 1,
        },
        Expect => undef,
    },
    {
        Name   => 'ObjectIconAdd(): invalid data - no ContentType',
        Data   => {
            Object      => 'object1',
            ObjectID    => 'objectid1',
            Content     => $SVGContent,
            UserID      => 1,
        },
        Expect => undef,
    },
    {
        Name   => 'ObjectIconAdd(): invalid data - no Content',
        Data   => {
            Object      => 'object1',
            ObjectID    => 'objectid1',
            ContentType => 'image/svg+xml',
            UserID      => 1,
        },
        Expect => undef,
    },
    {
        Name   => 'ObjectIconAdd(): invalid data - no UserID',
        Data   => {
            Object      => 'object1',
            ObjectID    => 'objectid1',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
        },
        Expect => undef,
    },
    {
        Name   => 'ObjectIconAdd(): valid data',
        Data   => {
            Object      => 'object1',
            ObjectID    => 'objectid1',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
            UserID      => 1,
        },
        Expect => {
            Object      => 'object1',
            ObjectID    => 'objectid1',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
        },
    },
    {
        Name   => 'ObjectIconAdd(): valid data',
        Data   => {
            Object      => 'object1',
            ObjectID    => 'objectid2',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
            UserID      => 1,
        },
        Expect => {
            Object      => 'object1',
            ObjectID    => 'objectid2',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
        },
    },
    {
        Name   => 'ObjectIconAdd(): valid data',
        Data   => {
            Object      => 'object2',
            ObjectID    => 'objectid1',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
            UserID      => 1,
        },
        Expect => {
            Object      => 'object2',
            ObjectID    => 'objectid1',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
        },
    },
);

my %ObjectIconIDs;

TEST:
foreach my $Test ( @CreateTests ) {
    my $ObjectIconID = $ObjectIconObject->ObjectIconAdd(
        %{$Test->{Data}},
        Content => $Test->{Data}->{Content} ? MIME::Base64::encode_base64($Test->{Data}->{Content}) : undef
    );

    if ( !$Test->{Expect} ) {
        $Self->False(
          $ObjectIconID,
          $Test->{Name},
        );
        next TEST;
    }

    $Self->True(
        $ObjectIconID,
        $Test->{Name},
    );

    # save ID for later
    $ObjectIconIDs{$Test->{Data}->{Object} . '-' . $Test->{Data}->{ObjectID}} = $ObjectIconID;

    my %ObjectIcon = $ObjectIconObject->ObjectIconGet(
        ID => $ObjectIconID,
    );

    if ( IsHashRefWithData($Test->{Expect}) ) {
        $Test->{Expect}->{Content} = MIME::Base64::encode_base64($Test->{Expect}->{Content});

        foreach my $Attr ( sort keys %{$Test->{Expect}}) {
            $Self->Is(
                $ObjectIcon{$Attr},
                $Test->{Expect}->{$Attr},
                $Test->{Name} . ' - ' . $Attr,
            );
        }

        # check FS
        my $Content = $Kernel::OM->Get('Main')->FileRead(
            Directory => $ObjectIconObject->{Config}->{Directory},
            Filename  => $ObjectIconIDs{"$Test->{Expect}->{Object}-$Test->{Expect}->{ObjectID}"},
        );
        $Self->Is(
            $$Content,
            $SVGContent,
            $Test->{Name} . ' - FS sync',
        );
    }
}

my @UpdateTests = (
    {
        Name   => 'ObjectIconUpdate(): invalid data - no data',
        Data   => {},
        Expect => undef,
    },
    {
        Name   => 'ObjectIconUpdate(): invalid data - no ID',
        Data   => {
            Object      => 'object1',
            ObjectID    => 'objectid1',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
            UserID      => 1,
        },
        Expect => undef,
    },
    {
        Name   => 'ObjectIconUpdate(): invalid data - non existent ID',
        Data   => {
            ID          => 999999,
            Object      => 'object1',
            ObjectID    => 'objectid1',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
            UserID      => 1,
        },
        Expect => undef,
    },
    {
        Name   => 'ObjectIconUpdate(): invalid data - no Object',
        Data   => {
            ID          => $ObjectIconIDs{'object1-objectid1'},
            ObjectID    => 'objectid1',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
            UserID      => 1,
        },
        Expect => undef,
    },
    {
        Name   => 'ObjectIconUpdate(): invalid data - no ObjectID',
        Data   => {
            ID          => $ObjectIconIDs{'object1-objectid1'},
            Object      => 'object1',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
            UserID      => 1,
        },
        Expect => undef,
    },
    {
        Name   => 'ObjectIconUpdate(): invalid data - no ContentType',
        Data   => {
            ID          => $ObjectIconIDs{'object1-objectid1'},
            Object      => 'object1',
            ObjectID    => 'objectid1',
            Content     => $SVGContent,
            UserID      => 1,
        },
        Expect => undef,
    },
    {
        Name   => 'ObjectIconUpdate(): invalid data - no Content',
        Data   => {
            ID          => $ObjectIconIDs{'object1-objectid1'},
            Object      => 'object1',
            ObjectID    => 'objectid1',
            ContentType => 'image/svg+xml',
            UserID      => 1,
        },
        Expect => undef,
    },
    {
        Name   => 'ObjectIconUpdate(): invalid data - no UserID',
        Data   => {
            ID          => $ObjectIconIDs{'object1-objectid1'},
            Object      => 'object1',
            ObjectID    => 'objectid1',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
        },
        Expect => undef,
    },
    {
        Name   => 'ObjectIconUpdate(): change Object',
        Data   => {
            ID          => $ObjectIconIDs{'object1-objectid1'},
            Object      => 'object3',
            ObjectID    => 'objectid1',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
            UserID      => 1,
        },
        Expect => {
            Object      => 'object3',
            ObjectID    => 'objectid1',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
        },
    },
    {
        Name   => 'ObjectIconUpdate(): change ObjectID',
        Data   => {
            ID          => $ObjectIconIDs{'object1-objectid1'},
            Object      => 'object3',
            ObjectID    => 'objectid3',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
            UserID      => 1,
        },
        Expect => {
            Object      => 'object3',
            ObjectID    => 'objectid3',
            ContentType => 'image/svg+xml',
            Content     => $SVGContent,
        },
    },
    {
        Name   => 'ObjectIconUpdate(): change ContentType',
        Data   => {
            ID          => $ObjectIconIDs{'object1-objectid1'},
            Object      => 'object3',
            ObjectID    => 'objectid3',
            ContentType => 'image/png',
            Content     => $SVGContent,
            UserID      => 1,
        },
        Expect => {
            Object      => 'object3',
            ObjectID    => 'objectid3',
            ContentType => 'image/png',
            Content     => $SVGContent,
        },
    },
    {
        Name   => 'ObjectIconUpdate(): change Content',
        Data   => {
            ID          => $ObjectIconIDs{'object1-objectid1'},
            Object      => 'object3',
            ObjectID    => 'objectid3',
            ContentType => 'image/png',
            Content     => $SVGContent_Update,
            UserID      => 1,
        },
        Expect => {
            Object      => 'object3',
            ObjectID    => 'objectid3',
            ContentType => 'image/png',
            Content     => $SVGContent_Update,
        },
    },
    {
        Name   => 'ObjectIconUpdate(): change ContentType to non image',
        Data   => {
            ID          => $ObjectIconIDs{'object1-objectid1'},
            Object      => 'object3',
            ObjectID    => 'objectid3',
            ContentType => 'text',
            Content     => $SVGContent_Update,
            UserID      => 1,
        },
        Expect => {
            Object      => 'object3',
            ObjectID    => 'objectid3',
            ContentType => 'text',
            Content     => $SVGContent_Update,
        },
    },
);

TEST:
foreach my $Test ( @UpdateTests ) {

    my %ObjectIconOld;
    if ( $Test->{Expect} ) {
        %ObjectIconOld = $ObjectIconObject->ObjectIconGet(
            ID => $Test->{Data}->{ID},
        );
    }

    my $Success = $ObjectIconObject->ObjectIconUpdate(
        %{$Test->{Data}},
        Content => $Test->{Data}->{Content} ? MIME::Base64::encode_base64($Test->{Data}->{Content}) : undef
    );

    if ( !$Test->{Expect} ) {
        $Self->False(
          $Success,
          $Test->{Name},
        );
        next TEST;
    }

    $Self->True(
        $Success,
        $Test->{Name},
    );

    my %ObjectIcon = $ObjectIconObject->ObjectIconGet(
        ID => $Test->{Data}->{ID},
    );

    if ( IsHashRefWithData($Test->{Expect}) ) {
        $Test->{Expect}->{Content} = MIME::Base64::encode_base64($Test->{Expect}->{Content});

        foreach my $Attr ( sort keys %{$Test->{Expect}}) {
            $Self->Is(
                $ObjectIcon{$Attr},
                $Test->{Expect}->{$Attr},
                $Test->{Name} . ' - ' . $Attr,
            );
        }

        # check FS
        if ( $ObjectIconObject->{Config}->{ContentTypeMapping}->{$Test->{Expect}->{ContentType}} ) {
            my $Content = $Kernel::OM->Get('Main')->FileRead(
                Directory => $ObjectIconObject->{Config}->{Directory},
                Filename  => $ObjectIconIDs{"$Test->{Expect}->{Object}-$Test->{Expect}->{ObjectID}"},
            );
            $Self->Is(
                $$Content,
                $Test->{Data}->{Content},
                $Test->{Name} . ' - FS sync :: file updated',
            );
        }
    }
}

my $IDs = $ObjectIconObject->ObjectIconList();

$Self->IsDeeply(
    $IDs,
    [
        @ObjectIconIDListOrg,
        $ObjectIconIDs{'object1-objectid1'},
        $ObjectIconIDs{'object1-objectid2'},
        $ObjectIconIDs{'object2-objectid1'},
    ],
    'ObjectIconList()',
);

$IDs = $ObjectIconObject->ObjectIconList(
    Object => 'object2',
);

$Self->IsDeeply(
    $IDs,
    [
        $ObjectIconIDs{'object2-objectid1'},
    ],
    'ObjectIconList() - object2',
);

$IDs = $ObjectIconObject->ObjectIconList(
    ObjectID => 'objectid2',
);

$Self->IsDeeply(
    $IDs,
    [
        $ObjectIconIDs{'object1-objectid2'},
    ],
    'ObjectIconList() - objectid2',
);

$IDs = $ObjectIconObject->ObjectIconList(
    Object => 'object1',
    ObjectID => 'objectid1',
);

$Self->IsDeeply(
    $IDs,
    [],
    'ObjectIconList() - object1 + objectid2',
);

$IDs = $ObjectIconObject->ObjectIconList(
    Object => 'object2',
    ObjectID => 'objectid1',
);

$Self->IsDeeply(
    $IDs,
    [
        $ObjectIconIDs{'object2-objectid1'},
    ],
    'ObjectIconList() - object1 + objectid2',
);

my $Success = $ObjectIconObject->ObjectIconDelete(
    ID     => $ObjectIconIDs{'object1-objectid2'},
    UserID => 1,
);

$Self->True(
    $Success,
    'ObjectIconDelete() - existing ID',
);

$IDs = $ObjectIconObject->ObjectIconList(
    Object => 'object2',
    ObjectID => 'objectid1',
);

$Self->IsDeeply(
    $IDs,
    [
        $ObjectIconIDs{'object2-objectid1'},
    ],
    'ObjectIconList() after delete - object1 + objectid2',
);

my $Content = $Kernel::OM->Get('Main')->FileRead(
    Directory => $ObjectIconObject->{Config}->{Directory},
    Filename  => "object1_objectid2.svg",
);
$Self->False(
    $Content,
    'ObjectIconDelete() - removed file in FS',
);

$Success = $ObjectIconObject->ObjectIconDelete(
    ID => $ObjectIconIDs{'object1-objectid1'},
);

$Self->False(
    $Success,
    'ObjectIconDelete() - existing ID but without UserID',
);

$Success = $ObjectIconObject->ObjectIconDelete(
    ID     => 999999,
    UserID => 1,
);

$Self->False(
    $Success,
    'ObjectIconDelete() - non-existing ID',
);

# rollback transaction on database
$Helper->Rollback();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
