#!/usr/bin/perl
# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin) . '/../../';
use lib dirname($RealBin) . '/../../Kernel/cpan-lib';

use Getopt::Std;
use File::Path qw(mkpath);

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'db-update-build-1131_pre.pl',
    },
);
my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

use vars qw(%INC);

_FreeOrgIDOneAndAddMyOrga();

exit 0;

sub _FreeOrgIDOneAndAddMyOrga {
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
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

    my @Orga;
    while (my @Row = $DBObject->FetchrowArray()) {
        for my $i (1..$#Row) {
            push @Orga, \$Row[$i];
        }
    }

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
        SQL  => 'UPDATE organisation_prefs SET org_id = ? WHERE org_id = 1',
        Bind => [ \$NewOrgID ],
    );

    return if !$DBObject->Do(
        SQL  => 'UPDATE ticket SET organisation_id = ? WHERE organisation_id = \'1\' ',
        Bind => [ \$NewOrgID ],
    );

    return if !$DBObject->Do(
        SQL  => 'UPDATE contact SET primary_org_id = ? WHERE primary_org_id = 1 ',
        Bind => [ \$NewOrgID ],
    );

    return if !$DBObject->Do(
        SQL  => "UPDATE contact SET org_ids = REPLACE(org_ids,',1,',CONCAT(',',CAST(? AS VARCHAR),',')) WHERE org_ids LIKE '%,1,%' ",
        Bind => [ \$NewOrgID ],
    );
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
