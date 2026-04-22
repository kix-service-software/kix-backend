#!/usr/bin/perl
# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . '/plugins';
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-2285',
    },
);

use vars qw(%INC);

# changed Createby of the flags smime,NotSent,RetryEncrypt to 1
_UpdateArticleFlags();

sub _UpdateArticleFlags {
    my ( $Self, %Param ) = @_;

    my @Flags  = qw(SMIMESignedError SMIMEEncryptedError NotSentError RetryEncrypt);
    my $UserID = 1 ;

    for my $Flag ( @Flags ) {

        $Kernel::OM->Get('DB')->Do(
            SQL => <<'END',
UPDATE article_flag
SET create_by = ?
WHERE article_key = ? AND create_by != ?
END
            Bind => [ \$UserID, \$Flag, \$UserID ]
        );
    }

    $Kernel::OM->Get('Cache')->CleanUp();

    return 1;
}

exit 0;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
