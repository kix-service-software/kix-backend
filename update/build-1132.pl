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
use lib dirname($Bin) . '/plugins';
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Getopt::Std;

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1132',
    },
);
my $LogObject = $Kernel::OM->Get('Log');

use vars qw(%INC);

use vars qw(%INC);

# add new permissions for role Customer
_AddPermissionsForRoleCustomer();

exit 0;


sub _AddPermissionsForRoleCustomer {
    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    my $RoleID = $Kernel::OM->Get('Role')->RoleLookup(
        Role => 'Customer'
    );

    if (!$RoleID) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Unable to find role "Customer"! Aborting.'
        );
        return;
    }

    my $XML = "<?xml version=\"1.0\" encoding=\"utf-8\" ?>
<database Name=\"kix\">
    <!-- role \"Customer\": permission C____ on /auth -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/auth</Data>
        <Data Key=\"value\">1</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /cmdb -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/cmdb</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission CR___ on /contacts -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/contacts</Data>
        <Data Key=\"value\">3</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /faq -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/faq</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _____ on /faq/* -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/faq/*</Data>
        <Data Key=\"value\">0</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /faq/articles -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/faq/articles</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /faq/articles/*{FAQArticle.CustomerVisible EQ 1} -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">2</Data>
        <Data Key=\"target\" Type=\"Quote\">/faq/articles/*{FAQArticle.CustomerVisible EQ 1}</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission CR___ on /faq/articles/*/votes -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/faq/articles/*/votes</Data>
        <Data Key=\"value\">3</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /i18n -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/i18n</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /links -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/links</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission CRUD_ on /session -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/session</Data>
        <Data Key=\"value\">15</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /system -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/system</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _____ on /system/* -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/system/*</Data>
        <Data Key=\"value\">0</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /system/cmdb -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/system/cmdb</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _____ on /system/cmdb/* -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/system/cmdb/*</Data>
        <Data Key=\"value\">0</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /system/cmdb/classes -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/system/cmdb/classes</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /system/communication -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/system/communication</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _____ on /system/communication/* -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/system/communication/*</Data>
        <Data Key=\"value\">0</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /system/communication/channels -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/system/communication/channels</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /system/communication/notifications -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/system/communication/notifications</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /system/communication/sendertypes -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/system/communication/sendertypes</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /system/communication/systemaddresses -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/system/communication/systemaddresses</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /system/faq -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/system/faq</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _____ on /system/faq/* -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/system/faq/*</Data>
        <Data Key=\"value\">0</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /system/faq/categories -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/system/faq/categories</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /system/ticket -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/system/ticket</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission C____ on /system/users -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/system/users</Data>
        <Data Key=\"value\">1</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission CR___ on /tickets -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/tickets</Data>
        <Data Key=\"value\">3</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /tickets/* -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/tickets/*</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _____ on /tickets{Ticket.ContactID NE \$CurrentUser.Contact.ID && Ticket.OrganisationID NE \$CurrentUser.Contact.PrimaryOrganisationID} -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">2</Data>
        <Data Key=\"target\" Type=\"Quote\"><![CDATA[/tickets{Ticket.ContactID NE \$CurrentUser.Contact.ID && Ticket.OrganisationID NE \$CurrentUser.Contact.PrimaryOrganisationID}]]></Data>
        <Data Key=\"value\">0</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _____ on /tickets/*{Ticket.ContactID NE \$CurrentUser.Contact.ID && Ticket.OrganisationID NE \$CurrentUser.Contact.PrimaryOrganisationID} -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">2</Data>
        <Data Key=\"target\" Type=\"Quote\"><![CDATA[/tickets{Ticket.ContactID NE \$CurrentUser.Contact.ID && Ticket.OrganisationID NE \$CurrentUser.Contact.PrimaryOrganisationID}]]></Data>
        <Data Key=\"value\">0</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /tickets/*{Ticket.[Age,Articles,Changed,ContactID,Created,CreateTimeUnix,DynamicFields,OrganisationID,PriorityID,QueueID,StateID,TypeID]} -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">3</Data>
        <Data Key=\"target\" Type=\"Quote\">/tickets/*{Ticket.[Age,Articles,Changed,ContactID,Created,CreateTimeUnix,DynamicFields,OrganisationID,PriorityID,QueueID,StateID,TypeID]}</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission CR___ on /tickets/*/articles -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/tickets/*/articles</Data>
        <Data Key=\"value\">3</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /tickets/*/articles/* -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/tickets/*/articles/*</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /tickets/*/articles/*{Article.CustomerVisible EQ 1} -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">2</Data>
        <Data Key=\"target\" Type=\"Quote\">/tickets/*/articles/*{Article.CustomerVisible EQ 1}</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission _R___ on /tickets/*/articles/*{Article.[*,!Bcc,!BccRealname]} -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">3</Data>
        <Data Key=\"target\" Type=\"Quote\">/tickets/*/articles/*{Article.[*,!Bcc,!BccRealname]}</Data>
        <Data Key=\"value\">2</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
    <!-- role \"Customer\": permission CR___ on /tickets/*/articles/*/flags -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleID</Data>
        <Data Key=\"type_id\">1</Data>
        <Data Key=\"target\" Type=\"Quote\">/tickets/*/articles/*/flags</Data>
        <Data Key=\"value\">3</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>
</database>";

    my @XMLArray = $Kernel::OM->Get('XML')->XMLParse(
        String => $XML,
    );
    if (!@XMLArray) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to parse permission XML!"
        );
        return;
    }

    my @SQL = $Kernel::OM->Get('DB')->SQLProcessor(
        Database => \@XMLArray,
    );
    if (!@SQL) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to generate SQL from permission XML!"
        );
        return;
    }

    my $Line = 0;
    for my $SQL (@SQL) {
        $Line++;
        my $Result = $Kernel::OM->Get('DB')->Do(
            SQL => $SQL
        );
        if (!$Result) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to execute permission SQL (line $Line)!"
            );
        }
    }

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    return 1;
}

exit 0;

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
