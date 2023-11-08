# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::ConfigItem::XMLData;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::Common
);

our @ObjectDependencies = qw(
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::ConfigItem::XMLData - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Property => {
            IsSortable     => 0|1,
            IsSearchable => 0|1,
            Operators     => []
        },
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    $Self->{Supported} = {};

    # check cache
    my $CacheKey = "GetSupportedAttributes::XMLData";
    my $Data = $Kernel::OM->Get('Cache')->Get(
        Type => 'ITSMConfigurationManagement',
        Key  => $CacheKey,
    );

    if (
        $Data
        && ref $Data eq 'HASH'
    ) {
        $Self->{Supported} = $Data;
        return $Self->{Supported};
    }

    my $ClassIDs = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class'
    );

    for my $ClassID ( sort keys %{$ClassIDs} ) {
        my $Definition = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
            ClassID => $ClassID
        );

        $Self->_XMLAttributeGet(
            DefinitionRef => $Definition->{DefinitionRef},
            ClassID       => $ClassID,
            Class         => $Definition->{Class},
            Key           => 'Data'
        );
    }

    # special supported for assigned contact handle
    $Self->{Supported}->{AssignedContact} = {
        IsSearchable => 1,
        IsSortable   => 0,
        Operators    => []
    };

    $Kernel::OM->Get('Cache')->Set(
        Type  => 'ITSMConfigurationManagement',
        TTL   => 60 * 60 * 24 * 20,
        Key   => $CacheKey,
        Value => $Self->{Supported},
    );

    return $Self->{Supported};
}


=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        Search => {}
    );

    $Result = {
        SQLWhere   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my @SQLWhere;

    # check params
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    my @SQLJoin = $Self->_GetJoin(\%Param);

    my @Where;
    my $Field;
    if ( $Param{Search}->{Field} eq 'AssignedContact' ) {

        my %What = $Self->_GetAssigendSQL(\%Param);
    }
    else {
        my $SearchKey = "[1]{'Version'}[1]";
        my @Parts     = split(/[.]/sm, $Param{Search}->{Field});

        if ( scalar( @Parts ) > 1 ) {
            $Field = 'Data';
        }

        foreach my $Part ( @Parts[2..$#Parts] ) {
            $SearchKey .= "{'$Part'}[%]";
            $Field     .= ".$Part";
        }
        $SearchKey .= "{'Content'}";

        my @KeyWhere = $Self->GetOperation(
            Operator         => 'LIKE',
            Column           => 'xst.xml_content_key',
            Value            => $SearchKey,
            Type             => 'STRING',
            LikeEscapeString => 1,
            Supported        => ['LIKE']
        );

        @Where = $Self->GetOperation(
            Operator   => $Param{Search}->{Operator},
            Column     => 'xst.xml_content_value',
            Value      => $Param{Search}->{Value},
            Type       => 'STRING',
            IsOR       => 1,
            Supplement => [' AND ' . $KeyWhere[0]],
            Supported  => $Self->{Supported}->{$Field}->{Operators}
        );
    }


    return if !@Where;

    push( @SQLWhere, @Where);

    return {
        SQLJoin  => \@SQLJoin,
        SQLWhere => \@SQLWhere,
    };
}

sub _GetAssigendSQL {
    my ( $Self, %Param ) = @_;

    my %Contact = $Self->_GetAssignedContact(
        ContactID              => $Param{Search}->{Value},
        RelevantOrganisationID => $Param{Flags}->{AssignedOrganisation} || q{}
    );

    my $Mapping = $Self->_GetAssignedMapping(\%Param);

    my %UsedClassIDs;
    my %ClassIDs = %{$Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    )};
    my %Classes = reverse %ClassIDs;

    if ( $Param{Flags}->{ClassIDs} ) {
        %UsedClassIDs = map { $ClassIDs{$_} => $_ } @{$Param{Flags}->{ClassIDs}};
    }

    my %SearchWhat;
    CICLASS:
    for my $CIClass ( keys %{ $Mapping->{ $Param{ObjectType} } } ) {
        next CICLASS if ( !IsHashRefWithData( $Mapping->{$CIClass} ) );
        next CICLASS if !$Classes{$CIClass};
        next CICLASS if %UsedClassIDs && !$UsedClassIDs{$CIClass};

        # get CI-class definition...
        my $XMLDefinition = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
            ClassID => $Classes{$CIClass},
        );

        if ( !$XMLDefinition->{DefinitionID} ) {
            if (
                !defined $Param{Silent}
                || !$Param{Silent}
            ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No Definition definied for class $CIClass!",
                );
            }
            next CICLASS;
        }

        # prepare search data
        my %SearchData = $Self->_GetAssignedSearchData(
            CIClass => $CIClass,
            Mapping => $Mapping,
            Contact => \%Contact
        );

        # ignore class if not search is given/usable
        next if (!scalar(keys %SearchData));

        # prepare xml search params (What)
        $Self->_GetXMLSearchDataForAssignedCIs(
            XMLDefinition => $XMLDefinition->{DefinitionRef},
            SearchWhat    => \%SearchWhat,
            SearchData    => \%SearchData,
        );

    }

    return %SearchWhat;
}

sub _GetAssignedSearchData {
    my ($Self, %Param) = @_;

    my $CIClass = $Param{CIClass};
    my $Mapping = $Param{Mapping};
    my %Contact = %{$Param{Contact}};
    my %SearchData;

    for my $CISearchAttribute ( keys %{ $Mapping->{$CIClass} } ) {
        next if (!$CISearchAttribute);
        next if ( !IsHashRefWithData( $Mapping-{$CIClass}->{$CISearchAttribute} ) );

        my $ObjectSearchAttributes = $Mapping->{$CIClass}->{$CISearchAttribute}->{SearchAttributes};
        if ($ObjectSearchAttributes && !IsArrayRefWithData($ObjectSearchAttributes)) {
            $ObjectSearchAttributes = [$ObjectSearchAttributes];
        }
        my $SearchStatics = $Mapping->{$CIClass}->{$CISearchAttribute}->{SearchStatic};
        if ($SearchStatics && !IsArrayRefWithData($SearchStatics)) {
            $SearchStatics = [$SearchStatics];
        }

        next if ( !IsArrayRefWithData($ObjectSearchAttributes) && !IsArrayRefWithData($SearchStatics) );

        $CISearchAttribute =~ s/^\s+//g;
        $CISearchAttribute =~ s/\s+$//g;

        next if !$CISearchAttribute;

        $SearchData{$CISearchAttribute} = [];

        # get attributes search data
        if (
            %Contact
            && IsArrayRefWithData($ObjectSearchAttributes)
        ) {
            $Self->_GetAssignedSearchDataObject(
                CISearchAttribute      => $CISearchAttribute,
                ObjectSearchAttributes => $ObjectSearchAttributes,
                SearchData             => \%SearchData,
                Contact                => \%Contact
            );
        }

        # get static search data
        if (IsArrayRefWithData($SearchStatics)) {
            $Self->_GetAssignedSearchDataStatetic(
                CISearchAttribute => $CISearchAttribute,
                SearchStatics     => $SearchStatics,
                SearchData        => \%SearchData,
            );
        }

        if (!scalar(@{ $SearchData{$CISearchAttribute} })) {
            delete $SearchData{$CISearchAttribute};
        }
    }

    return %SearchData;
}

sub _GetAssignedSearchDataStatetic {
    my ($Self, %Param) = @_;

    for my $SearchStatic ( @{$Param{SearchStatics}} ) {
        next if ( !defined $SearchStatic );
        push ( @{ $Param{SearchData}->{$Param{CISearchAttribute}} }, $SearchStatic );
    }

    return 1;
}

sub _GetAssignedSearchDataObject {
    my ($Self, %Param) = @_;

    for my $ObjectSearchAttribute ( @{$Param{ObjectSearchAttributes}} ) {
        my $Value;
        if ( $ObjectSearchAttribute =~ /.+[.].+/sm ) {
            my @AttributStructure = split(/[.]/sm, $ObjectSearchAttribute);
            next if (
                !$AttributStructure[0]
                || !$AttributStructure[1]
                || !IsHashRefWithData( $Param{Contact}->{$AttributStructure[0]} )
            );
            $Value = $Param{Contact}->{$AttributStructure[0]}->{$AttributStructure[1]}
        } else {
            $Value = $Param{Contact}->{$ObjectSearchAttribute};
        }

        next if ( !defined $Value );

        push (
            @{ $Param{SearchData}->{$Param{CISearchAttribute}} },
            IsArrayRefWithData($Value) ? @{$Value} : $Value
        );
    }

    return 1;
}

sub _GetAssignedContact {
    my ($Self, %Param) = @_;

    # get contact and user data
    my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
        ID            => $Param{ContactID},
        DynamicFields => 1
    );
    if (
        !$ContactData{User}
        && $ContactData{AssignedUserID}
    ) {
        my %User = $Kernel::OM->Get('User')->GetUserData(
            UserID => $ContactData{AssignedUserID},
        );
        $ContactData{User} = IsHashRefWithData(\%User) ? \%User : undef;
    }

    if ($Param{RelevantOrganisationID}) {
        $ContactData{RelevantOrganisationID} = $Param{RelevantOrganisationID} || undef;
    }

    return %ContactData;
}

sub _GetAssignedMapping {
    my ( $Self, %Param ) = @_;

    my $Mapping;
    if ( !$Param{Flags}->{AssignedConfigItemsMapping} ) {
        my $MappingString = $Kernel::OM->Get('Config')->Get('AssignedConfigItemsMapping') || q{};

        my $MappingData = $Kernel::OM->Get('JSON')->Decode(
            Data   => $MappingString,
            Silent => $Param{Silent} || 0
        );

        if ( !IsHashRefWithData($MappingData) ) {
            if (
                !defined $Param{Silent}
                || !$Param{Silent}
            ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Invalid JSON for sysconfig option 'AssignedConfigItemsMapping'."
                );
            }
        }

        $Param{Flags}->{AssignedConfigItemsMapping} = $MappingData;
        $Mapping = $MappingData->{Contact} if ( !$MappingData->{Contact} );
    }
    else {
        $Mapping = $Param{Flags}->{AssignedConfigItemsMapping}->{Contact} || q{};
    }

    return $Mapping;
}


sub _GetJoin {
    my ($Self, %Param) = @_;

    my @JoinAND;
    if (
        $Param{Flags}->{ClassIDs}
        && !$Self->{Flags}->{JoinXML}
    ) {

        my @Types;
        for my $ClassID ( @{$Param{Flags}->{ClassIDs}}) {
            if ( $Param{Flags}->{PreviousVersion} ) {
                push (@Types, 'ITSM::ConfigItem::Archiv::' . $ClassID);
            }
            push (@Types, 'ITSM::ConfigItem::' . $ClassID)
        }
        @JoinAND = $Self->GetOperation(
            Operator  => 'IN',
            Column    => 'xst.xml_type',
            Value     => \@Types,
            Type      => 'STRING',
            Supported => ['IN']
        );
    }
    my @SQLJoin;
    my $TablePrefix = 'ci';
    if ( $Param{Flags}->{PreviousVersion} ) {
        $TablePrefix = 'vr';

        if ( !$Param{Flags}->{JoinVersion} ) {
            push(
                @SQLJoin,
                ' LEFT OUTER JOIN configitem_version vr on ci.id = vr.configitem_id'
            );
            $Param{Flags}->{JoinVersion} = 1;
        }
        if ( !$Self->{Flags}->{JoinXML} ) {

            push(
                @SQLJoin,
                ' LEFT OUTER JOIN xml_storage xst on vr.id = CAST(xst.xml_key AS BIGINT)'
                . (@JoinAND ? ' AND ' . $JoinAND[0] : q{})
            );
            $Param{Flags}->{JoinXML} = 1;
        }
    }
    elsif ( !$Self->{Flags}->{JoinXML} ) {
        push(
            @SQLJoin,
            ' LEFT OUTER JOIN xml_storage xst on ci.last_version_id = CAST(xst.xml_key AS BIGINT)'
            . (@JoinAND ? ' AND ' . $JoinAND[0] : q{})
        );
        $Param{Flags}->{JoinXML} = 1;
    }

    return @SQLJoin;
}

sub _XMLAttributeGet {
    my ($Self, %Param) = @_;

    return if !$Param{DefinitionRef};
    return if ref $Param{DefinitionRef} ne 'ARRAY';

    for my $Attr ( @{$Param{DefinitionRef}} ) {
        my $Key = ($Param{Key} || 'Data') . ".$Attr->{Key}";

        $Self->{Supported}->{"$Param{Class}::$Key"} = {
            IsSearchable => $Attr->{Searchable} || 0,
            IsSortable   => 0,
            ClassID      => $Param{ClassID},
            Operators    => $Attr->{Searchable} ? ['EQ','NE','LT','LTE','GT','GTE','CONTAINS','ENDSWITH','STARTSWITH'] : []
        };

        if ( $Attr->{Sub} ) {
            $Self->_XMLAttributeGet(
                %Param,
                DefinitionRef => $Attr->{Sub},
                Key           => $Key,
            );
        }
    }

    return 1;
}

sub _GetXMLSearchDataForAssignedCIs {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition} || ref $Param{XMLDefinition} ne 'ARRAY';
    return if !$Param{SearchWhat}    || ref $Param{SearchWhat}    ne 'HASH';
    return if !$Param{SearchData}    || ref $Param{SearchData}    ne 'HASH';

    for my $Item ( @{ $Param{XMLDefinition} } ) {
        my $Key = $Param{Prefix} ? $Param{Prefix} . q{::} . $Item->{Key} : $Item->{Key};

        # prepare value
        my $Values = [];
        if ( IsArrayRefWithData($Param{SearchData}->{$Key}) ) {

            for my $SingleValue ( @{$Param{SearchData}->{$Key}} ) {
                my $ValuePart = $Kernel::OM->Get('ITSMConfigItem')->XMLExportSearchValuePrepare(
                    Item  => $Item,
                    Value => $SingleValue,
                );

                if (defined $ValuePart && $ValuePart ne q{}) {
                    if ( IsArrayRefWithData($ValuePart) ) {
                        push( @{$Values}, @{$ValuePart} );
                    } else {
                        push( @{$Values}, $ValuePart);
                    }
                }
            }
        }

        if ( IsArrayRefWithData($Values) ) {

            # create search key
            my $SearchKey = $Key;
            $SearchKey =~ s{ :: }{\'\}[%]\{\'}xmsg;

            # create search hash
            $Param{SearchWhat}->{ "[1]{'Version'}[1]{'" . $SearchKey. "'}[%]{'Content'}" } = $Values;
        }

        next if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_GetXMLSearchDataForAssignedCIs(
            XMLDefinition => $Item->{Sub},
            SearchWhat    => $Param{SearchWhat},
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
