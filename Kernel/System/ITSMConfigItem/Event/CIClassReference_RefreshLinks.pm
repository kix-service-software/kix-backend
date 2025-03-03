# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ITSMConfigItem::Event::CIClassReference_RefreshLinks;

use strict;
use warnings;

our @ObjectDependencies = (
    'ITSMConfigItem',
    'LinkObject',
    'Log'
);

sub new {
    my ( $Type, %Param ) = @_;

    #allocate new hash for object...
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigItemObject} = $Kernel::OM->Get('ITSMConfigItem');
    $Self->{LinkObject}       = $Kernel::OM->Get('LinkObject');
    $Self->{LogObject}        = $Kernel::OM->Get('Log');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    #check required stuff...
    foreach (qw(Event Data)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Event::CIClassReference_RefreshLinks: Need $_!"
            );
            return;
        }
    }
    $Param{ConfigItemID} = $Param{Data}->{ConfigItemID};
    if ( !$Param{ConfigItemID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Event::CIClassReference_RefreshLinks: No ConfigItemID in Data!"
        );
        return;
    }

    #get config item...
    my $ConfigItemRef = $Self->{ConfigItemObject}->ConfigItemGet(
        ConfigItemID => $Param{ConfigItemID},
    );
    return if ( !$ConfigItemRef || ref($ConfigItemRef) ne 'HASH' );

    #check if there is a version at all...
    my $VersionListRef = $Self->{ConfigItemObject}->VersionList(
        ConfigItemID => $Param{ConfigItemID},
    );
    return if ( !$VersionListRef->[0] );

    # get the the new version (that is being created)...
    # new links should be added for this version's attributes
    my $NewVersionData = $Self->{ConfigItemObject}->VersionGet(
        ConfigItemID => $Param{ConfigItemID},
    );
    return if ( !$NewVersionData || ref($NewVersionData) ne 'HASH' );

    # get the old version
    # old links should be deleted for this version's attributes
    my $OldVersionData = ();
    if ( $VersionListRef->[-2] ) {
        $OldVersionData = $Self->{ConfigItemObject}->VersionGet(
            VersionID => $VersionListRef->[-2],
        );
    }

    #---------------------------------------------------------------------------
    # get hash with all attribute-keys, referenced CI-classes,
    # corresponding link types and -directions from CI-class definition...

    my %RelAttrNewVersion = ();
    my %RelAttrOldVersion = ();
    my $XMLDefinition = $Self->{ConfigItemObject}->DefinitionGet(
        ClassID => $NewVersionData->{ClassID},
    );

    # _CreateCIReferencesHash() returns a hash with attributes of Type CICLassREference;
    # for non-empty attributes there are values for
    # $RelAttr{Key}->{ReferencedCIClassLinkType}
    # $RelAttr{Key}->{ReferencedCIClassLinkDirection}
    # Example:
#              'PartOfProject' => [
#                               {
#                                 'ReferencedCIClassLinkType' => 'PartOf',
#                                 'ReferencedCIClassLinkDirection' => '',
#                               }
#                             ]
    # relevant attributes for the old version
    %RelAttrNewVersion = $Self->_CreateCIReferencesHash(
        XMLData       => $NewVersionData->{XMLData}->[1]->{Version}->[1],
        XMLDefinition => $XMLDefinition->{DefinitionRef},
    );

    # relevant attributes for the new version
    %RelAttrOldVersion = $Self->_CreateCIReferencesHash(
        XMLData       => $OldVersionData->{XMLData}->[1]->{Version}->[1],
        XMLDefinition => $XMLDefinition->{DefinitionRef},
    );

    #---------------------------------------------------------------------------
    # update ConfigItem-links...
    if ( $NewVersionData && $XMLDefinition && %RelAttrNewVersion ) {

        my $CIReferenceAttrDataRef = \();

        my %ConfigItemsToDelete;
        my %ConfigItemsToAdd;

        #-----------------------------------------------------------------------
        # delete links most likely created from previous version of this attribute...
        if ( $OldVersionData && %RelAttrOldVersion ) {
            for my $CurrKeyname ( keys(%RelAttrOldVersion) ) {

                next if ( !$RelAttrOldVersion{$CurrKeyname}->[0]->{ReferencedCIClassLinkType} );

                my $LastLinkType = $RelAttrOldVersion{$CurrKeyname}->[0]->{ReferencedCIClassLinkType};

                # NOTE: result looks like {<$CurrKeyname> => [ <CIID1>, <CIID2>, ...]}
                $CIReferenceAttrDataRef = $Self->_GetAttributeDataByKey(
                    XMLData       => $OldVersionData->{XMLData}->[1]->{Version}->[1],
                    XMLDefinition => $XMLDefinition->{DefinitionRef},
                    KeyName       => $CurrKeyname,
                    Content       => 1,    #need the CI-ID, not the shown value
                );

                if (
                    $CIReferenceAttrDataRef->{$CurrKeyname}
                    && ref( $CIReferenceAttrDataRef->{$CurrKeyname} ) eq 'ARRAY'
                ) {
                    for my $CurrPrevPartnerID ( @{ $CIReferenceAttrDataRef->{ $CurrKeyname } } ) {
                        $ConfigItemsToDelete{ $LastLinkType }->{ $CurrPrevPartnerID } = 1;
                    }
                }
            }    #EO for my $CurrKeyname ( keys( %RelAttrOldVersion ))
        }

        #-----------------------------------------------------------------------
        # create new linkes for attributes if the new version
        for my $CurrKeyname ( keys(%RelAttrNewVersion) ) {

            $CIReferenceAttrDataRef = $Self->_GetAttributeDataByKey(
                XMLData       => $NewVersionData->{XMLData}->[1]->{Version}->[1],
                XMLDefinition => $XMLDefinition->{DefinitionRef},
                KeyName       => $CurrKeyname,
                Content => 1,    #need the CI-ID, not the shown value
            );

            my $CurrLinkType = $RelAttrNewVersion{$CurrKeyname}->[0]->{ReferencedCIClassLinkType};

            #-----------------------------------------------------------------------
            # create all links from available data...
            for my $SearchResult ( keys(%{$CIReferenceAttrDataRef}) ) {

                my @ReferenceCIIDs = @{ $CIReferenceAttrDataRef->{$SearchResult} };
                for my $CurrCIReferenceID (@ReferenceCIIDs) {

                    # create link between this CI and current CIReference-attribute...
                    if ( $CurrCIReferenceID && $Param{ConfigItemID} ) {

                        if (
                            $RelAttrNewVersion{$CurrKeyname}->[0]
                            ->{ReferencedCIClassLinkDirection}
                            && $RelAttrNewVersion{$CurrKeyname}->[0]
                            ->{ReferencedCIClassLinkDirection} eq 'Reverse'
                            )
                        {
                            $ConfigItemsToAdd{ $CurrLinkType }->{ $CurrCIReferenceID } = 'Source';
                        }
                        else {
                            $ConfigItemsToAdd{ $CurrLinkType }->{ $CurrCIReferenceID } = 'Target';
                        }

                    }    #EO if( $CurrCIReferenceID && $Param{ConfigItemID})

                }    #EO for my $CurrCIReferenceID( @ReferenceCIIDs )

            }    #EO foreach my $SearchResult ( keys( %{$CIReferenceAttrDataRef}))

        }    #EO for my $CurrKeyname ( keys( %RelAttrNewVersion ))

        LINKTYPE:
        for my $LinkType ( sort( keys( %ConfigItemsToDelete ) ) ) {
            CONFIGITEM:
            for my $ConfigItemID ( sort( keys( %{ $ConfigItemsToDelete{ $LinkType } } ) ) ) {
                # we don't need to delete a link we are going to add again with same type
                next CONFIGITEM if ( $ConfigItemsToAdd{ $LinkType }->{ $ConfigItemID } );

                $Self->{LinkObject}->LinkDelete(
                    Object1 => 'ConfigItem',
                    Key1    => $Param{ConfigItemID},
                    Object2 => 'ConfigItem',
                    Key2    => $ConfigItemID,
                    Type    => $LinkType,
                    UserID  => 1,
                );
            }
        }

        LINKTYPE:
        for my $LinkType ( sort( keys( %ConfigItemsToAdd ) ) ) {
            CONFIGITEM:
            for my $ConfigItemID ( sort( keys( %{ $ConfigItemsToAdd{ $LinkType } } ) ) ) {
                # we don't need to add a link we already have with the correct type
                next CONFIGITEM if ( $ConfigItemsToDelete{ $LinkType }->{ $ConfigItemID } );

                my $Direction = $ConfigItemsToAdd{ $LinkType }->{ $ConfigItemID };

                if ( $Direction eq 'Source' ) {
                    $Self->{LinkObject}->LinkAdd(
                        SourceObject => 'ConfigItem',
                        SourceKey    => $ConfigItemID,
                        TargetObject => 'ConfigItem',
                        TargetKey    => $Param{ConfigItemID},
                        Type         => $LinkType,
                        UserID       => 1,
                    );
                }
                elsif ( $Direction eq 'Target' ) {
                    $Self->{LinkObject}->LinkAdd(
                        TargetObject => 'ConfigItem',
                        TargetKey    => $ConfigItemID,
                        SourceObject => 'ConfigItem',
                        SourceKey    => $Param{ConfigItemID},
                        Type         => $LinkType,
                        UserID       => 1,
                    );
                }
            }
        }

    }    #EO if ( $NewVersionData && $XMLDefinition && %RelAttrNewVersion)

    return;
}

sub _CreateCIReferencesHash {
    my ( $Self, %Param ) = @_;

    # check required params...
    if (
        ( !$Param{XMLData} )
        || ( !$Param{XMLDefinition} )
        || ( ref $Param{XMLData} ne 'HASH' )
        || ( ref $Param{XMLDefinition} ne 'ARRAY' )
        )
    {
        return;
    }

    my $CIRelAttr = $Self->{ConfigItemObject}->GetAttributeDataByType(
        XMLData       => $Param{XMLData},
        XMLDefinition => $Param{XMLDefinition},
        AttributeType => 'CIClassReference',
    );

    my %SumRelAttr = ();
    for my $Key ( keys %{$CIRelAttr} ) {

        my %RetHash = ();
        ITEM:
        for my $Item ( @{ $Param{XMLDefinition} } ) {

            COUNTER:
            for my $Counter ( 1 .. $Item->{CountMax} ) {
                if ( $Item->{Key} eq $Key ) {
                    for my $ParamRef (
                        qw(ReferencedCIClassLinkType ReferencedCIClassLinkDirection)
                        )
                    {
                        $RetHash{$ParamRef} = $Item->{Input}->{$ParamRef};
                    }
                }
                next COUNTER if !$Item->{Sub};

                # sub items in definitions
                if ( $Item->{Sub} ) {
                    %SumRelAttr = (
                        %SumRelAttr,
                        $Self->_CreateCIReferencesHash(
                            XMLDefinition => $Item->{Sub},
                            XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
                        )
                    );
                }
            }
        }
        push @{ $SumRelAttr{$Key} }, \%RetHash;

    }
    return %SumRelAttr;
}

=item _GetAttributeDataByKey()

    Returns a hashref with names and attribute values from the
    XML-DataHash for a specified data type.

    $ConfigItemObject->GetAttributeDataByKey(
        XMLData       => $XMLData,
        XMLDefinition => $XMLDefinition,
        KeyName => $Key,
    );

=cut

sub _GetAttributeDataByKey {
    my ( $Self, %Param ) = @_;

    my %Result;

    if ( $Param{Content} ) {
        my $CurrContent = $Self->{ConfigItemObject}->GetAttributeContentsByKey(
            KeyName       => $Param{KeyName},
            XMLData       => $Param{XMLData},
            XMLDefinition => $Param{XMLDefinition},
            );
        $Result{ $Param{KeyName} } = $CurrContent;
    }
    else {
        my $CurrVal = $Self->{ConfigItemObject}->GetAttributeValuesByKey(
            KeyName       => $Param{KeyName},
            XMLData       => $Param{XMLData},
            XMLDefinition => $Param{XMLDefinition},
            );
        $Result{ $Param{KeyName} } = $CurrVal;
    }
    return \%Result;

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
