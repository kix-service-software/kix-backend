# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::Event::CSVMappingAutoCreate;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'ITSMConfigItem',
    'ImportExport',
    'GeneralCatalog',
    'Log'
);

sub new {
    my ( $Type, %Param ) = @_;

    #allocate new hash for object...
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ITSMConfigItemObject} = $Kernel::OM->Get('ITSMConfigItem');
    $Self->{GeneralCatalogObject} = $Kernel::OM->Get('GeneralCatalog');
    $Self->{LogObject}            = $Kernel::OM->Get('Log');
    $Self->{ImportExportObject}   = $Kernel::OM->Get('ImportExport');
    $Self->{ConfigObject}         = $Kernel::OM->Get('Config');

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

    return $Kernel::OM->Get('ImportExport::ITSMConfigItemCSVMappingAutoCreate')->CSVMappingAutoCreate(
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
