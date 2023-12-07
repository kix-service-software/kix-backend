# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::Type;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::Common
);

our @ObjectDependencies = qw(
    Config
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Type - attribute module for database object search

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
        'TypeID' => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','IN','!IN','NE','GT','GTE','LT','LTE'],
            ValueType    => 'Integer'
        },
        'Type' => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => []
        },
    };

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

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    my @TypeIDs;
    if ( $Param{Search}->{Field} eq 'Type' ) {
        my @TypeList = ( $Param{Search}->{Value} );
        if ( IsArrayRef($Param{Search}->{Value}) ) {
            @TypeList = @{$Param{Search}->{Value}}
        }
        foreach my $Type ( @TypeList ) {
            my $TypeID = $Kernel::OM->Get('Type')->TypeLookup(
                Type => $Type,
            );
            if ( !$TypeID ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown Type $Type!",
                );
                return;
            }

            push( @TypeIDs, $TypeID );
        }
    }
    else {
        @TypeIDs = ( $Param{Search}->{Value} );
        if ( IsArrayRef($Param{Search}->{Value}) ) {
            @TypeIDs = @{$Param{Search}->{Value}}
        }
    }

    my @SQLWhere;
    my @Where = $Self->GetOperation(
        Operator  => $Param{Search}->{Operator},
        Column    => 'st.type_id',
        Value     => \@TypeIDs,
        Type      => 'NUMERIC',
        Supported => $Self->{Supported}->{$Param{Search}->{Field}}->{Operators}
    );

    return if !@Where;

    push( @SQLWhere, @Where);

    return {
        Where => \@SQLWhere,
    };
}

=item Sort()

run this module and return the SQL extensions

    my $Result = $Object->Sort(
        Attribute => '...'      # required
    );

    $Result = {
        Select   => [ ],          # optional
        OrderBy => [ ]           # optional
    };

=cut

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSortParams(%Param) );

    # map search attributes to table attributes
    my %AttributeMapping = (
        Type    => 'COALESCE(tl.value, tt.name) AS TranslateType',
        TypeID  => 'st.type_id',
    );

    my %OrderMapping = (
        Type    => 'TranslateType',
        TypeID  => 'st.type_id',
    );

    my %Join;
    if ( $Param{Attribute} eq 'Type' ) {
        $Join{Join} = [
            'INNER JOIN ticket_type tt ON tt.id = st.type_id',
	        'LEFT OUTER JOIN translation_pattern tlp ON tlp.value = tt.name',
            "LEFT OUTER JOIN translation_language tl ON tl.pattern_id = tlp.id AND tl.language = '$Param{Language}'"
        ];
    }
    return {
        Select => [
            $AttributeMapping{$Param{Attribute}}
        ],
        OrderBy => [
            $OrderMapping{$Param{Attribute}}
        ],
        %Join
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
