# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::FwdLinkedObjectData;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Language',
    'LinkObject',
    'Ticket',
    'ITSMConfigItem',
    'Main',
    'Log',
    'Output::HTML::Layout',
);

use vars qw($VERSION);
$VERSION = '$Revision$';
$VERSION =~ s/^\$.*:\W(.*)\W.+?$/$1/;

sub new {
    my ( $Type, %Param ) = @_;
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigObject}   = $Kernel::OM->Get('Config');
    $Self->{LayoutObject}   = $Kernel::OM->Get('Output::HTML::Layout');
    $Self->{LanguageObject} = $Kernel::OM->Get('Language');

    return $Self;
}

sub BuildFwdContent {
    my ( $Self, %Param ) = @_;
    my $Intend    = "    ";
    my $Translate = 0;

    #check required stuff...
    foreach (qw( TicketID)) {
        if ( !$Param{$_} ) {

            return;
        }
    }

    if ( defined( $Param{Intend} ) ) {
        $Intend = $Param{Intend};
    }

    my $FwdObjectClassesRef
        = $Self->{ConfigObject}->Get('ExternalSupplierForwarding::ForwardObjectClasses');

    #get ticket data...
    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID => $Param{TicketID},
        UserID   => 1,
    );
    my %FirstArticle = $Kernel::OM->Get('Ticket')->ArticleFirstArticle(
        TicketID => $Param{TicketID},
    );

    my $FwdBody = "";

    #---------------------------------------------------------------------
    # get data of linked objects...
    my $RelevantLinkObjectClasses = join( ",", keys( %{$FwdObjectClassesRef} ) );
    my %PartnerList               = ();
    my $Count                     = 0;

    #build partner link list...
    for my $LinkPartner ( keys( %{$FwdObjectClassesRef} ) ) {

        my $ArrayRef = $Self->_GetLinkedObjects(
            FromObject   => 'Ticket',
            FromObjectID => $Param{TicketID},
            ToObject     => 'ConfigItem',
            ToSubObject  => '',
        );
        $PartnerList{$LinkPartner} = $ArrayRef;

    }

    #handle ITSMConfigItem-partners...
    my $ITSMConfigItemIsInstalled
        = $Kernel::OM->Get('Main')->Require('ITSMConfigItem');
    if ( $PartnerList{'ConfigItem'} && $ITSMConfigItemIsInstalled ) {

        my $ITSMConfigItemObject = $Kernel::OM->Get('ITSMConfigItem');

        #get attributes relevant to forwarding...
        my @RelevantLinkObjectAttributes =
            split( ",", $FwdObjectClassesRef->{'ConfigItem'} );
        my @CIIDArray = @{ $PartnerList{'ConfigItem'} };

        for my $CurrCIID (@CIIDArray) {
            $Count++;

            #-------------------------------------------------------------------
            #get CI data...
            my $ConfigItemRef = $ITSMConfigItemObject->ConfigItemGet(
                ConfigItemID => $CurrCIID,
            );

            if ( $ConfigItemRef->{Number} ) {
                $FwdBody .= "\n" . $Intend . "(" . $Count . ") " . $ConfigItemRef->{Class};
                $FwdBody .= " - " . $ConfigItemRef->{Number} . "\n";
            }

            for my $CurrKey (@RelevantLinkObjectAttributes) {
                if ( $ConfigItemRef->{$CurrKey} ) {
                    $FwdBody .= $Intend . "    " . $Self->{LanguageObject}->Translate($CurrKey);
                    $FwdBody .= ": " . $ConfigItemRef->{$CurrKey} . "\n";
                }
            }

            #-------------------------------------------------------------------
            #get linked locations....
            my $ArrayRef = $Self->_GetLinkedObjects(
                FromObject   => 'ConfigItem',
                FromObjectID => $CurrCIID,
                ToObject     => 'ConfigItem',
                ToSubObject  => 'Location',
            );

            for my $CILocID ( @{$ArrayRef} ) {

                my $LocConfigItemRef = $ITSMConfigItemObject->ConfigItemGet(
                    ConfigItemID => $CILocID,
                );
                my $LocVersionRef = $ITSMConfigItemObject->VersionGet(
                    ConfigItemID => $CILocID,
                );

                next if ( !$LocVersionRef || ( ref($LocVersionRef) ne 'HASH' ) );

                $FwdBody .= $Intend . "    "
                    . $Self->{LanguageObject}->Translate('Location Information')
                    . " (" . $LocVersionRef->{Name} . "): "
                    . "\n";

                my $ExcludedAttrRef
                    = $Self->{ConfigObject}->Get('FwdLinkedObjectData::ExcludedCIAttributeKeys');
                my $OnlyAttrRef
                    = $Self->{ConfigObject}->Get('FwdLinkedObjectData::OnlyCIAttributeKeys');

                my $CurrentExcludedAttr = $ExcludedAttrRef->{ $LocVersionRef->{Class} } || "";
                my $CurrentOnlyAttr     = $OnlyAttrRef->{ $LocVersionRef->{Class} }     || "";
                my $CIInfoString        = "";

                if (
                    ( ref $LocVersionRef eq 'HASH' )
                    &&
                    ( $LocVersionRef->{XMLDefinition} ) &&
                    ( $LocVersionRef->{XMLData} ) &&
                    ( ref $LocVersionRef->{XMLDefinition} eq 'ARRAY' ) &&
                    ( ref $LocVersionRef->{XMLData}       eq 'ARRAY' ) &&
                    ( $LocVersionRef->{XMLData}->[1] ) &&
                    ( ref $LocVersionRef->{XMLData}->[1] eq 'HASH' ) &&
                    ( $LocVersionRef->{XMLData}->[1]->{Version} ) &&
                    ( ref $LocVersionRef->{XMLData}->[1]->{Version} eq 'ARRAY' )
                    )
                {
                    $CIInfoString = $Self->_StringOutputFromCIXMLData(
                        XMLDefinition  => $LocVersionRef->{XMLDefinition},
                        XMLData        => $LocVersionRef->{XMLData}->[1]->{Version}->[1],
                        Intend         => $Intend . "        ",
                        ExcludedAttr   => $CurrentExcludedAttr,
                        OnlyAttr       => $CurrentOnlyAttr,
                        LanguageObject => $Self->{LanguageObject},
                    );
                }

                $FwdBody .= $CIInfoString . "\n";

            }    #EO for my $LocLinkObjects (@LocLinkIDs)

            #-------------------------------------------------------------------
            #get CI version data...
            my $VersionRef = $ITSMConfigItemObject->VersionGet(
                ConfigItemID => $CurrCIID,
            );

            my $ExcludedAttrRef
                = $Self->{ConfigObject}->Get('FwdLinkedObjectData::ExcludedCIAttributeKeys');
            my $OnlyAttrRef
                = $Self->{ConfigObject}->Get('FwdLinkedObjectData::OnlyCIAttributeKeys');

            my $CurrentExcludedAttr = $ExcludedAttrRef->{ $VersionRef->{Class} } || "";
            my $CurrentOnlyAttr     = $OnlyAttrRef->{ $VersionRef->{Class} }     || "";

            my $CIInfoString = "";

            if (
                ( ref $VersionRef eq 'HASH' )
                &&
                ( $VersionRef->{XMLDefinition} ) &&
                ( $VersionRef->{XMLData} ) &&
                ( ref $VersionRef->{XMLDefinition} eq 'ARRAY' ) &&
                ( ref $VersionRef->{XMLData}       eq 'ARRAY' ) &&
                ( $VersionRef->{XMLData}->[1] ) &&
                ( ref $VersionRef->{XMLData}->[1] eq 'HASH' ) &&
                ( $VersionRef->{XMLData}->[1]->{Version} ) &&
                ( ref $VersionRef->{XMLData}->[1]->{Version} eq 'ARRAY' )
                )
            {
                $CIInfoString = $Self->_StringOutputFromCIXMLData(
                    XMLDefinition  => $VersionRef->{XMLDefinition},
                    XMLData        => $VersionRef->{XMLData}->[1]->{Version}->[1],
                    Intend         => $Intend . "    ",
                    ExcludedAttr   => $CurrentExcludedAttr,
                    OnlyAttr       => $CurrentOnlyAttr,
                    LanguageObject => $Self->{LanguageObject},
                );
            }

            $FwdBody .= $CIInfoString . "\n";

        }

    }

    return $FwdBody;

}

sub _GetLinkedObjects {
    my ( $Self, %Param ) = @_;
    my @IDArr = qw{};

    # check required params...
    if ( ( !$Param{ToObject} ) || ( !$Param{FromObject} ) || ( !$Param{FromObjectID} ) )
    {
        return;
    }

    #as long as it's not implemented...
    if ( $Param{ToObject} ne 'ConfigItem' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "FwdLinkedObjectData::_GetLinkedObjects: "
                . "unknown ToObject $Param{ToObject} - won't do anything.",
        );
        return;
    }

    if ( !$Param{ToSubObject} ) {
        $Param{ToSubObject} = "";
    }

    #get all linked ToObjects...
    my $PartnerLinkList = $Kernel::OM->Get('LinkObject')->LinkListWithData(
        Object    => $Param{FromObject},
        Key       => $Param{FromObjectID},
        Object2   => $Param{ToObject},
        State     => 'Valid',
        Direction => 'Both',
        UserID    => 1,
    );

    #---------------------------------------------------------------------------
    # ToPartner "ConfigItem"
    if ( $Param{ToObject} eq 'ConfigItem' ) {

        #for each existing link type
        for my $LinkType ( keys( %{ $PartnerLinkList->{'ConfigItem'} } ) ) {

            #if linked object is a source
            if (
                ( defined( $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Source} ) )
                &&
                ( ref( $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Source} ) eq 'HASH' )
                )
            {
                for my $CurrCIID (
                    keys( %{ $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Source} } )
                    )
                {
                    my $CurrCI = $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Source}
                        ->{$CurrCIID};

                    if ( $Param{ToSubObject} && ( $CurrCI->{Class} eq $Param{ToSubObject} ) ) {
                        push( @IDArr, $CurrCIID );
                    }
                    elsif ( !$Param{ToSubObject} ) {
                        push( @IDArr, $CurrCIID );
                    }
                }
            }

            #if linked object is target
            if (
                ( defined( $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Target} ) )
                &&
                ( ref( $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Target} ) eq 'HASH' )
                )
            {
                for my $CurrCIID (
                    keys( %{ $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Target} } )
                    )
                {
                    my $CurrCI = $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Target}
                        ->{$CurrCIID};

                    if ( $Param{ToSubObject} && ( $CurrCI->{Class} eq $Param{ToSubObject} ) ) {
                        push( @IDArr, $CurrCIID );
                    }
                    elsif ( !$Param{ToSubObject} ) {
                        push( @IDArr, $CurrCIID );
                    }
                }
            }

        }    #EO for each existing link type

    }

    # EO ToPartner "ConfigItem"
    #---------------------------------------------------------------------------

    return \@IDArr;
}

sub _StringOutputFromCIXMLData {
    my ( $Self, %Param ) = @_;

    # check required params...
    if (
        ( !$Param{XMLData} )
        ||
        ( !$Param{XMLDefinition} ) ||
        ( ref $Param{XMLData} ne 'HASH' ) ||
        ( ref $Param{XMLDefinition} ne 'ARRAY' )
        )
    {
        return;
    }

    if ( !defined( $Param{Level} ) ) {
        $Param{Level} = 0;
    }

    if ( !defined( $Param{Intend} ) ) {
        $Param{Intend} = "    ";
    }

    my $IntendOffset = "    ";

    my $OutStrg = "";

    if ( !defined( $Param{ExcludedAttr} ) ) {
        $Param{ExcludedAttr} = "";
    }
    if ( !defined( $Param{OnlyAttr} ) ) {
        $Param{OnlyAttr} = "";
    }

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            # no content then stop loop...
            last COUNTER if !defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content};

            # get the value...
            my $Value = $Kernel::OM->Get('ITSMConfigItem')->XMLValueLookup(
                Item => $Item,
                Value => $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content} || '',
            );

            # new attribute, new line...
            my $NewLine = {
                Key   => $Self->{LanguageObject}->Translate( $Item->{Name} ),
                Value => $Value,
            };

            # add intend, if sub-level specified..
            if ( $Param{Level} ) {
                for ( 2 .. $Param{Level} ) {
                    $NewLine->{Key}
                        = $IntendOffset . $Self->{LanguageObject}->Translate( $NewLine->{Key} );
                    $NewLine->{Value} = $NewLine->{Value};
                }
            }

            # add line data to out-string

            if ( $NewLine->{Value} ) {

                my $Value = $NewLine->{Value};
                if ( $Value =~ /\015\012|\015|\012/ ) {
                    $Value =~ s/\015\012|\015|\012/\n$Param{Intend}$Param{Intend}/g;
                    $Value = "\n" . $Param{Intend} . $Param{Intend} . $Value;
                }

                if (
                    ( $Param{ExcludedAttr} )
                    &&
                    ( $Param{ExcludedAttr} !~ /(^|.*,)$Item->{Key}(,.*|$)/ )
                    )
                {
                    $OutStrg .= $Param{Intend} . $NewLine->{Key} . ": " . $Value . "\n";
                }
                elsif (
                    ( $Param{OnlyAttr} )
                    &&
                    ( $Param{OnlyAttr} =~ /(^|.*,)$Item->{Key}(,.*|$)/ )
                    )
                {
                    $OutStrg .= $Param{Intend} . $NewLine->{Key} . ": " . $Value . "\n";
                }
                elsif ( !( $Param{ExcludedAttr} ) && !( $Param{OnlyAttr} ) ) {
                    $OutStrg .= $Param{Intend} . $NewLine->{Key} . ": " . $Value . "\n";
                }

            }

            next COUNTER if !$Item->{Sub};

            #recurse if subsection available...
            $OutStrg .= $Self->_StringOutputFromCIXMLData(
                XMLDefinition  => $Item->{Sub},
                XMLData        => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
                Level          => $Param{Level} + 1,
                Intend         => $Param{Intend},
                ExcludedAttr   => $Param{ExcludedAttr},
                LanguageObject => $Self->{LanguageObject},
            );
        }
    }

    return $OutStrg;
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
