# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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

# get config object
my $ConfigObject = $Kernel::OM->Get('Config');

my $SkipCryptSMIME;
if ( !$ConfigObject->Get('SMIME') ) {
    $SkipCryptSMIME = 1;
}

my $SkipCryptPGP;
if ( !$ConfigObject->Get('PGP') ) {
    $SkipCryptPGP = 1;
}

my $SkipChat;
if ( !$ConfigObject->Get('ChatEngine::Active') ) {
    $SkipChat = 1;
}

my $SkipCalendar;
if ( !$Kernel::OM->Get('Main')->Require( 'Calendar', Silent => 1 ) ) {
    $SkipCalendar = 1;
}

my $SkipTeam;
if ( !$Kernel::OM->Get('Main')->Require( 'Calendar::Team', Silent => 1 ) ) {
    $SkipTeam = 1;
}

my $Home = $ConfigObject->Get('Home');

# get main object
my $MainObject = $Kernel::OM->Get('Main');

my %OperationChecked;

my @DirectoriesToSearch = (
    '/bin',
    '/Custom/Kernel/Output',
    '/Custom/Kernel/System',
    '/Kernel/GenericInterface',
    '/Kernel/Output',
    '/Kernel/System',
    '/var/packagesetup'
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
            ${$ContentSCALARRef}
            =~ m{ \$Kernel::OM \s* -> \s* Get\( \s* '([^']+)'\) \s* -> \s* ([a-zA-Z1-9]+)\( }msxg
            )
        {

            # skip if the function for the object was already checked before
            next OPERATION if $OperationChecked{"$1->$2()"};

            # skip crypt object if it is not configured
            next OPERATION if $1 eq 'Crypt::SMIME'          && $SkipCryptSMIME;
            next OPERATION if $1 eq 'Crypt::PGP'            && $SkipCryptPGP;
            next OPERATION if $1 eq 'Chat'                  && $SkipChat;
            next OPERATION if $1 eq 'ChatChannel'           && $SkipChat;
            next OPERATION if $1 eq 'VideoChat'             && $SkipChat;
            next OPERATION if $1 eq 'Calendar'              && $SkipCalendar;
            next OPERATION if $1 eq 'Calendar::Appointment' && $SkipCalendar;
            next OPERATION if $1 eq 'Calendar::Team'        && $SkipTeam;

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
