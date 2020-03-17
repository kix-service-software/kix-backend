# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Dev::Tools::PermissionCSV2XML;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

use Kernel::Language;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Encode',
    'Kernel::System::Main',
    'Kernel::System::SysConfig',
    'Kernel::System::Time',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('create permission XML from CSV.');

    $Self->AddOption(
        Name        => 'file',
        Description => "The CSV file to convert.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my %RoleList = (
        'Superuser'        => 1,
        'System Admin'     => 2,
        'Agent User'       => 3,
        'Ticket Reader'    => 4,
        'Ticket Agent'     => 5,
        'Ticket Creator'   => 6,
        'FAQ Reader'       => 7,
        'FAQ Editor'       => 8,
        'CMDB Reader'      => 9,
        'CMDB Maintainer'  => 10,
        'Customer Reader'  => 11,
        'Customer Manager' => 12,
        'Customer'         => 13,
    );

    my %PermissionTypeList = (
        'Resource'         => 1,
        'PropertyValue'    => 2,
        'Property'         => 3,
    );

    my $CSVFile = $Self->GetOption('file');
    if ( !-f $CSVFile ) {
        die "File $CSVFile does not exist or is not readable.\n";
    }

    $Self->Print("<yellow>generating XML...</yellow>\n\n");

    # read CSV file
    my $Content = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
        Location => $CSVFile,
    );
    if ( !$Content ) {
        $Self->PrintError('Could not read CSV file!');
        return $Self->ExitCodeError();
    }

    my $LinesRef = $Kernel::OM->Get('Kernel::System::CSV')->CSV2Array(
        String => $$Content
    );

    # remove header line
    my @Lines = @{$LinesRef};
    shift @Lines;

    foreach my $Line (@Lines) {        
        my $Role   = $Line->[0];
        my $Type   = $Line->[1];
        my $Target = $Line->[2];
        my $Value  = 0
            + ( $Line->[3] ? Kernel::System::Role::Permission->PERMISSION->{CREATE} : 0 )
            + ( $Line->[4] ? Kernel::System::Role::Permission->PERMISSION->{READ}   : 0 )
            + ( $Line->[5] ? Kernel::System::Role::Permission->PERMISSION->{UPDATE} : 0 )
            + ( $Line->[6] ? Kernel::System::Role::Permission->PERMISSION->{DELETE} : 0 )
            + ( $Line->[7] ? Kernel::System::Role::Permission->PERMISSION->{DENY}   : 0 );

        my $PermissionStr = $Kernel::OM->Get('Kernel::System::Role')->GetReadablePermissionValue(
            Value  => $Value,
            Format => 'Short'
        );
        $PermissionStr =~ s/-/_/g;

        $Role   =~ s/ *$//g;
        $Target =~ s/ *$//g;

        my $XML =
            "    <!-- role \"$Role\": permission $PermissionStr on $Target -->
    <Insert Table=\"role_permission\">
        <Data Key=\"role_id\">$RoleList{$Role}</Data>
        <Data Key=\"type_id\">$PermissionTypeList{$Type}</Data>
        <Data Key=\"target\" Type=\"Quote\"><![CDATA[$Target]]></Data>
        <Data Key=\"value\">$Value</Data>
        <Data Key=\"create_by\">1</Data>
        <Data Key=\"create_time\">current_timestamp</Data>
        <Data Key=\"change_by\">1</Data>
        <Data Key=\"change_time\">current_timestamp</Data>
    </Insert>";

        $Self->Print("$XML\n");
    }

    $Self->Print("\n<green>Done.</green>\n");

    return $Self->ExitCodeOk();
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
