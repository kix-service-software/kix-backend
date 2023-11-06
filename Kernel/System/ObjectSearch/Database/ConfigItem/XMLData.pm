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

    $Self->{Supported} = {
        "Data\." => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','LT','LTE','GT','GTE','CONTAINS','ENDSWITH','STARTSWITH']  # ToDo: currently no '-between' are possible
        }
    };

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
    my @SQLJoin;
    my @SQLWhere;

    # check params
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

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

    my $SearchKey = "[1]{'Version'}[1]";
    my @Parts     = split(/[.]/sm, $Param{Search}->{Field});
    foreach my $Part ( @Parts[2..$#Parts] ) {
        $SearchKey .= "{'$Part'}[%]";
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

    my @Where = $Self->GetOperation(
        Operator   => $Param{Search}->{Operator},
        Column     => 'xst.xml_content_value',
        Value      => $Param{Search}->{Value},
        Type       => 'STRING',
        IsOR       => 1,
        Supplement => [' AND ' . $KeyWhere[0]],
        Supported  => $Self->{Supported}->{'Data.'}->{Operators}
    );

    return if !@Where;

    push( @SQLWhere, @Where);

    return {
        SQLJoin  => \@SQLJoin,
        SQLWhere => \@SQLWhere,
    };
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
