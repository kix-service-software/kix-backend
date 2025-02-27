# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ObjectSearch::Database::ConfigItem::XMLData;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::ConfigItem::XMLData - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    # check cache
    my $CacheKey  = "GetSupportedAttributes::XMLData";
    my $CacheData = $Kernel::OM->Get('Cache')->Get(
        Type => 'ObjectSearch_ConfigItem',
        Key  => $CacheKey,
    );
    return $CacheData if ( IsHashRefWithData( $CacheData ) );

    # get valid config item
    my $ClassIDs = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
        Valid => 1
    );

    # init hash ref for supported attributes
    my $AttributesRef = {};

    # process classes in order to get predictable result
    for my $ClassID ( sort( keys( %{ $ClassIDs } ) ) ) {
        # get current class definition
        my $Definition = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
            ClassID => $ClassID
        );
        next if (
            !IsHashRefWithData( $Definition )
            || !IsArrayRefWithData( $Definition->{DefinitionRef} )
        );

        # get supported attributes for current class
        $Self->_XMLAttributeGet(
            DefinitionRef => $Definition->{DefinitionRef},
            ClassID       => $ClassID,
            Class         => $Definition->{Class},
            Key           => 'CurrentVersion.Data',
            AttributesRef => $AttributesRef
        );
    }

    # cache supported attributes
    $Kernel::OM->Get('Cache')->Set(
        Type  => 'ITSMConfigurationManagement',
        TTL   => 60 * 60 * 24 * 20,
        Key   => $CacheKey,
        Value => $AttributesRef,
    );

    # return supported attributes
    return $AttributesRef;
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # check for needed joins
    my $TableAlias = 'xst_left' . ( $Param{Flags}->{JoinMap}->{ $Param{Search}->{Field} } // '' );
    my @SQLJoin = ();
    if ( !defined( $Param{Flags}->{JoinMap}->{ $Param{Search}->{Field} } ) ) {
        my $Count = $Param{Flags}->{XMLStorageJoinCounter}++;
        $TableAlias .= $Count;

        # init column for storage join
        my $XMLStorageJoinColumn = 'ci.last_version_id';
        if ( $Param{Flags}->{PreviousVersionSearch} ) {
            $XMLStorageJoinColumn = 'civ.id';

            if ( !$Param{Flags}->{JoinMap}->{ConfigItemVersion} ) {
                push( @SQLJoin, 'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id' );

                $Param{Flags}->{JoinMap}->{ConfigItemVersion} = 1;
            }
        }

        # get parts of fields
        my @FieldParts = split(/\./, $Param{Search}->{Field});

        # remove first to parts (always CurrentVersion and Data)
        splice( @FieldParts, 0, 2 );

        # prepare supplement value
        my $JoinRestrictionValue = '[1]{\'Version\'}[1]';
        for my $Part ( @FieldParts ) {
            $JoinRestrictionValue .= "{'$Part'}[%]";
        }
        $JoinRestrictionValue .= '{\'Content\'}';

        # prepare supplement
        my $JoinRestriction = $Self->_GetCondition(
            Column   => "$TableAlias.xml_content_key",
            Operator => 'LIKE',
            Value    => $JoinRestrictionValue
        );

        my $SupportedAttributes = $Self->GetSupportedAttributes();
        my @XMLType     = map{"ITSM::ConfigItem::$_"} @{$SupportedAttributes->{$Param{Search}->{Field}}->{ClassID}};

        if ( $Param{Flags}->{PreviousVersionSearch} ) {
            my @XMLTypeArchiv = map{"ITSM::ConfigItem::Archiv::$_"} @{$SupportedAttributes->{$Param{Search}->{Field}}->{ClassID}};
            push( @XMLType, @XMLTypeArchiv);
        }

        my $JoinXMLType = $Self->_GetCondition(
            Column   => "$TableAlias.xml_type",
            Operator => 'IN',
            Value    => \@XMLType
        );

        # add join for xml storage
        push(
            @SQLJoin,
            "LEFT OUTER JOIN xml_storage $TableAlias ON $TableAlias.xml_key = $XMLStorageJoinColumn AND $JoinRestriction AND $JoinXMLType"
        );

        $Param{Flags}->{JoinMap}->{ $Param{Search}->{Field} } = $Count;
    }

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator  => $Param{Search}->{Operator},
        Column    => "$TableAlias.xml_content_value",
        Value     => $Param{Search}->{Value},
        NULLValue => 1,
        Silent    => $Param{Silent}
    );
    return if ( !$Condition );

    # return search def
    return {
        Join       => \@SQLJoin,
        Where      => [ $Condition ],
        IsRelative => $Param{Search}->{IsRelative}
    };
}

=begin Internal:

=cut

sub _XMLAttributeGet {
    my ($Self, %Param) = @_;

    # process definition
    for my $Attr ( @{$Param{DefinitionRef}} ) {
        my $Key = $Param{Key} . ".$Attr->{Key}";

        if (  $Attr->{Searchable} ) {
            if ( defined( $Param{AttributesRef}->{ $Key } ) ) {
                push( @{ $Param{AttributesRef}->{ $Key }->{Class} }, $Param{Class} );
                push( @{ $Param{AttributesRef}->{ $Key }->{ClassID} }, $Param{ClassID} );
            }
            else {
                my $ValueType = undef;
                my $Operators;
                if (
                    $Attr->{Input}->{Type} eq 'Date'
                    || $Attr->{Input}->{Type} eq 'DateTime'
                ) {
                    $ValueType = uc( $Attr->{Input}->{Type} );
                    $Operators = ['EQ','NE','LT','LTE','GT','GTE'];
                }
                else {
                    $Operators = ['EQ','NE','IN','!IN','LT','LTE','GT','GTE','ENDSWITH','STARTSWITH','CONTAINS','LIKE'];
                }

                $Param{AttributesRef}->{ $Key } = {
                    IsSearchable => 1,
                    IsSortable   => 0,
                    Class        => [ $Param{Class} ],
                    ClassID      => [ $Param{ClassID} ],
                    Operators    => $Operators,
                    ValueType    => $ValueType
                };
            }
        }

        if ( IsArrayRefWithData( $Attr->{Sub} ) ) {
            $Self->_XMLAttributeGet(
                %Param,
                DefinitionRef => $Attr->{Sub},
                Key           => $Key,
            );
        }
    }

    return 1;
}

=end Internal:

=cut

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
