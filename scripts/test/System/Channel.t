# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get ChannelLanguage object
my $ChannelObject = $Kernel::OM->Get('Kernel::System::Channel');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
