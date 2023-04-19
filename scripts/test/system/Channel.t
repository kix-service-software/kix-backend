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

use vars (qw($Self));

# get ChannelLanguage object
my $ChannelObject = $Kernel::OM->Get('Channel');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# get existing channel by using the id
my %ChannelData = $ChannelObject->ChannelGet( ID => 1 );

$Self->Is(
    $ChannelData{Name} || '',
    'note',
    'ChannelGet() - Name (using the ID)',
);

# get non-existent channel by using the id
%ChannelData = $ChannelObject->ChannelGet( ID => 9999 );

$Self->Is(
    $ChannelData{ID},
    undef,
    'ChannelGet() - Name (using non-existent ID)',
);

# lookup existent channel using ID
my $ChannelNameExists = $ChannelObject->ChannelLookup( ID => 1 );

$Self->Is(
    $ChannelNameExists,
    'note',
    'ChannelLookup() - using ID',
);

# lookup non-existent channel using name
my $ChannelNameNotExists = $ChannelObject->ChannelLookup( ID => 9999 );

$Self->False(
    $ChannelNameNotExists,
    'ChannelLookup() - using non-existent ID',
);

# lookup existent channel using name
my $ChannelIDExists = $ChannelObject->ChannelLookup( Name => 'note' );

$Self->Is(
    $ChannelIDExists,
    1,
    'ChannelLookup() - using name',
);

# lookup non-existent channel using name
my $ChannelIDNotExists = $ChannelObject->ChannelLookup( Name => 'note#invalid' );

$Self->False(
    $ChannelIDNotExists,
    'ChannelLookup() - using non-existent name',
);

my %ChannelList = $ChannelObject->ChannelList();

$Self->True(
    exists $ChannelList{1} && $ChannelList{1} eq 'note',
    'ChannelList() contains the channel note with ID 1',
);

# cleanup is done by RestoreDatabase.

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
