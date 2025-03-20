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

use vars (qw($Self));

use Kernel::System::ObjectManager;

local $Kernel::OM = Kernel::System::ObjectManager->new(
    'PostMaster' => {
        Email => [],
    },
);

$Self->True( $Kernel::OM, 'Could build object manager' );

# get needed object
my $MainObject   = $Kernel::OM->Get('Main');
my $ConfigObject = $Kernel::OM->Get('Config');

my $Home = $ConfigObject->Get('Home');

my %SkipModules;
if ( !$MainObject->Require('SLA', Silent => 1) ) {
    $SkipModules{SLA} = {
        $Home. "/Kernel/System/Automation/MacroAction/Ticket/StateSet.pm" => 1
    };
}
if ( !$MainObject->Require('DFAttachment', Silent => 1) ) {
    $SkipModules{DFAttachment} = {
        $Home. "/Kernel/System/Ticket/Event/NotificationEvent/Transport/Email.pm" => 1
    };
}

my %OperationChecked;
my @DirectoriesToSearch = (
    '/bin',
    '/Kernel/API',
    '/Kernel/Output',
    '/Kernel/System',
    '/var/packagesetup',
);

for my $Directory ( sort @DirectoriesToSearch ) {
    my @FilesInDirectory = $MainObject->DirectoryRead(
        Directory => $Home . $Directory,
        Filter    => [ '*.pm', '*.pl' ],
        Recursive => 1,
    );

    LOCATION:
    for my $Location (@FilesInDirectory) {

        my $ContentSCALARRef = $MainObject->FileRead(
            Location => $Location,
        );

        my $Module = $Location;
        $Module =~ s{$Home\/+}{}msx;

        # check if file contains a call to another module using Object manager
        #    for example: $Kernel::OM->Get('Config')->Get('Home');
        #    the regular expression will match until $Kernel::OM->Get('Config')->Get(
        #    including possible line returns
        #    for this example:
        #    $1 will contain Kernel::Config
        #    $2 will contain Get
        OPERATION:
        while (
            ${$ContentSCALARRef} =~ m{ \$Kernel::OM \s* -> \s* Get\( \s* '([^']+)'\) \s* -> \s* ([a-zA-Z1-9]+)\( }msxg
        ) {

            # skip if the function for the object was already checked before
            next OPERATION if $OperationChecked{"$1->$2()"};
            next OPERATION if $SkipModules{$1}->{$Location};

            # load object
            my $Object = $Kernel::OM->Get("$1");

            my $Success = $Object->can($2);

            $Self->True(
                $Success,
                "$Module | $1->$2()",
            );

            # remember the already checked operation
            $OperationChecked{"$1->$2()"} = 1;
        }
    }
}

# cleanup cache
$Kernel::OM->Get('Cache')->CleanUp();

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
