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
        LogPrefix => 'framework_update-to-build-2298',
    },
);

use vars qw(%INC);

# convert email preference 
_UpdateCertificatePreferences();

sub _UpdateCertificatePreferences {
    my ( $Self, %Param ) = @_;

    my @Certificates = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Certificate',
        Result     => 'ARRAY',
        Search     => {
            AND => [
                {
                    Field    => 'Email',
                    Operator => 'CONTAINS',
                    Value    => ','
                }
            ]
        },
        UserID   => 1,
        UserType => 'Agent'
    );
    
    for my $CertificateID ( @Certificates ) {
        my $Certificate = $Kernel::OM->Get('Certificate')->CertificateGet(
            ID => $CertificateID
        );

        my $PreferenceKey = 'Email';
        my @Emails = split( ', ', $Certificate->{Email} );

        return if !$Kernel::OM->Get('DB')->Do(
            SQL => 'DELETE FROM virtual_fs_preferences WHERE virtual_fs_id=? AND preferences_key=?',
            Bind => [ \$Certificate->{FileID}, \ $PreferenceKey ],
        );

        for my $Email ( @Emails ) {
            return if !$Kernel::OM->Get('DB')->Do(
                SQL => <<'END',
INSERT INTO virtual_fs_preferences
    (virtual_fs_id, preferences_key, preferences_value)
VALUES ( ?, ?, ?)
END
                Bind => [ \$Certificate->{FileID}, \$PreferenceKey, \$Email ],
            );
        }
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
