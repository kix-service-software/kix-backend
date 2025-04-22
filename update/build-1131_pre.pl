#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
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
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Getopt::Std;
use File::Path qw(mkpath);

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1131_pre',
    },
);
my $LogObject = $Kernel::OM->Get('Log');

use vars qw(%INC);

_FreeOrgIDOneAndAddMyOrga();

exit 0;

sub _FreeOrgIDOneAndAddMyOrga {
    my $DBObject = $Kernel::OM->Get('DB');
    my $OrgNumber;
    my $OrgName;
    my $NewOrgID;
    $LogObject->Log(
        Priority => "info",
        Message  => "Freeing ID 1 in table 'organisation'..."
    );
    return if !$DBObject->Prepare(
        SQL   => 'SELECT * FROM organisation WHERE id = 1',
        Limit => 1,
    );

    my @Orga = ();
    while (my @Row = $DBObject->FetchrowArray()) {
        for my $i (1..$#Row) {
            push @Orga, \$Row[$i];
        }
    }
    if (scalar @Orga > 0) {
        return if !$DBObject->Do(
            SQL => 'UPDATE organisation
                SET name = \'My Organisation\', number = \'MY_ORGA\', street = NULL, zip = NULL,
                    city = NULL, country = NULL, url = NULL, comments = NULL, valid_id = 1,
                    create_time = current_timestamp, create_by = 1, change_time = current_timestamp, change_by = 1
                WHERE id = 1'
        );

        return if !$DBObject->Do(
            SQL  => 'INSERT INTO organisation (number, name, street, zip, city, country, url, comments,
                          valid_id, create_time, create_by, change_time, change_by)
                 VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)',
            Bind => \@Orga
        );

        return if !$DBObject->Prepare(
            SQL   => 'SELECT id FROM organisation WHERE name = ? AND number = ?',
            Bind  => [ \$OrgName, \$OrgNumber ],
            Limit => 1,
        );

        while (my @Row = $DBObject->FetchrowArray()) {
            $NewOrgID = $Row[0];
        }
        return if !$DBObject->Do(
            SQL  => 'UPDATE ticket SET organisation_id = ? WHERE organisation_id = \'1\' ',
            Bind => [ \$NewOrgID ],
        );

        return if !$DBObject->Do(
            SQL  => 'UPDATE contact SET primary_org_id = ? WHERE primary_org_id = 1 ',
            Bind => [ \$NewOrgID ],
        );

        return if !$DBObject->Prepare(
            SQL => 'SELECT id, org_ids FROM contact WHERE org_ids LIKE \'%,1,%\'',
        );

        my @FetchedRowArray = ();
        while (my @Row = $DBObject->FetchrowArray()) {
            push(@FetchedRowArray, [ @Row ]);
        }

        foreach my $row (@FetchedRowArray) {
            my @Row = @{$row};
            my $UpdatedOrgIDs = $Row[1] =~ s/,1,/,$NewOrgID,/r;
            return if !$DBObject->Do(
                SQL  => "UPDATE contact SET org_ids = ? WHERE id = ? ",
                Bind => [ \$UpdatedOrgIDs, \$Row[0] ],
            );
        }

    }
    else {
        return if !$DBObject->Do(
            SQL  => 'INSERT INTO organisation (id, number, name, valid_id, create_time, create_by, change_time, change_by)
                     VALUES (1, \'MY_ORGA\', \'My Organisation\', 1, current_timestamp, 1, current_timestamp, 1)'
        );
    }
    $LogObject->Log(
        Priority => "info",
        Message  => "Done!"
    );

    return 1;
}

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
