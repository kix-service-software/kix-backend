# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $ObjectTagModule = 'Kernel::System::ObjectTag';

# require module
return if ( !$Kernel::OM->Get('Main')->Require( $ObjectTagModule ) );

# create backend object
my $ObjectTagObject = $ObjectTagModule->new( %{ $Self } );
$Self->Is(
    ref( $ObjectTagObject ),
    $ObjectTagModule,
    'ObjectTag object has correct module ref'
);

# check supported methods
for my $Method ( qw(
        ObjectTagGet ObjectTagExists
        ObjectTagAdd ObjectTagDelete
    )
) {
    $Self->True(
        $ObjectTagObject->can($Method),
        'ObjectTag object can "' . $Method . '"'
    );
}

# begin transaction on database
$Helper->BeginWork();

# init fixed time
my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2025-03-14 17:00:00',
);
$Helper->FixedTimeSet($SystemTime);

my @Tests = (
    {
        Name     => 'ObjectTagAdd | no Params | Return undef',
        Function => 'ObjectTagAdd',
        Data     => {
            Silent => 1
        },
        ResultAs => 'False'
    },
    {
        Name     => 'ObjectTagAdd | no Name | Return undef',
        Function => 'ObjectTagAdd',
        Data     => {
            ObjectID   => 1,
            ObjectType => 'UnitTest',
            UserID     => 1,
            Silent     => 1
        },
        ResultAs => 'False'
    },
    {
        Name     => 'ObjectTagAdd | no ObjectType | Return undef',
        Function => 'ObjectTagAdd',
        Data     => {
            Name       => 'test',
            ObjectID   => 1,
            UserID     => 1,
            Silent     => 1
        },
        ResultAs => 'False'
    },
    {
        Name     => 'ObjectTagAdd | no ObjectID | Return undef',
        Function => 'ObjectTagAdd',
        Data     => {
            Name       => 'test',
            ObjectType => 'UnitTest',
            UserID     => 1,
            Silent     => 1
        },
        ResultAs => 'False'
    },
    {
        Name     => 'ObjectTagAdd | no UserID | Return undef',
        Function => 'ObjectTagAdd',
        Data     => {
            Name       => 'test',
            ObjectID   => 1,
            ObjectType => 'UnitTest',
            Silent     => 1
        },
        ResultAs => 'False'
    },
    {
        Name     => 'ObjectTagAdd | Name: test, ObjectType: UnitTest, ObjectID: 1 | Return ID',
        Function => 'ObjectTagAdd',
        Data     => {
            Name       => 'test',
            ObjectID   => 1,
            ObjectType => 'UnitTest',
            UserID     => 1
        },
        ResultAs        => 'True',
        SaveResult      => 'ID_0',
        SetFixedTime    => '-86400',
        UnsetFixedTime  => '86400'
    },
    {
        Name     => 'ObjectTagAdd | Name: test, ObjectType: UnitTest, ObjectID: 1 | Repeated | Return same ID',
        Function => 'ObjectTagAdd',
        Data     => {
            Name       => 'test',
            ObjectID   => 1,
            ObjectType => 'UnitTest',
            UserID     => 1
        },
        ResultAs => 'Is',
        Expect   => '###ID_0###'
    },
    {
        Name     => 'ObjectTagAdd | Name: test, ObjectType: UnitTest, ObjectID: 2 |  Return same ID',
        Function => 'ObjectTagAdd',
        Data     => {
            Name       => 'test',
            ObjectID   => 2,
            ObjectType => 'UnitTest',
            UserID     => 1
        },
        SaveResult => 'ID_1',
        ResultAs   => 'True'
    },
    {
        Name     => 'ObjectTagExists | no Params |  Return undef',
        Function => 'ObjectTagExists',
        Data     => {
            Silent     => 1
        },
        ResultAs => 'False',
        Expect   => 1
    },
    {
        Name     => 'ObjectTagExists | no Name |  Return undef',
        Function => 'ObjectTagExists',
        Data     => {
            ObjectType => 'UnitTest',
            ObjectID   => 1,
            Silent     => 1
        },
        ResultAs => 'False',
        Expect   => 1
    },
    {
        Name     => 'ObjectTagExists | no ObjectType |  Return undef',
        Function => 'ObjectTagExists',
        Data     => {
            Name       => 'test',
            ObjectID   => 1,
            Silent     => 1
        },
        ResultAs => 'False'
    },
    {
        Name     => 'ObjectTagExists | no ObjectID |  Return undef',
        Function => 'ObjectTagExists',
        Data     => {
            Name       => 'test',
            ObjectType => 'UnitTest',
            Silent     => 1
        },
        ResultAs => 'False'
    },
    {
        Name     => 'ObjectTagExists | Name: test, ObjectType: UnitTest, ObjectID: 4 |  Return undef',
        Function => 'ObjectTagExists',
        Data     => {
            Name       => 'test',
            ObjectType => 'UnitTest',
            ObjectID   => 4

        },
        ResultAs => 'False'
    },
    {
        Name     => 'ObjectTagExists | Name: test, ObjectType: UnitTest, ObjectID: 1 |  Return ID',
        Function => 'ObjectTagExists',
        Data     => {
            Name       => 'test',
            ObjectType => 'UnitTest',
            ObjectID   => 1

        },
        ResultAs => 'Is',
        Expect   => '###ID_0###'
    },
    {
        Name     => 'ObjectTagExists | Name: test, ObjectType: UnitTest, ObjectID: 2 |  Return ID',
        Function => 'ObjectTagExists',
        Data     => {
            Name       => 'test',
            ObjectType => 'UnitTest',
            ObjectID   => 2

        },
        ResultAs => 'Is',
        Expect   => '###ID_1###'
    },
    {
        Name     => 'ObjectTagGet | no ID |  Return undef',
        Function => 'ObjectTagGet',
        Data     => {
            Silent => 1
        },
        ResultAs => 'False'
    },
    {
        Name     => 'ObjectTagGet | ID: 4 |  Return undef',
        Function => 'ObjectTagGet',
        Data     => {
            ID     => 4,
            Silent => 1
        },
        ResultAs => 'False'
    },
    {
        Name     => 'ObjectTagGet | ID: 1 |  Return object hash',
        Function => 'ObjectTagGet',
        Data     => {
            ID => '###ID_0###'

        },
        ResultAs => 'HASH',
        Expect   => {
            ID         => '###ID_0###',
            Name       => 'test',
            ObjectID   => 1,
            ObjectType => 'UnitTest',
            CreateTime => '2025-03-13 17:00:00',
            CreateBy   => 1,
            ChangeTime => '2025-03-13 17:00:00',
            ChangeBy   => 1
        }
    },
    {
        Name     => 'ObjectTagGet | ID: 2 |  Return object hash',
        Function => 'ObjectTagGet',
        Data     => {
            ID => '###ID_1###'
        },
        ResultAs => 'HASH',
        Expect   => {
            ID         => '###ID_1###',
            Name       => 'test',
            ObjectID   => 2,
            ObjectType => 'UnitTest',
            CreateTime => '2025-03-14 17:00:00',
            CreateBy   => 1,
            ChangeTime => '2025-03-14 17:00:00',
            ChangeBy   => 1
        }
    }
);

my %Saved;
for my $Test ( @Tests ) {

    if ( $Test->{SetFixedTime} ) {
        $Helper->FixedTimeAddSeconds($Test->{SetFixedTime});
    }

    my $Function = $Test->{Function};
    if ( $Test->{Function} eq 'ObjectTagGet' ) {
        if (
            defined $Test->{Data}->{ID}
            && $Test->{Data}->{ID} =~ /###(.*)###/sm
        ) {
            $Test->{Data}->{ID} = $Saved{$1};
        }
        if (
            defined $Test->{Expect}->{ID}
            && $Test->{Expect}->{ID} =~ /###(.*)###/sm
        ) {
            $Test->{Expect}->{ID} = $Saved{$1};
        }
    }

    my $Result = $ObjectTagObject->$Function(
        %{$Test->{Data}}
    );

    if ( $Test->{SaveResult} ) {
        $Saved{$Test->{SaveResult}} = $Result;
    }

    if ( $Test->{ResultAs} eq 'HASH' ) {
        $Self->IsDeeply(
            $Result,
            $Test->{Expect},
            $Test->{Name}
        );
    }
    elsif ( $Test->{ResultAs} eq 'False' ) {
        $Self->False(
            $Result,
            $Test->{Name}
        );
    }
    elsif ( $Test->{ResultAs} eq 'True' ) {
        $Self->True(
            $Result,
            $Test->{Name}
        );
    } else {
        my $Expect = $Test->{Expect};
        if ( $Test->{Expect} =~ /###(.*)###/sm ) {
            $Expect = $Saved{$1};
        }

        $Self->Is(
            $Result,
            $Expect,
            $Test->{Name}
        );
    }

    if ( $Test->{UnsetFixedTime} ) {
        $Helper->FixedTimeAddSeconds($Test->{UnsetFixedTime});
    }
}

# Delete Tests
# generate some tag entries

my @Tags = (
    {
        Name       => 'delete',
        ObjectType => 'DelUnitTest',
        ObjectID   => 1,
        UserID     => 1
    },
    {
        Name       => 'deletebyname',
        ObjectType => 'DelUnitTest',
        ObjectID   => 2,
        UserID     => 1
    },
    {
        Name       => 'delete',
        ObjectType => 'DelUnitTest',
        ObjectID   => 3,
        UserID     => 1
    },
    {
        Name       => 'delete',
        ObjectType => 'DelUnitTest',
        ObjectID   => 4,
        UserID     => 1
    },
    {
        Name       => 'deletebyid',
        ObjectType => 'DelUnitTest',
        ObjectID   => 5,
        UserID     => 1
    }
);

my @IDList;
for my $Data ( @Tags ) {
    my $ID = $ObjectTagObject->ObjectTagAdd(
        %{$Data}
    );

    $Self->True(
        $ID,
        "ObjectTagAdd | For Delete | Name:$Data->{Name}, ObjectType:$Data->{ObjectType}, ObjectID:$Data->{ObjectID} | Return ID"
    );

    last if !$ID;
    push( @IDList, $ID );
}

my @DeleteTests = (
    {
        Name     => 'ObjectTagDelete | no Params |  Return undef',
        Data     => {
            Silent => 1
        },
        Expect   => undef
    },
    {
        Name     => 'ObjectTagDelete | ObjectID: 1, no ObjectType |  Return undef',
        Data     => {
            Silent   => 1,
            ObjectID => 1
        },
        Expect   => undef
    },
    {
        Name     => 'ObjectTagDelete | invalid Param |  Return undef',
        Data     => {
            Silent => 1,
            Test   => 1
        },
        Expect   => undef
    },
    {
        Name     => "ObjectTagDelete | ID: $IDList[4] | Return 1",
        Data     => {
            ID => $IDList[4]
        },
        PostData => [
            $Tags[4]
        ],
        Expect   => 1
    },
    {
        Name     => 'ObjectTagDelete | Name: deletebyname |  Return 1',
        Data     => {
            Name => 'deletebyname'
        },
        PostData => [
            $Tags[1]
        ],
        Expect   => 1
    },
    {
        Name     => 'ObjectTagDelete | ObjectID: 3, ObjectType: DelUnitTest |  Return 1',
        Data     => {
            ObjectType => 'DelUnitTest',
            ObjectID   => 3
        },
        PostData => [
            $Tags[2]
        ],
        Expect   => 1
    },
    {
        Name     => 'ObjectTagDelete | ObjectType: DelUnitTest |  Return 1',
        Data     => {
            ObjectType => 'DelUnitTest',
        },
        PostData => [
            $Tags[0],
            $Tags[3]
        ],
        Expect   => 1
    }
);

for my $Test ( @DeleteTests ) {
    my $Result = $ObjectTagObject->ObjectTagDelete(
        %{$Test->{Data}}
    );

    $Self->Is(
        $Result,
        $Test->{Expect},
        $Test->{Name}
    );

    if ( IsArrayRefWithData($Test->{PostData}) ) {
        for my $SubTest ( @{ $Test->{PostData} } ) {
            my $SubResult = $ObjectTagObject->ObjectTagExists(
                %{$SubTest}
            );

            $Self->False(
                $SubResult,
                "ObjectTagDelete | Post exists check | Name: $SubTest->{Name}, ObjectType: $SubTest->{ObjectType}, ObjectID: $SubTest->{ObjectID} |  Return undef",
            );
        }
    }
}

# unset fixed time
$Helper->FixedTimeUnset();

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
