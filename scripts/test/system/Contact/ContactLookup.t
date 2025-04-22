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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# do not check mail addresses
$Kernel::OM->Get('Config')->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);
# disable unique check
$Kernel::OM->Get('Config')->Set(
    Key   => 'ContactEmailUniqueCheck',
    Value => 0,
);

my $ContactEmail = 'contact@lookup.com';
my $ContactEmailC = 'contactC@lookup.com';
my @Contacts = (
    {
        Name  => 'ContactLookupA',
        Email => $ContactEmail,
        Valid => 0
    },
    {
        Name => 'ContactLookupB',
        Email => $ContactEmail,
        Valid => 1
    },
    {
        Name => 'ContactLookupC',
        Email => $ContactEmailC,
        Valid => 1
    }
);
my $ContactsCreated = 0;

for my $Contact (@Contacts) {

    # add assigned user
    my $UserID = $Kernel::OM->Get('User')->UserAdd(
        UserLogin    => $Contact->{Name},
        ValidID      => 1,
        ChangeUserID => 1,
        IsAgent      => 1
    );
    $Self->True(
        $UserID,
        "ContactLookup: Assigned UserAdd() - $Contact->{Name}"
    );

    if ($UserID) {
        $Contact->{UserID} = $UserID;

        # add contact
        my $ContactID = $Kernel::OM->Get('Contact')->ContactAdd(
            AssignedUserID => $UserID,
            Firstname      => 'Firstname_' . $Contact->{Name},
            Lastname       => 'Lastname_' . $Contact->{Name},
            Email   => $Contact->{Email},
            ValidID => $Contact->{Valid} ? 1 : 2,
            UserID  => 1
        );
        $Self->True(
            $ContactID,
            "ContactLookup: ContactAdd() - $Contact->{Name}"
        );

        if ($ContactID) {
            $ContactsCreated++;
            $Contact->{ID} = $ContactID;
        }
    }
}

if (!$ContactsCreated || $ContactsCreated != 3) {
    $Self->True(
        0,
        "ContactLookup: Not all test contacts created!"
    );
}
else {
    my $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        ID     => $Contacts[0]->{ID},
        Silent => 1
    );
    $Self->Is(
        $Result,
        $Contacts[0]->{Email},
        'ContactLookup: lookup with ID (first contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        ID     => $Contacts[0]->{ID},
        Silent => 1,
        Valid  => 1 # first contact is invalid => should NOT be "found"
    );
    $Self->False(
        $Result,
        'ContactLookup: lookup with ID and Valid (first contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        ID     => $Contacts[1]->{ID},
        Silent => 1
    );
    $Self->Is(
        $Result,
        $Contacts[1]->{Email},
        'ContactLookup: lookup with ID (second contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        ID     => $Contacts[1]->{ID},
        Silent => 1,
        Valid  => 1 # second contact is valid => should be "found"
    );
    $Self->Is(
        $Result,
        $Contacts[1]->{Email},
        'ContactLookup: lookup with ID and Valid (second contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        ID     => $Contacts[2]->{ID},
        Silent => 1
    );
    $Self->Is(
        $Result,
        $Contacts[2]->{Email},
        'ContactLookup: lookup with ID (third contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        UserID => $Contacts[0]->{UserID},
        Silent => 1
    );
    $Self->Is(
        $Result,
        $Contacts[0]->{ID},
        'ContactLookup: lookup with UserID (first contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        UserID => $Contacts[0]->{UserID},
        Silent => 1,
        Valid  => 1 # first contact is invalid => should NOT be "found"
    );
    $Self->False(
        $Result,
        'ContactLookup: lookup with UserID and Valid (first contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        UserID => $Contacts[1]->{UserID},
        Silent => 1
    );
    $Self->Is(
        $Result,
        $Contacts[1]->{ID},
        'ContactLookup: lookup with UserID (second contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        UserID => $Contacts[1]->{UserID},
        Silent => 1,
        Valid  => 1 # second contact is valid => should be "found"
    );
    $Self->Is(
        $Result,
        $Contacts[1]->{ID},
        'ContactLookup: lookup with UserID and Valid (second contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        UserID => $Contacts[2]->{UserID},
        Silent => 1
    );
    $Self->Is(
        $Result,
        $Contacts[2]->{ID},
        'ContactLookup: lookup with UserID (third contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        UserLogin => $Contacts[0]->{Name},
        Silent    => 1
    );
    $Self->Is(
        $Result,
        $Contacts[0]->{ID},
        'ContactLookup: lookup with UserLogin (first contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        UserLogin => $Contacts[0]->{Name},
        Silent    => 1,
        Valid     => 1 # first contact is invalid => should NOT be "found"
    );
    $Self->False(
        $Result,
        'ContactLookup: lookup with UserLogin and Valid (first contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        UserLogin => $Contacts[1]->{Name},
        Silent    => 1
    );
    $Self->Is(
        $Result,
        $Contacts[1]->{ID},
        'ContactLookup: lookup with UserLogin (second contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        UserLogin => $Contacts[1]->{Name},
        Silent    => 1,
        Valid     => 1 # second contact is valid => should be "found"
    );
    $Self->Is(
        $Result,
        $Contacts[1]->{ID},
        'ContactLookup: lookup with UserLogin and Valid (second contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        UserLogin => $Contacts[2]->{Name},
        Silent    => 1
    );
    $Self->Is(
        $Result,
        $Contacts[2]->{ID},
        'ContactLookup: lookup with UserLogin (third contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        Email  => $Contacts[0]->{Email},
        Silent => 1
    );
    $Self->Is(
        $Result,
        $Contacts[0]->{ID},
        'ContactLookup: lookup with Email (first contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        Email  => $Contacts[1]->{Email},
        Silent => 1
    );
    $Self->Is(
        $Result,
        $Contacts[0]->{ID}, # ID of first contact, because both use same mail address
        'ContactLookup: lookup with Email (second contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        Email  => $Contacts[1]->{Email},
        Silent => 1,
        Valid  => 1  # ignore invalid (first) contact
    );
    $Self->Is(
        $Result,
        $Contacts[1]->{ID}, # should be ID of second contact this time
        'ContactLookup: lookup with Email and Valid (second contact)'
    );

    $Result = $Kernel::OM->Get('Contact')->ContactLookup(
        Email  => $Contacts[2]->{Email},
        Silent => 1
    );
    $Self->Is(
        $Result,
        $Contacts[2]->{ID},
        'ContactLookup: lookup with Email (third contact)'
    );
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
