# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::Event::CSVMappingAutoCreate;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::ITSMCIAttributCollectionUtils',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::ImportExport',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::Log'
);

sub new {
    my ( $Type, %Param ) = @_;

    #allocate new hash for object...
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CIACUtilsObject}      = $Kernel::OM->Get('Kernel::System::ITSMCIAttributCollectionUtils');
    $Self->{ITSMConfigItemObject} = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    $Self->{GeneralCatalogObject} = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    $Self->{LogObject}            = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{ImportExportObject}   = $Kernel::OM->Get('Kernel::System::ImportExport');
    $Self->{ConfigObject}         = $Kernel::OM->Get('Kernel::Config');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check required stuff...
    foreach (qw(Event Data)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Event::CSVMappingAutoCreate: Need $_!"
            );
            return;
        }
    }

    if ( !$Param{Data}->{Comment} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Event::CSVMappingAutoCreate: No DefinitionID in Data!"
        );
        return;
    }

    return $Kernel::OM->Get('Kernel::System::ImportExport::ITSMConfigItemCSVMappingAutoCreate')->CSVMappingAutoCreate(
        ClassID         => $Param{Data}->{ClassID},
        XMLDefinitionID => $Param{Data}->{Comment},
        TemplateComment => 'Definition create event'
    );

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut