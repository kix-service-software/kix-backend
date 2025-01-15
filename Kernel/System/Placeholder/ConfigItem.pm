# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Placeholder::ConfigItem;

use strict;
use warnings;

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Placeholder::Base);

our @ObjectDependencies = (
    'Config',
    'Log'
);

=head1 NAME

Kernel::System::Placeholder::Ticket

=cut

=begin Internal:

=cut

sub _Replace {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Text UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $Tag = $Self->{Start} . 'KIX_ASSET_';
    return $Param{Text} if ($Param{Text} !~ m/$Tag.+?/);

    my $ConfigItem = {};
    my $Version    = {};

    # if objects given (or use ID in data for fallback below)
    if ( IsHashRefWithData($Param{Data}) ) {
        if ( $Param{Data}->{ConfigItem} && IsHashRefWithData($Param{Data}->{ConfigItem}) ) {
            $ConfigItem = $Param{Data}->{ConfigItem};
        } elsif ($Param{Data}->{ConfigItemID}) {
            $Param{ObjectType} = 'ITSMConfigItem';
            $Param{ObjectID} = $Param{Data}->{ConfigItemID};
        }
        if ( $Param{Data}->{Version} && IsHashRefWithData($Param{Data}->{Version}) ) {
            $Version = $Param{Data}->{Version};
        }
    }

    # use ID if objects not given
    if ($Param{ObjectType} && $Param{ObjectType} eq 'ITSMConfigItem' && $Param{ObjectID}) {
        if (!IsHashRefWithData($ConfigItem)) {
            $ConfigItem = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemGet(
                ConfigItemID => $Param{ObjectID}
            ) || {};
        }
        if (
            !IsHashRefWithData($Version)
            && IsHashRefWithData($ConfigItem)
        ) {
            $Version = $Kernel::OM->Get('ITSMConfigItem')->VersionGet(
                ConfigItemID => $ConfigItem->{ConfigItemID},
                XMLDataGet   => 1,
            ) || {};
        }
    }

    my $LanguageObject;
    if ($Param{Language}) {
        $LanguageObject = Kernel::Language->new(
            UserLanguage => $Param{Language}
        );
    }

    if ( IsHashRefWithData($ConfigItem) ) {
        # clone it, do not change original
        $ConfigItem = $Kernel::OM->Get('Storable')->Clone(Data => $ConfigItem);

        $ConfigItem->{ID} = $ConfigItem->{ConfigItemID};

        for my $Field ( keys %{$ConfigItem} ) {
            next if !defined $ConfigItem->{$Field};
            $ConfigItem->{$Field.'!'} = $ConfigItem->{$Field};      # store the original value with a trailing "!"
        }

        if ($LanguageObject) {
            $ConfigItem->{CreateTime} = $LanguageObject->FormatTimeString(
                $ConfigItem->{CreateTime}, 'DateFormat', 'NoSeconds'
            );
            $ConfigItem->{ChangeTime} = $LanguageObject->FormatTimeString(
                $ConfigItem->{ChangeTime}, 'DateFormat', 'NoSeconds'
            );
        }
    }

    # prepare version if needed else set it empty
    if ( IsHashRefWithData($Version) ) {
        # clone it, do not change original
        $Version = $Kernel::OM->Get('Storable')->Clone(Data => $Version);

        # handle CurrentVersion placeholder
        my $CurrentVersionTag = $Tag . 'CurrentVersion_';
        my @Attributes = $Param{Text} =~ m/\Q$CurrentVersionTag\E(.*?)$Self->{End}/g;
        for my $Attribute (@Attributes) {
            my $ReplaceString = '';

            # handle xml attributes
            if ($Attribute =~ m/Data_(.+)/) {
                my $XMLKey = $1;
                my $Values = $Kernel::OM->Get('ITSMConfigItem')->GetAttributeValuesByKey(
                    KeyName       => $XMLKey,
                    XMLData       => $Version->{XMLData}->[1]->{Version}->[1],
                    XMLDefinition => $Version->{XMLDefinition},
                );

                if ( IsArrayRefWithData($Values) ) {
                    $ReplaceString = $Values->[0];
                }
            }
            # handle version attributes
            elsif (
                $Attribute ne 'XMLData'
                && $Attribute ne 'XMLDefinition'
                && defined( $Version->{ $Attribute } )
            ) {
                $ReplaceString = $Version->{ $Attribute };
            }

            $Param{Text} =~ s/\Q$CurrentVersionTag$Attribute\E$Self->{End}/$ReplaceString/g;
        }

        my $TopLevelAttributes = $Self->_GetTopLevelAttributes(Version => $Version) || [];
        my $CheckList = join('|',@{$TopLevelAttributes});
        if ($CheckList && $Param{Text} =~ m/$Tag(?:$CheckList)/) {
            $Self->_PrepareVersion(LanguageObject => $LanguageObject, Version => $Version);
        } else {
            $Version = {};
        }

        # return if "object value" is wanted
        if ($Param{Text} =~ m/^$Tag((?:\w|^>)+)(ObjectValue|(?<!Value|Values|Key|Keys|\d|_)!)$Self->{End}$/) {
            my $Key = $1;
            if ($Key !~ m/_$/) {
                $Key .= '_';
            }
            $Key .= 'ObjectValueArray';
            return $Version->{$Key};
        }
    }

    # replace it
    $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, $Tag, %{ $Version }, %{ $ConfigItem } );

    # cleanup
    $Param{Text} =~ s/$Tag.+?$Self->{End}/$Param{ReplaceNotFound}/gi;

    return $Param{Text};
}

sub _GetTopLevelAttributes {
    my ( $Self, %Param ) = @_;

    return if (
        !IsHashRefWithData( $Param{Version} ) &&
        !IsHashRefWithData( $Param{Version}->{XMLDefinition} )
    );

    my @Attributes;
    for my $Item ( @{ $Param{Version}->{XMLDefinition} } ) {
        push(@Attributes, $Item->{Key})
    }
    return \@Attributes;
}

sub _PrepareVersion {
    my ( $Self, %Param ) = @_;

    if (
        IsHashRefWithData( $Param{Version} ) &&
        IsArrayRefWithData( $Param{Version}->{XMLData} ) &&
        IsHashRefWithData( $Param{Version}->{XMLData}->[1] ) &&
        IsArrayRefWithData( $Param{Version}->{XMLData}->[1]->{Version} ) &&
        IsHashRefWithData( $Param{Version}->{XMLData}->[1]->{Version}->[1] )
    ) {
        # <..._AttributeName> comma separated list of display values
        # <..._AttributeName_Values> like above
        # <..._AttributeName_Keys> comma separated list of saved values
        # <..._AttributeName_0> display value of first value (_1 = display value second value)
        # <..._AttributeName_0_Value> like above
        # <..._AttributeName_0_Key> first value (_1 = second value)
        # for sub attributes: ..._ParentAttribute_0_SubAttribute_0_Value
        $Self->_PrepareData(
            LanguageObject => $Param{LanguageObject},
            Version        => $Param{Version},
            XMLData        => $Param{Version}->{XMLData}->[1]->{Version}->[1],
            XMLDefinition  => $Param{Version}->{XMLDefinition}
        );
    }

    delete $Param{Version}->{XMLData};
    delete $Param{Version}->{XMLDefinition};
}

sub _PrepareData {
    my ( $Self, %Param ) = @_;

    return if (
        !IsHashRefWithData( $Param{Version} ) &&
        IsHashRefWithData( $Param{XMLData} ) &&
        IsHashRefWithData( $Param{XMLDefinition} )
    );
    $Param{Parent} ||= '';

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        my $Attribute = $Param{Parent} . $Item->{Key};
        my @Keys;
        my @Values;
        my @NotTranslatedValues;

        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {
            my $AttributeCounter = $Attribute . "_" . ($Counter - 1);
            if ($Param{XMLData}->{ $Item->{Key} }->[$Counter] && defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content}) {
                my $Value = $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content};

                $Param{Version}->{$AttributeCounter . '_Key'} = $Value;
                push(@Keys, $Value);

                my $PreparedValue = $Self->_GetDisplayValue(
                    LanguageObject => $Param{LanguageObject},
                    Item  => $Item,
                    Value => $Value
                );

                my $NotTranslatedValue = $Self->_GetDisplayValue(
                    Item  => $Item,
                    Value => $Value
                );

                if (defined $PreparedValue) {
                    $Value = $PreparedValue;
                }
                if ( $Item->{Input}->{Type} eq 'Attachment' && IsHashRefWithData($Value) ) {
                    $Value = $Value->{Filename};
                }

                $Param{Version}->{$AttributeCounter . '_Value'} = $Value;
                $Param{Version}->{$AttributeCounter} = $Value;
                $Param{Version}->{$AttributeCounter . '_Value!'} = $NotTranslatedValue // $Param{Version}->{$AttributeCounter . '_Key'};
                $Param{Version}->{$AttributeCounter . '!'} = $NotTranslatedValue // $Param{Version}->{$AttributeCounter . '_Key'};

                push(@Values, $Value);
                push(@NotTranslatedValues, $NotTranslatedValue // $Param{Version}->{$AttributeCounter . '_Key'});
            }

            next COUNTER if !$Item->{Sub};

            # recurse if subsection available...
            $Self->_PrepareData(
                LanguageObject => $Param{LanguageObject},
                Version        => $Param{Version},
                Parent         => $AttributeCounter . '_',
                XMLDefinition  => $Item->{Sub},
                XMLData        => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
            );
        }

        if (scalar(@Values)) {
            $Param{Version}->{$Attribute} = join(', ', @Values);
            $Param{Version}->{$Attribute . '_Values'} = $Param{Version}->{$Attribute};
        }
        if (scalar(@NotTranslatedValues)) {
            $Param{Version}->{$Attribute . '_Values!'} = join(', ', @NotTranslatedValues);
        }
        if (scalar(@Keys)) {
            $Param{Version}->{$Attribute . '_Keys'} = join(', ', @Keys);
            $Param{Version}->{$Attribute . '!'} = join(',', @Keys);
            $Param{Version}->{$Attribute . '_ObjectValue'} = join(',', @Keys);
            $Param{Version}->{$Attribute . '_ObjectValueArray'} = \@Keys;
        }
    }
}

sub _GetDisplayValue {
    my ($Self, %Param) = @_;
    my $Result;

    # check if we have already created an instance of this type
    $Self->{AttributeTypeModules} //= {};
    if ( !$Self->{AttributeTypeModules}->{$Param{Item}->{Input}->{Type}} ) {
        my $Module = 'ITSMConfigItem::XML::Type::'.$Param{Item}->{Input}->{Type};
        my $Object = $Kernel::OM->Get($Module);

        if (ref $Object ne $Kernel::OM->GetModuleFor($Module)) {
            return;
        }
        $Self->{AttributeTypeModules}->{$Param{Item}->{Input}->{Type}} = $Object;
    }

    # check if we have a special handling method to prepare the value
    if ( $Self->{AttributeTypeModules}->{$Param{Item}->{Input}->{Type}}->can('ValueLookup') ) {
        $Result = $Self->{AttributeTypeModules}->{$Param{Item}->{Input}->{Type}}->ValueLookup(
            Item  => $Param{Item},
            Value => $Param{Value},
        );
        if ($Param{LanguageObject}) {
            if (
                $Param{Item}->{Input}->{Type} eq 'Date'
            ) {
                $Result = $Param{LanguageObject}->FormatTimeString(
                    $Result . ' 00:00:01', 'DateFormatShort', 'NoSeconds'
                );
            } elsif (
                $Param{Item}->{Input}->{Type} eq 'DateTime'
            ) {
                $Result = $Param{LanguageObject}->FormatTimeString(
                    $Result, 'DateFormat', 'NoSeconds'
                );
            } elsif (
                $Param{Item}->{Input}->{Type} ne 'Text' &&
                $Param{Item}->{Input}->{Type} ne 'TextArea' &&
                $Param{Item}->{Input}->{Type} ne 'CIClassReference' &&
                $Param{Item}->{Input}->{Type} ne 'TicketReference' &&
                $Param{Item}->{Input}->{Type} ne 'Contact' &&
                $Param{Item}->{Input}->{Type} ne 'Organisation' &&
                $Param{Item}->{Input}->{Type} ne 'User' &&
                $Param{Item}->{Input}->{Type} ne 'EncryptedText'
            ) {
                $Result = $Param{LanguageObject}->Translate($Result);
            }
        }
    }

    return $Result;
}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
