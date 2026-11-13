# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Update::2317;

use strict;
use warnings;

our @ObjectDependencies = (
    'Contact',
    'DB',
    'Log',
    'ObjectSearch',
    'TimeAccounting',
    'XML',
);

=item new()

create an object. Do not use it directly, only used by update script

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub TimeAccountingUpdate {
    my ( $Self, %Param ) = @_;

    my @TimeAccountingIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'TimeAccounting',
        Result     => 'ARRAY',
        UserID     => 1,
        UserType   => 'Agent'
    );

    if ( @TimeAccountingIDs ) {
        my %ExecutingContactIDHash = ();

        for my $TimeAccountingID ( @TimeAccountingIDs ) {
            my %TimeAccounting = $Kernel::OM->Get('TimeAccounting')->TimeAccountingGet(
                TimeAccountingID => $TimeAccountingID
            );

            if ( !$ExecutingContactIDHash{ $TimeAccounting{CreateBy} } ) {
                $ExecutingContactIDHash{ $TimeAccounting{CreateBy} } = $Kernel::OM->Get('Contact')->ContactLookup(
                    UserID => $TimeAccounting{CreateBy}
                );
            }

            my $ExecutingContactID = $ExecutingContactIDHash{ $TimeAccounting{CreateBy} };

            $Kernel::OM->Get('TimeAccounting')->TimeAccountingUpdate(
                %TimeAccounting,
                TimeAccountingID   => $TimeAccountingID,
                ExecutingContactID => $ExecutingContactID,
                StartTime          => $TimeAccounting{CreateTime},
                IsInvoiced         => 0,
                UserID             => 1
            );
        }
    }

    # require columns
    my $XML = <<END;
<?xml version="1.0" encoding="utf-8" ?>
<database Name="kix">

    <TableAlter Name="time_accounting">
        <ColumnChange NameOld="executing_contact_id" NameNew="executing_contact_id" Required="true" Type="INTEGER"/>
        <ColumnChange NameOld="start_time" NameNew="start_time" Required="true" Type="DATE"/>
        <ColumnChange NameOld="is_invoiced" NameNew="is_invoiced" Required="true" Type="SMALLINT" Default="0"/>
    </TableAlter>

</database>
END

    my @XMLArray = $Kernel::OM->Get('XML')->XMLParse(
        String => $XML,
    );
    if (!@XMLArray) {
        $Kernel::OM->Get('Log')->Log(
            Priority => "error",
            Message  => "Unable to parse SQL for update build-2317!",
        );
        return;
    }

    my @SQL = $Kernel::OM->Get('DB')->SQLProcessor(
        Database => \@XMLArray,
    );
    if (!@SQL) {
        $Kernel::OM->Get('Log')->Log(
            Priority => "error",
            Message  => "Unable to generate SQL for update build-2317!",
        );
        return;
    }

    for my $SQL (@SQL) {
        my $Result = $Kernel::OM->Get('DB')->Do(
            SQL => $SQL
        );
        if (!$Result) {
            $Kernel::OM->Get('Log')->Log(
                Priority => "error",
                Message  => "Unable to execute SQL for update build-2317!",
            );
        }
    }

    # execute post SQL statements (indexes, constraints)
    my @SQLPost = $Kernel::OM->Get('DB')->SQLProcessorPost();
    for my $SQL (@SQLPost) {
        my $Result = $Kernel::OM->Get('DB')->Do(
            SQL => $SQL
        );
        if (!$Result) {
            $Kernel::OM->Get('Log')->Log(
                Priority => "error",
                Message  => "Unable to execute POST SQL for update build-2317!",
            );
        }
    }

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
