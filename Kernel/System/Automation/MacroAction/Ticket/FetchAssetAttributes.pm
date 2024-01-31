# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::FetchAssetAttributes;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Log',
    'Ticket',
    'DynamicField',
    'DynamicField::Backend',
    'ITSMConfigItem'
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::FetchAssetAttributes - A module to fetch asset attribute value to ticket dynamic fields

=head1 SYNOPSIS

All FetchAssetAttributes functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Fetch value from attachments and use them to set dynamic fields of ticket.'));
    $Self->AddOption(
        Name        => 'AssetReferenceDF',
        Label       => Kernel::Language::Translatable('Asset Reference Dynamic Field'),
        Description => Kernel::Language::Translatable('The name of the dynamic field which contains the relevant asset ID.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'ForceSet',
        Label       => Kernel::Language::Translatable('Force'),
        Description => Kernel::Language::Translatable('If set the dynamic field values will be overwritten whether or not the asset atribute is empty or the dynamic field has already a value.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'AttributeDFMapping',
        Label       => Kernel::Language::Translatable('Attribute - DynamicField Mapping'),
        Description => Kernel::Language::Translatable('The mapping which asset attribute will set which ticket dynamic field.'),
        Required    => 1,
    );

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        TicketID => 123,
        Config   => {
            AssetReferenceDF   => 'SomeDFName',
            ForceSet           => 1|0,
            AttributeDFMapping => [
                [ 'SomeAttributeName', 'SomeOtherDFName' ],
                [ ... ],
                ...
            ]
        },
        UserID   => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);

    my $TicketObject       = $Kernel::OM->Get('Ticket');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $ConfigItemObject   = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 1,
        Silent        => 1,
    );

    return if (!%Ticket);

    my $AssetReferenceDFName = $Self->_ReplaceValuePlaceholder(
        %Param,
        Value => $Param{Config}->{AssetReferenceDF}
    );

    return if (!$AssetReferenceDFName);
    return if (!IsArrayRefWithData($Param{Config}->{AttributeDFMapping}));

    # check if dynamic field is set
    my $CIID = $Ticket{ 'DynamicField_' . $AssetReferenceDFName };

    # use first entry if it is an array ref
    if( IsArrayRefWithData($CIID) ) {
        $CIID = $CIID->[0];
    }

    if( !$CIID ) {
        return 1;
    }

    # get version data
    my $VersionData = $ConfigItemObject->VersionGet(
       ConfigItemID => $CIID,
    );
    if( !$VersionData || !IsHashRefWithData($VersionData) ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - could not get CI version for \"$CIID\"!",
            UserID   => $Param{UserID}
        );
        return;
    }

    # get xml definition
    my $XMLDefinition = $ConfigItemObject->DefinitionGet(
       ClassID => $VersionData->{ClassID},
    );
    if( !$XMLDefinition || !IsHashRefWithData($XMLDefinition) ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - could not get XMLDefinition for \"$CIID/$VersionData->{ClassID}\"!",
            UserID   => $Param{UserID}
        );
        return;
    }

    for my $CurrMapping( @{$Param{Config}->{AttributeDFMapping}} ) {

        # skip if config is empty
        next if (!IsArrayRefWithData($CurrMapping) || !$CurrMapping->[0] || !$CurrMapping->[1]);

        my $SourceAttributeName = $Self->_ReplaceValuePlaceholder(
            %Param,
            Value => $CurrMapping->[0]
        );

        my $TargetDFName = $Self->_ReplaceValuePlaceholder(
            %Param,
            Value => $CurrMapping->[1]
        );

        next if (!$SourceAttributeName || !$TargetDFName);

        # skip if existent value should not be overwritten
        next if ($Ticket{ 'DynamicField_' . $TargetDFName} && !$Param{Config}->{ForceSet});

        # get dynamic field config
        my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
            Name => $TargetDFName,
        );
        next if (!IsHashRefWithData($DynamicFieldConfig));

        # get value from config item version
        my $CIAttributeData = $ConfigItemObject->GetAttributeContentsByKey(
            XMLData       => $VersionData->{XMLData}->[1]->{Version}->[1],
            XMLDefinition => $XMLDefinition->{DefinitionRef},
            KeyName       => $SourceAttributeName,
        );
        my $NewDFValue = $CIAttributeData->[0] || undef;

        my $Success;
        if (defined $NewDFValue) {

            # prepare value for field type 'Date'/'DateTime'
            if(
                ($DynamicFieldConfig->{FieldType} eq 'Date' || $DynamicFieldConfig->{FieldType} eq 'DateTime')
                && $NewDFValue !~ m/ 00:00:00$/
            ) {
                $NewDFValue .= ' 00:00:00';
            }

            # set new value
            $Success = $BackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $Param{TicketID},
                Value              => $NewDFValue,
                UserID             => $Param{UserID} || 1,
            );
        } else {
            $Success = $BackendObject->ValueDelete(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $Param{TicketID},
                UserID             => $Param{UserID} || 1,
            );
        }
        if(!$Success) {
            $Kernel::OM->Get('Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't update dynamic field of ticket $Param{TicketID}!",
                UserID   => $Param{UserID}
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
