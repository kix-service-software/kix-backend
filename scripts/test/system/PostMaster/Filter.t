# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get priority object
my $FilterObject = $Kernel::OM->Get('PostMaster::Filter');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# general tests for Filter
my @Tests = (
    {
        Filter => {
            Name           => 'first filter',
            StopAfterMatch => 1,
            ValidID        => 1,
            UserID         => 1,
            Comment        => 'first filter - comment',
            Match          => {
                From    => 'email@example.com',
                Subject => 'Test subject'
            },
            Set => {
                'X-KIX-Queue' => 'Some::Queue'
            },
            Not => {
                From => 1
            },
        },
        Name => 'First Filter Test - '
    },
    {
        Filter => {
            Name           => 'second filter',
            StopAfterMatch => 0,
            ValidID        => 2,
            UserID         => 1,
            Comment        => 'second filter - comment',
            Match          => {
                From    => 'email2@example.com',
                Subject => 'Test subject 2'
            },
            Set => {
                'X-KIX-Queue' => 'Some::Other::Queue'
            },
        },
        Name => 'Second Filter Test - '
    },
);

my %NewFilters;

TEST:
for my $Test (@Tests) {

    # test add
    my $FilterID = $FilterObject->FilterAdd(
        %{ $Test->{Filter} },
        UserID => 1
    );

    $Self->IsNot(
        $FilterID,
        '',
        $Test->{Name} . 'Add'
    ) || next TEST;

    # remember new filter
    $NewFilters{$FilterID} = $Test->{Filter}->{Name};

    # lookup ID
    my $LookupID = $FilterObject->FilterIDLookup(
        Name => $Test->{Filter}->{Name}
    );
    $Self->Is(
        $LookupID,
        $FilterID,
        $Test->{Name} . 'Lookup ID'
    ) || next TEST;

    # lookup name
    my $LookupName = $FilterObject->FilterNameLookup(
        ID => $FilterID,
    );
    $Self->Is(
        $LookupName,
        $Test->{Filter}->{Name},
        $Test->{Name} . 'Lookup name'
    ) || next TEST;

    # test get by ID
    my %ResultGet = $FilterObject->FilterGet(
        ID     => $FilterID,
        UserID => 1
    );
    $Self->Is(
        $ResultGet{ID},
        $FilterID,
        $Test->{Name} . 'Get filter by ID (ID)'
    ) || next TEST;
    $Self->Is(
        $ResultGet{ValidID},
        $Test->{Filter}->{ValidID},
        $Test->{Name} . 'Get filter by ID (ValidID)'
    ) || next TEST;
    $Self->Is(
        $ResultGet{Name},
        $Test->{Filter}->{Name},
        $Test->{Name} . 'Get filter by ID (Name)'
    ) || next TEST;
    $Self->Is(
        $ResultGet{StopAfterMatch},
        $Test->{Filter}->{StopAfterMatch},
        $Test->{Name} . 'Get filter by ID (StopAfterMatch)'
    ) || next TEST;
    $Self->Is(
        $ResultGet{Comment},
        $Test->{Filter}->{Comment},
        $Test->{Name} . 'Get filter by ID (Comment)'
    ) || next TEST;
    $Self->Is(
        $ResultGet{Match}->{From},
        $Test->{Filter}->{Match}->{From},
        $Test->{Name} . 'Get filter by ID (Match->From)'
    ) || next TEST;
    $Self->Is(
        $ResultGet{Set}->{'X-KIX-Queue'},
        $Test->{Filter}->{Set}->{'X-KIX-Queue'},
        $Test->{Name} . 'Get filter by ID (Set->Queue)'
    ) || next TEST;

    # test get by name
    %ResultGet = $FilterObject->FilterGet(
        Name   => $Test->{Filter}->{Name},
        UserID => 1
    );
    $Self->Is(
        $ResultGet{ID},
        $FilterID,
        $Test->{Name} . 'Get filter by Name (ID)'
    ) || next TEST;
    $Self->Is(
        $ResultGet{ValidID},
        $Test->{Filter}->{ValidID},
        $Test->{Name} . 'Get filter by Name (ValidID)'
    ) || next TEST;
    $Self->Is(
        $ResultGet{Name},
        $Test->{Filter}->{Name},
        $Test->{Name} . 'Get filter by Name (Name)'
    ) || next TEST;

    # test update
    my $NewName           = $Test->{Filter}->{Name} . ' - update';
    my $NewComment        = 'new comment';
    my $NewStopAfterMatch = $Test->{Filter}->{StopAfterMatch} ? 0 : 1;
    my $NewMatch          = {
        To => 'soem-email@example.com'
    };
    my $UpdateFilterID = $FilterObject->FilterUpdate(
        %{ $Test->{Filter} },
        ID             => $FilterID,
        Name           => $NewName,
        Comment        => $NewComment,
        StopAfterMatch => $NewStopAfterMatch,
        Match          => $NewMatch,
        ValidID        => 3,
        UserID         => 1
    );

    $Self->Is(
        $UpdateFilterID,
        $FilterID,
        $Test->{Name} . 'Update'
    ) || next TEST;

    my %UpdatedFilter = $FilterObject->FilterGet(
        ID     => $FilterID,
        UserID => 1
    );

    $Self->Is(
        $UpdatedFilter{Name},
        $NewName,
        $Test->{Name} . 'Update (Name)'
    ) || next TEST;
    $Self->Is(
        $UpdatedFilter{ValidID},
        3,
        $Test->{Name} . 'Update (ValidID)'
    ) || next TEST;
    $Self->Is(
        $UpdatedFilter{Comment},
        $NewComment,
        $Test->{Name} . 'Update (ValidID)'
    ) || next TEST;
    $Self->Is(
        $UpdatedFilter{StopAfterMatch},
        $NewStopAfterMatch,
        $Test->{Name} . 'Update (StopAfterMatch)'
    ) || next TEST;
    $Self->IsDeeply(
        $UpdatedFilter{Match},
        $NewMatch,
        $Test->{Name} . 'Update (Match)'
    ) || next TEST;

    $NewFilters{$FilterID} = $NewName;
}

# List tests
my %FilterList = $FilterObject->FilterList( Valid => 0 );
$Self->True( scalar( keys %FilterList ) >= 2, 'List - length' );
for my $NewFilterID ( keys %NewFilters ) {
    my $Found = $Self->_inList(
        Find => $NewFilterID,
        List => \%FilterList
    );
    $Self->True( $Found, 'List - new filter in list' );
}

# get only valid filters
$FilterObject->FilterUpdate(
    %{ $Tests[0]->{Filter} },
    ID      => [ keys %NewFilters ]->[0],
    ValidID => 1,
    UserID  => 1
);
my %ValidFilterList = $FilterObject->FilterList( Valid => 1 );
my $FoundFirst = $Self->_inList(
    Find => [ keys %NewFilters ]->[0],
    List => \%ValidFilterList
);
$Self->True( $FoundFirst, 'List - new valid filter in list' );
my $FoundSecond = $Self->_inList(
    Find => [ keys %NewFilters ]->[1],
    List => \%ValidFilterList
);
$Self->False( $FoundSecond, 'List - new invalid filter not in list' );

# delete filter
$FilterObject->FilterDelete(
    ID     => [ keys %NewFilters ]->[0],
    UserID => 1
);
my %FilterListAfterDelete = $FilterObject->FilterList( Valid => 0 );
my $FoundDelete = $Self->_inList(
    Find => [ keys %NewFilters ]->[0],
    List => \%FilterListAfterDelete
);
$Self->False( $FoundDelete, 'List - deleted filter not in ist' );

# specialtest - update with invalid name
my $UpdateID = $FilterObject->FilterUpdate(
    %{ $Tests[1]->{Filter} },
    ID     => [ keys %NewFilters ]->[1],
    Name   => '',
    UserID => 1,
    Silent => 1,
);
$Self->False( $UpdateID, 'Update with invalid name' );

# rollback transaction on database
$Helper->Rollback();

sub _inList {
    my ( $Self, %Param ) = @_;
    my $Found = 0;
    for my $FilterListID ( keys %{ $Param{List} } ) {
        if ( $FilterListID == $Param{Find} ) {
            $Found = 1;
            last;
        }
    }
    return $Found;
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
