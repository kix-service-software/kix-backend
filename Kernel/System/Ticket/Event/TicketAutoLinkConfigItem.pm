# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::TicketAutoLinkConfigItem;

use strict;
use warnings;
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Log',
    'Ticket',
    'User',
    'GeneralCatalog',
    'ITSMConfigItem',
    'DynamicField',
    'DynamicField::Backend',
);


sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigObject}         = $Kernel::OM->Get('Config');
    $Self->{LogObject}            = $Kernel::OM->Get('Log');
    $Self->{TicketObject}         = $Kernel::OM->Get('Ticket');
    $Self->{UserObject}           = $Kernel::OM->Get('User');
    $Self->{GeneralCatalogObject} = $Kernel::OM->Get('GeneralCatalog');
    $Self->{ConfigItemObject}     = $Kernel::OM->Get('ITSMConfigItem');
    $Self->{DynamicFieldObject}   = $Kernel::OM->Get('DynamicField');
    $Self->{DynamicFieldBEObject} = $Kernel::OM->Get('DynamicField::Backend');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # --------------------------------------------------------------------------
    # check required stuff and config...
    foreach (qw(Event Config)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message => "Event TicketAutoLinkConfigItem: Need $_!"
            );
            return 0 ;
        }
    }

    if ( !$Param{Data}->{TicketID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Event TicketAutoLinkConfigItem: need TicketID!"
        );
        return 0;
    }

    my $OnlyFirstArticle = $Param{'Config'}->{'FirstArticleOnly'} || '';
    my $AppendDFName     = $Param{'Config'}->{'DynamicFieldName'} || '';

    # check the DF config...
    my $AppendDFConfig = undef;
    if ( $AppendDFName ) {
        $AppendDFConfig = $Self->{DynamicFieldObject}->DynamicFieldGet(
            'Name' => $AppendDFName,
        );
        if ( !IsHashRefWithData($AppendDFConfig) ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Event TicketAutoLinkConfigItem: "
                 . "no valid Dynamic Field defined <$AppendDFName>.",
            );
            return 0;
        }
    }
    else {
      $Self->{LogObject}->Log(
          Priority => 'error',
          Message  => "Event TicketAutoLinkConfigItem: no Dynamic Field defined.",
      );
      return 0;
    }

    # prepare asset class params..
    my $CISearchPatternRef = $Self->{ConfigObject}->Get('TicketAutoLinkConfigItem::CISearchPattern');
    my $SearchInClassesRef = $Self->{ConfigObject}->Get('TicketAutoLinkConfigItem::CISearchInClasses');

    my $SearchClassesPerRecipientRef = $Self->{ConfigObject}->Get('TicketAutoLinkConfigItem::CISearchInClassesPerRecipient');

    return 0 if( ref($CISearchPatternRef) ne 'HASH');
    return 0 if( ref($SearchInClassesRef) ne 'HASH');
    return 0 if( ref($SearchClassesPerRecipientRef) ne 'HASH');

    # only lower case...
    my %SearchClassesRecip = ();
    for my $Key ( %{$SearchClassesPerRecipientRef} ) {
        if ( $SearchClassesPerRecipientRef->{$Key} ) {
            $SearchClassesRecip{ lc($Key) } = $SearchClassesPerRecipientRef->{$Key};
        }
    }


    #---------------------------------------------------------------------------
    # EVENT ArticleCreate - check article id and index...
    my %ArticleData = ();
    if ( $Param{Event} eq 'ArticleCreate' && $Param{Data}->{ArticleID} ) {
        %ArticleData = $Self->{TicketObject}->ArticleGet(
            ArticleID => $Param{Data}->{ArticleID},
            UserID    => 1,
        );
        if ($OnlyFirstArticle) {
            my %FirstArticleData = $Self->{TicketObject}->ArticleFirstArticle(
                TicketID => $Param{Data}->{TicketID},
                UserID   => 1,
            );

            return 0 if ( !$FirstArticleData{ArticleID}
                || $FirstArticleData{ArticleID} != $Param{Data}->{ArticleID}
            );
        }

    }
    elsif ( $Param{Event} eq 'ArticleCreate' && !$Param{Data}->{ArticleID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Event TicketAutoLinkConfigItem: nee ArticleID!"
        );
        return;
    }
    else {

        #use the last article...
        my @ArticleIDs = $Self->{TicketObject}->ArticleIndex(
            TicketID => $Param{Data}->{TicketID},
            UserID   => 1,
        );

        if (@ArticleIDs) {
            %ArticleData = $Self->{TicketObject}->ArticleGet(
                ArticleID => $ArticleIDs[-1],
                UserID    => 1,
            );
        }
    }


    my $SearchPatternRegExp = '';
    my $SearchInIndex       = 0;
    my $SearchIn            = '';
    my @SearchStrings       = ();

    #---------------------------------------------------------------------------
    # GET SEARCH PATTERN for event ArticleCreate
    if ( $Param{Event} eq 'ArticleCreate' ) {
        for my $Key ( keys %{$CISearchPatternRef} ) {
            my $SearchString = '';
            if ( $Key =~ /(Article_)(.*)/ ) {
                $SearchIn = $2;
                $SearchIn =~ s/_OR\d*//g;
                $SearchPatternRegExp = $CISearchPatternRef->{$Key} || '';
                if (
                    $SearchPatternRegExp
                    && $ArticleData{$SearchIn} =~ /$SearchPatternRegExp/m
                    )
                {
                    $SearchString = $1;
                    $SearchString =~ s/^\s+//g;
                    $SearchString =~ s/\s+$//g;
                    push( @SearchStrings, $SearchString );
                }
            }
        }
    }

    #---------------------------------------------------------------------------
    # GET SEARCH PATTERN for event TicketDynamicFieldUpdate
    elsif ( $Param{Event} =~ /TicketDynamicFieldUpdate_/ ) {

        # get ticket data...
        my %TicketData = $Self->{TicketObject}->TicketGet(
            TicketID      => $Param{Data}->{TicketID},
            UserID        => 1,
            DynamicFields => 1,
        );

        # get trigger DF...
        my $TriggerDF = $Param{Event};
        $TriggerDF =~ s/TicketDynamicFieldUpdate_//g;

        # do nothing if updated DF is empty..
        return 0 if (!$TicketData{'DynamicField_'.$TriggerDF});

        # get CI search pattern for config for trigger DF...
        CISEARCHPATTERN:
        for my $Key ( keys( %{$CISearchPatternRef} ) ) {

            # next pattern if current not relevant for trigger field..
            my $KeyPattern = "DynamicField_".$TriggerDF;
            next CISEARCHPATTERN if ( $Key !~ /$KeyPattern(_OR\d*)?/ );

            $SearchPatternRegExp = $CISearchPatternRef->{$Key} || '';

            # next pattern if no regex defined..
            next CISEARCHPATTERN if( !$SearchPatternRegExp );

            # get value(s) of trigger DF (might be an array)...
            my @ValArr = qw{};
            if( ref($TicketData{'DynamicField_'.$TriggerDF}) eq 'ARRAY') {
                @ValArr = @{$TicketData{'DynamicField_'.$TriggerDF}};
            }
            else {
                @ValArr = ($TicketData{'DynamicField_'.$TriggerDF});
            }

            # extract and remember values matching CI search pattern...
            for my $CurrVal ( @ValArr ) {

                if ( $CurrVal && $CurrVal =~ /$SearchPatternRegExp/ ) {
                    my $SearchString = $1;
                    $SearchString =~ s/^\s+//g;
                    $SearchString =~ s/\s+$//g;
                    push( @SearchStrings, $SearchString );
                }
            }
        }
    }

    #---------------------------------------------------------------------------
    # nothing to search for found?
    return 0 if ( !scalar @SearchStrings );


    #---------------------------------------------------------------------------
    # ASSET SEARCH - limit search classes if restricted to-address...
    if ( keys (%SearchClassesRecip) ) {
        my $ToAddress = lc( $ArticleData{To} || '' );
        $ToAddress =~ s/(.*<|>.*)//g;
        if ( $ToAddress && $SearchClassesRecip{$ToAddress} ) {
            for my $CIClass ( keys %{$SearchInClassesRef} ) {
                if ( $SearchClassesRecip{$ToAddress} !~ /(^|.*,\s*)$CIClass(,.*|$)/ )
                {
                    delete( $SearchInClassesRef->{$CIClass} );
                }
            }
        }
    }

    #---------------------------------------------------------------------------
    # ASSET SEARCH - let's do it...
    my %FoundCIIDs = ();
    for my $CIClass ( keys %{$SearchInClassesRef} ) {
        if ( $SearchInClassesRef->{$CIClass} ) {
            my $SearchAttributeKeyList = $SearchInClassesRef->{$CIClass} || '';
            my $ClassItemRef = $Self->{GeneralCatalogObject}->ItemGet(
                Class => 'ITSM::ConfigItem::Class',
                Name  => $CIClass,
            ) || 0;

            if ( ref($ClassItemRef) eq 'HASH' && $ClassItemRef->{ItemID} ) {

                # get CI-class definition...
                my $XMLDefinition = $Self->{ConfigItemObject}->DefinitionGet(
                    ClassID => $ClassItemRef->{ItemID},
                );

                if ( !$XMLDefinition->{DefinitionID} ) {
                    $Self->{LogObject}->Log(
                        Priority => 'error',
                        Message => "TicketAutoLinkConfigItem: no definition "
                            . "found for class $CIClass!",
                    );
                }

                for my $SearchAttributeKey ( split( ',', $SearchAttributeKeyList ) ) {
                    $SearchAttributeKey =~ s/^\s+//g;
                    $SearchAttributeKey =~ s/\s+$//g;
                    next if ( !$SearchAttributeKey );
                    for my $CurrSearchString (@SearchStrings) {
                        my %SearchParams = ();
                        my %SearchData   = ();

                        # get search attributes
                        for my $AttributeValue (qw(Number Name)) {
                            next if $AttributeValue ne $SearchAttributeKey;
                            $SearchParams{$AttributeValue} = $CurrSearchString;
                        }

                        for my $AttributeArray (qw(DeplStateIDs InciStateIDs)) {
                            next if $AttributeArray ne $SearchAttributeKey;
                            $SearchParams{$AttributeArray} = [$CurrSearchString];
                        }

                        # build search params...
                        $SearchData{$SearchAttributeKey} = $CurrSearchString;
                        my @SearchParamsWhat;
                        $Self->_ExportXMLSearchDataPrepare(
                            XMLDefinition => $XMLDefinition->{DefinitionRef},
                            What          => \@SearchParamsWhat,
                            SearchData    => \%SearchData,
                        );

                        # build search hash...
                        if (@SearchParamsWhat) {
                            $SearchParams{What} = \@SearchParamsWhat;
                        }

                        # search if there's sth to search for...
                        if ( scalar( keys(%SearchParams) ) ) {
                            my $ConfigItemList = $Self->{ConfigItemObject}->ConfigItemSearchExtended(
                                %SearchParams,
                                ClassIDs => [ $ClassItemRef->{ItemID} ],
                                UserID   => 1,
                            );

                            for my $ConfigItemID ( @{$ConfigItemList} ) {
                              $FoundCIIDs{$ConfigItemID} = "1";
                            }
                        }
                    }
                }
            }
        }
    }

    #---------------------------------------------------------------------------
    # store found assets in ticket DF (append them, prevent duplicates)...
    my @FoundCIs = keys(%FoundCIIDs);

    if ( scalar(@FoundCIs) ) {
        my $CurrDFValue = $Self->{DynamicFieldBEObject}->ValueGet(
            DynamicFieldConfig => $AppendDFConfig,
            ObjectID           => $Param{Data}->{TicketID},
        );
        my @NewDFValArr = qw{};
        if ($CurrDFValue) {
            if (IsArrayRefWithData($CurrDFValue)) {
                @NewDFValArr = @{ $CurrDFValue };
            } else {
                @NewDFValArr = ( $CurrDFValue );
            }
        }
        my %NewValues = map {$_ => "1"} @NewDFValArr;
        %NewValues    = (%NewValues, %FoundCIIDs);
        @NewDFValArr  = keys( %NewValues );

        # set new DF value
        my $Success = $Self->{DynamicFieldBEObject}->ValueSet(
            DynamicFieldConfig => $AppendDFConfig,
            ObjectID           => $Param{Data}->{TicketID},
            Value              => \@NewDFValArr,
            UserID             => 1,
        );

    }


    return;
}


=item _ExportXMLSearchDataPrepare()

recusion function to prepare the export XML search params

    $ObjectBackend->_ExportXMLSearchDataPrepare(
        XMLDefinition => $ArrayRef,
        What          => $ArrayRef,
        SearchData    => $HashRef,
    );

=cut

sub _ExportXMLSearchDataPrepare {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition};
    return if !$Param{What};
    return if !$Param{SearchData};
    return if ref $Param{XMLDefinition} ne 'ARRAY';
    return if ref $Param{What} ne 'ARRAY';
    return if ref $Param{SearchData} ne 'HASH';

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # create key
        my $Key = $Param{Prefix} ? $Param{Prefix} . '::' . $Item->{Key} : $Item->{Key};

        # prepare value
        my $Values = $Self->{ConfigItemObject}->XMLExportSearchValuePrepare(
            Item  => $Item,
            Value => $Param{SearchData}->{$Key},
        );

        if ($Values) {

            # create search key
            my $SearchKey = $Key;
            $SearchKey =~ s{ :: }{\'\}[%]\{\'}xmsg;

            # create search hash
            my $SearchHash = {
                '[1]{\'Version\'}[1]{\'' . $SearchKey . '\'}[%]{\'Content\'}' => $Values,
            };

            push @{ $Param{What} }, $SearchHash;
        }

        next ITEM if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_ExportXMLSearchDataPrepare(
            XMLDefinition => $Item->{Sub},
            What          => $Param{What},
            SearchData    => $Param{SearchData},
            Prefix        => $Key,
        );
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
