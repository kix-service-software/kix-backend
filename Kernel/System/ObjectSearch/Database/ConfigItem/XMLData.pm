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
            Key           => 'CurrentVersion.Data'
        );
    }

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
        Where   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my @SQLWhere;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    my @Where;
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
        Supplement => [' AND ' . $KeyWhere[0]],
        Supported  => $Self->{Supported}->{$Field}->{Operators}
    );

    return if !@Where;

    my @SQLJoin = $Self->_GetJoin(%Param);

    push( @SQLWhere, @Where);

    return {
        Join  => \@SQLJoin,
        Where => \@SQLWhere,
    };
}

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

    return if !$Param{DefinitionRef};
    return if ref $Param{DefinitionRef} ne 'ARRAY';

    for my $Attr ( @{$Param{DefinitionRef}} ) {
        my $Key = ($Param{Key} || 'Data') . ".$Attr->{Key}";

        if ( $Self->{Supported}->{$Key} ) {
            push(
                @{$Self->{Supported}->{$Key}->{Class}},
                $Param{Class}
            );
            push(
                @{$Self->{Supported}->{$Key}->{ClassID}},
                $Param{ClassID}
            );
        }
        else {
            $Self->{Supported}->{$Key} = {
                IsSearchable => $Attr->{Searchable} || 0,
                IsSortable   => 0,
                Class        => [$Param{Class}],
                ClassID      => [$Param{ClassID}],
                Operators    => $Attr->{Searchable} ? ['EQ','NE','LT','LTE','GT','GTE','CONTAINS','ENDSWITH','STARTSWITH'] : []
            };
        }


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

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
