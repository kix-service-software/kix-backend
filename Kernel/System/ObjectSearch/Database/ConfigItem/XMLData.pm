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
        Type => 'ITSMConfigurationManagement',
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
    my @SQLWhere;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    my $Field;

    my $SearchKey = "[1]{'Version'}[1]";
    my @Parts     = split(/[.]/sm, $Param{Search}->{Field});

    if ( scalar( @Parts ) > 1 ) {
        $Field = 'CurrentVersion.Data';
    }

    foreach my $Part ( @Parts[2..$#Parts] ) {
        $SearchKey .= "{'$Part'}[%]";
        $Field     .= ".$Part";
    }
    $SearchKey .= "{'Content'}";

    my $KeyCondition = $Self->_GetCondition(
        Operator         => 'LIKE',
        Column           => 'xst.xml_content_key',
        Value            => $SearchKey
    );

    my $Condition = $Self->_GetCondition(
        Operator   => $Param{Search}->{Operator},
        Column     => 'xst.xml_content_value',
        Value      => $Param{Search}->{Value},
        Type       => 'STRING',
        Supplement => [ $KeyCondition ]
    );

    return if ( !$Condition );

    my @SQLJoin = $Self->_GetJoin(%Param);



    return {
        Join  => \@SQLJoin,
        Where => [ $Condition ]
    };
}

=begin Internal:

=cut

sub _GetJoin {
    my ($Self, %Param) = @_;

    my @JoinAND;
    if (
        $Param{Flags}->{ClassIDs}
        && !$Param{Flags}->{JoinXML}
    ) {

        my @Types;
        for my $ClassID ( @{$Param{Flags}->{ClassIDs}}) {
            if ( $Param{Flags}->{PreviousVersion} ) {
                push (@Types, 'ITSM::ConfigItem::Archiv::' . $ClassID);
            }
            push (@Types, 'ITSM::ConfigItem::' . $ClassID)
        }
        @JoinAND = $Self->_GetCondition(
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
                'LEFT OUTER JOIN configitem_version vr on ci.id = vr.configitem_id'
            );
            $Param{Flags}->{JoinVersion} = 1;
        }
        if ( !$Param{Flags}->{JoinXML} ) {

            push(
                @SQLJoin,
                'LEFT OUTER JOIN xml_storage xst on vr.id = CAST(xst.xml_key AS BIGINT)'
                . (@JoinAND ? ' AND ' . $JoinAND[0] : q{})
            );
            $Param{Flags}->{JoinXML} = 1;
        }
    }
    elsif ( !$Param{Flags}->{JoinXML} ) {
        push(
            @SQLJoin,
            'LEFT OUTER JOIN xml_storage xst on ci.last_version_id = CAST(xst.xml_key AS BIGINT)'
            . (@JoinAND ? ' AND ' . $JoinAND[0] : q{})
        );
        $Param{Flags}->{JoinXML} = 1;
    }

    return @SQLJoin;
}

sub _XMLAttributeGet {
    my ($Self, %Param) = @_;

    # process definition
    for my $Attr ( @{$Param{DefinitionRef}} ) {
        my $Key = $Param{Key} . ".$Attr->{Key}";

        if ( defined( $Param{AttributesRef}->{ $Key } ) ) {
            push( @{ $Param{AttributesRef}->{ $Key }->{Class} }, $Param{Class} );
            push( @{ $Param{AttributesRef}->{ $Key }->{ClassID} }, $Param{ClassID} );
        }
        else {
            $Param{AttributesRef}->{$Key} = {
                IsSearchable => $Attr->{Searchable} || 0,
                IsSortable   => 0,
                Class        => [ $Param{Class} ],
                ClassID      => [ $Param{ClassID} ],
                Operators    => $Attr->{Searchable} ? ['EQ','NE','IN','!IN','LT','LTE','GT','GTE','ENDSWITH','STARTSWITH','CONTAINS','LIKE'] : []
            };
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
