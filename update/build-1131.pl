#!/usr/bin/perl
# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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
use Data::UUID;

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);
use Kernel::System::EmailParser;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1131',
    },
);
my $LogObject = $Kernel::OM->Get('Log');

use vars qw(%INC);

sub _SetAgents() {
    # get database object
    my $DBObject = $Kernel::OM->Get('DB');
    $LogObject->Log(
        Priority => "info",
        Message  => "Setting new agent flag for current agents..."
    );
    return if !$DBObject->Do(
        SQL => 'UPDATE users SET is_customer = 0, is_agent = 1',
    );
    $LogObject->Log(
        Priority => "info",
        Message  => "Done!"
    );
    return 1;
}

sub _MigrateUserInfoToContact() {
    my $DBObject = $Kernel::OM->Get('DB');
    $LogObject->Log(
        Priority => "info",
        Message  => "Migrating user info to table 'contact'..."
    );
    #migrate user info with the same email address as a contact
    return if !$DBObject->Prepare(
        SQL => 'SELECT c.id, u.* FROM users u JOIN contact c on LOWER(c.email) = LOWER(u.email)',
    );
    #  0 ContactID,
    #  1 id
    #  2 login
    #  3 pw
    #  4 title
    #  5 first_name
    #  6 last_name
    #  7 email
    #  8 phone
    #  9 mobile
    # 10 "comments"
    # 11 valid_id
    # 12 create_time
    # 13 create_by
    # 14 change_time
    # 15 change_by
    # 16 AssignedUserID
    my @FetchedRowArray = ();
    while (my @Row = $DBObject->FetchrowArray()) {
        push(@FetchedRowArray, [ @Row ]);
    }

    foreach my $row (@FetchedRowArray) {
        my @Row = @{$row};
        my $uuid = Data::UUID->new();
        my $DummyLogin = $uuid->to_hexstring($uuid->create());
        my $NewUserEmail = "noreply-" . $uuid->to_hexstring($uuid->create()) . '@nomail.com';
        my $OldUserEmailAsComment = "Old Mail before Migration: " . $Row[7];
        return if !$DBObject->Do(
            SQL  => 'INSERT INTO contact (login, email, primary_org_id, org_ids, title, firstname, lastname,
                     phone, mobile, comments, valid_id, create_time, create_by, change_time, change_by, user_id)
                     VALUES (?,?,1,\',1,\',?,?,?,?,?,?,?,?,?,?,?,?)',
            Bind => [ \$DummyLogin, \$NewUserEmail, \$Row[4], \$Row[5], \$Row[6], \$Row[8], \$Row[9], \$OldUserEmailAsComment,
                \$Row[11], \$Row[12], \$Row[13], \$Row[14], \$Row[15], \$Row[1]
            ]
        );
        $LogObject->Log(
            Priority => 'warning',
            Message  => "User ID '$Row[1]' has the same email address '$Row[7]' as contact ID '$Row[0]'. \n" .
                "Dummy unique email address was set to '$NewUserEmail' and old email address added as comment.",
        )
    }

    #migrate all other user info
    return if !$DBObject->Prepare(
        SQL => 'SELECT u.* FROM users u WHERE u.id NOT IN (SELECT DISTINCT(c.user_id) FROM contact c WHERE c.user_id IS NOT NULL)',
    );
    #  0 id
    #  1 login
    #  2 pw
    #  3 title
    #  4 first_name
    #  5 last_name
    #  6 email
    #  7 phone
    #  8 mobile
    #  9 "comments"
    # 10 valid_id
    # 11 create_time
    # 12 create_by
    # 13 change_time
    # 14 change_by
    # 15 AssignedUserID
    @FetchedRowArray = ();
    while (my @Row = $DBObject->FetchrowArray()) {
        push(@FetchedRowArray, [ @Row ]);
    }

    foreach my $row (@FetchedRowArray) {
        my @Row = @{$row};
        my $uuid = Data::UUID->new();
        my $DummyLogin = $uuid->to_hexstring($uuid->create()); #temporary workaround to ensure unique constraint on "login" and "login" not null
        return if !$DBObject->Do(
            SQL  => 'INSERT INTO contact (login, email, primary_org_id, org_ids, title, firstname, lastname,
                     phone, mobile, valid_id, create_time, create_by, change_time, change_by, user_id)
                     VALUES (?,?,1,\',1,\',?,?,?,?,?,?,?,?,?,?,?)',
            Bind => [ \$DummyLogin, \$Row[6], \$Row[3], \$Row[4], \$Row[5], \$Row[7], \$Row[8], \$Row[10], \$Row[11],
                \$Row[12], \$Row[13], \$Row[14], \$Row[0]
            ]
        );
    }
    $LogObject->Log(
        Priority => "info",
        Message  => "Done!"
    );
    return 1;
}

sub _MigrateContactInfoToUsers {
    #contact without an password are not migrated. they remain as a conact without an user.
    my $DBObject = $Kernel::OM->Get('DB');
    $LogObject->Log(
        Priority => "info",
        Message  => "Migrating contact login info into table 'users'..."
    );
    #migrate contacts with the same login as an user
    return if !$DBObject->Prepare(
        SQL => 'SELECT u.id, c.id, c.login, c.password, c.valid_id, c.create_time, c.create_by, c.change_time,
                c.change_by FROM users u JOIN contact c on LOWER(c.login) = LOWER(u.login) WHERE c.password IS NOT NULL',
    );
    # 0 UserID
    # 1 id
    # 2 login
    # 3 password
    # 4 valid_id
    # 5 create_time
    # 6 create_by
    # 7 change_time
    # 8 change_by
    my @FetchedRowArray = ();
    while (my @Row = $DBObject->FetchrowArray()) {
        push(@FetchedRowArray, [ @Row ]);
    }

    foreach my $row (@FetchedRowArray) {
        my @Row = @{$row};
        my $uuid = Data::UUID->new();
        my $NewUserLogin = $uuid->to_hexstring($uuid->create());
        my $OldContactLoginAsComment = "Old Login before Migration: " . $Row[2];
        return if !$DBObject->Do(
            SQL  => "INSERT INTO users (login, pw, comments, valid_id, create_time,  create_by, change_time, change_by,
                   is_customer, first_name,last_name,email) VALUES (?,?,?,?,?,?,?,?,0,'dummy','dummy','dummy')",
            Bind => [ \$NewUserLogin, \$Row[3], \$OldContactLoginAsComment, \$Row[4], \$Row[5], \$Row[6], \$Row[7],
                \$Row[8],
            ]
        );
        return if !$DBObject->Do(
            SQL  => 'UPDATE contact SET user_id = (SELECT id FROM users WHERE login = ? LIMIT 1) WHERE id = ?',
            Bind => [ \$NewUserLogin, \$Row[1] ]
        );
        $LogObject->Log(
            Priority => 'warning',
            Message  => "Contact ID '$Row[1]' has the same user login '$Row[2]' as user ID '$Row[0]'. \n" .
                "New user with dummy unique user login '$NewUserLogin' was created and old contact login added as comment.",
        );
    }
    #migrate contacts with different login as an user
    return if !$DBObject->Prepare(
        SQL => 'SELECT c.id, c.login, c.password, c.valid_id, c.create_time, c.create_by, c.change_time,
        c.change_by FROM contact c WHERE  c.login NOT IN (SELECT login FROM users) AND c.PASSWORD IS NOT NULL',
    );
    # 0 id
    # 1 login
    # 2 password
    # 3 valid_id
    # 4 create_time
    # 5 create_by
    # 6 change_time
    # 7 change_by
    @FetchedRowArray = ();
    while (my @Row = $DBObject->FetchrowArray()) {
        push(@FetchedRowArray, [ @Row ]);
    }

    foreach my $row (@FetchedRowArray) {
        my @Row = @{$row};
        return if !$DBObject->Do(
            SQL  => "INSERT INTO users (login, pw, valid_id, create_time,  create_by, change_time, change_by,
                   is_customer, first_name, last_name, email) VALUES (?,?,?,?,?,?,?,0,'dummy','dummy','dummy')",
            Bind => [ \$Row[1], \$Row[2], \$Row[3], \$Row[4], \$Row[5], \$Row[6], \$Row[7], ]
        );

        return if !$DBObject->Do(
            SQL  => 'UPDATE contact SET user_id = (SELECT id FROM users WHERE login = ? LIMIT 1) WHERE id = ?',
            Bind => [ \$Row[1], \$Row[0] ]
        );
    }
    $LogObject->Log(
        Priority => "info",
        Message  => "Done!"
    );
    return 1;
}

sub _PrepareAndValidateTableOrganisation {
    my $DBObject = $Kernel::OM->Get('DB');
    #change_by and create_by have missing foreign key constrains --> validate before adding constrains
    $LogObject->Log(
        Priority => "info",
        Message  => "Validating columns 'change_by' and 'create_by' in table 'organisation'..."
    );

    return if !$DBObject->Prepare(
        SQL => 'SELECT DISTINCT(o.create_by)
                FROM organisation o
                WHERE o.create_by NOT IN (
                    SELECT id FROM users
                )',
    );

    my @UnknownUserIDs = ();
    my $UnknownUserIDsString = '';
    while (my @Row = $DBObject->FetchrowArray()) {
        push(@UnknownUserIDs, $Row[0]);
    }

    $UnknownUserIDsString = join(',', @UnknownUserIDs) if (scalar @UnknownUserIDs > 0);

    if ($UnknownUserIDsString) {
        return if !$DBObject->Do(
            SQL  => 'UPDATE organisation SET create_by = 1 WHERE create_by IN (?)',
            Bind => [ \$UnknownUserIDsString ]
        );
    }

    return if !$DBObject->Prepare(
        SQL => 'SELECT DISTINCT(o.change_by)
                FROM organisation o
                WHERE o.change_by  NOT IN (
                    SELECT id FROM users
                )',
    );

    @UnknownUserIDs = ();
    $UnknownUserIDsString = '';
    while (my @Row = $DBObject->FetchrowArray()) {
        push(@UnknownUserIDs, $Row[0]);
    }

    $UnknownUserIDsString = join(',', @UnknownUserIDs) if (scalar @UnknownUserIDs > 0);

    if ($UnknownUserIDsString) {
        return if !$DBObject->Do(
            SQL  => 'UPDATE organisation SET change_by = 1 WHERE change_by IN (?)',
            Bind => [ \$UnknownUserIDsString ]
        );
    }

    $LogObject->Log(
        Priority => "info",
        Message  => "Done!"
    );
}

sub _PrepareAndValidateTableTicket {
    my $DBObject = $Kernel::OM->Get('DB');
    $LogObject->Log(
        Priority => "info",
        Message  => "Validating organisation IDs in table 'ticket'..."
    );
    # prepare organisations and validate
    # remove all non existing organisations from ticket table. this is possible because so far organisation id was an
    # varchar with no foreign key constraint on table organisation.id
    return if !$DBObject->Prepare(
        SQL => 'SELECT id FROM organisation'
    );
    my @UnknownOrgIDs = ();
    my $UnknownOrgIDString = '';
    while (my @Row = $DBObject->FetchrowArray()) {
        push(@UnknownOrgIDs, $Row[0]);
    }
    $UnknownOrgIDString = join(',', @UnknownOrgIDs) if (scalar @UnknownOrgIDs > 0);

    if ($UnknownOrgIDString) {
        return if !$DBObject->Do(
            SQL  => "UPDATE ticket SET organisation_id = NULL WHERE organisation_id NOT IN (?)",
            Bind => [ \$UnknownOrgIDString ]
        );
    }

    return if $DBObject->Prepare(
        SQL => 'SELECT DISTINCT(organisation_id) FROM ticket WHERE organisation_id IS NOT NULL'
    );

    my @OrgIDs = ();
    while (my @Row = $DBObject->FetchrowArray()) {
        push(@OrgIDs, \$Row[0]);
    }

    foreach my $id (@OrgIDs) {
        return if !$DBObject->Do(
            SQL  => 'UPDATE ticket SET organisation_id_new = ? WHERE organisation_id = \'?\'',
            Bind => [ \$id, \$id ]
        );
    }

    $LogObject->Log(
        Priority => "info",
        Message  => "Done!"
    );

    #########Contacts#########
    $LogObject->Log(
        Priority => "info",
        Message  => "Checking column 'contactid' for non-integer values..."
    );
    # contact_id is a varchar and can hold an email-address if the contact is unknown (or used something like a web form
    # to create the ticket) or an id.
    return if !$DBObject->Prepare(
        SQL => 'SELECT DISTINCT(contact_id) FROM ticket WHERE contact_id LIKE \'%@%\'',
    );
    # 0 contact_id (is an email-address)
    my @FetchedRowArray = ();
    while (my @Row = $DBObject->FetchrowArray()) {
        push(@FetchedRowArray, [ @Row ]);
    }

    foreach my $row (@FetchedRowArray) {
        my @Row = @{$row};
        my $EmailParser = Kernel::System::EmailParser->new(
            Mode => 'Standalone',
        );
        my $ContactEmail = $EmailParser->GetEmailAddress(
            Email => $Row[0],
        );
        my $ContactEmailRealname = $EmailParser->GetRealname(
            Email => $Row[0],
        );

        my @NameChunks = split(' ', $ContactEmailRealname);

        return if !$DBObject->Prepare(
            SQL   => 'SELECT id FROM contact WHERE LOWER(email) = LOWER(?)',
            Bind  => [ \$ContactEmail ],
            Limit => 1,
        );

        my $ContactID;
        while (my @ID = $DBObject->FetchrowArray()) {
            $ContactID = $ID[0];
        }

        if (!$ContactID) {
            my $Firstname = (@NameChunks) ? $NameChunks[0] : $ContactEmail;
            my $Lastname = (@NameChunks) ? join(" ", splice(@NameChunks, 1)) : $ContactEmail;
            my $uuid = Data::UUID->new();
            my $DummyLogin = $uuid->to_hexstring($uuid->create()); #temporary workaround to ensure unique constraint on "login" and "login" not null
            return if !$DBObject->Do(
                SQL  => 'INSERT INTO contact (login, firstname, lastname, email, valid_id, change_by, change_time, create_by, create_time)
                        VALUES (?,?,?,?,1,1,current_timestamp,1,current_timestamp)',
                Bind => [ \$DummyLogin, \$Firstname, \$Lastname, \$ContactEmail ]
            );
        }

        return if !$DBObject->Do(
            SQL  => 'UPDATE ticket SET contact_id = ? WHERE contact_id = ?',
            Bind => [ \$ContactID, \$Row[0] ],
        );

        $LogObject->Log(
            Priority => "info",
            Message  => "Mapped '$Row[0]' to contact '$ContactID' "
        );

    }
    $LogObject->Log(
        Priority => "info",
        Message  => "Done!"
    );
    return 1;
}

sub _PopulateContactOrganisationMappingTable {
    my $DBObject = $Kernel::OM->Get('DB');

    $LogObject->Log(
        Priority => "info",
        Message  => "Mapping contacts to their organisations..."
    );

    return if !$DBObject->Prepare(
        SQL => 'SELECT id, primary_org_id, org_ids FROM contact',
    );
    # 0 id
    # 1 primary org ID
    # 2 all org IDs comma separated: e.g. ',12,3,4,'
    my @FetchedRowArray = ();
    while (my @Row = $DBObject->FetchrowArray()) {
        push(@FetchedRowArray, [ @Row ]);
    }

    foreach my $row (@FetchedRowArray) {
        my @Row = @{$row};

        my @OrgIDs = split /,/, $Row[2];
        foreach my $ID (@OrgIDs) {
            if ($ID) {
                my $is_primary = ($ID == $Row[1]) ? 1 : 0;
                return if !$DBObject->Do(
                    SQL  => 'INSERT INTO contact_organisation (contact_id, org_id, is_primary) VALUES (?,?,?)',
                    Bind => [ \$Row[0], \$ID, \$is_primary ]
                );
            }
        }
    }

    $LogObject->Log(
        Priority => "info",
        Message  => "Done!"
    );
    return 1;
}

# make all existing users agents
_SetAgents();

# validate userIds in change_by and create_by and set to 1 if the provided ID is non-existing
_PrepareAndValidateTableOrganisation();

# merge User info into contact table
_MigrateUserInfoToContact();

# merge contact login info into user table and set new users is_customer = 1
_MigrateContactInfoToUsers();

# validate orgIDs ans set to 1 if non-existing or NULL
# check contacts for non-ID entries and make them new contacts and insert IDs
_PrepareAndValidateTableTicket();

# map contacts to their organisation(s)
_PopulateContactOrganisationMappingTable();

exit 0;

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
