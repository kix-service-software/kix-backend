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
        Search => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    $Self->{SupportedSearch} = {
        'TypeID' => ['EQ','IN','!IN','NE','GT','GTE','LT','LTE']
    };

    $Self->{SupportedSort} = [
        'TypeID',
        'Type'
    ];

    return {
        Search => $Self->{SupportedSearch},
        Sort   => $Self->{SupportedSort}
    };
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

    # check params
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    my @TypeIDs;
    if ( $Param{Search}->{Field} eq 'Type' ) {
        my @TypeList = ( $Param{Search}->{Value} );
        if ( IsArrayRefWithData($Param{Search}->{Value}) ) {
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
        if ( IsArrayRefWithData($Param{Search}->{Value}) ) {
            @TypeIDs = @{$Param{Search}->{Value}}
        }
    }

    my @SQLWhere;
    my @Where = $Self->GetOperation(
        Operator  => $Param{Search}->{Operator},
        Column    => 'st.type_id',
        Value     => \@TypeIDs,
        Type      => 'NUMERIC',
        Supported => $Self->{SupportedSearch}->{$Param{Search}->{Field}}
    );

    return if !@Where;

    push( @SQLWhere, @Where);

    return {
        SQLWhere => \@SQLWhere,
    };
}

=item Sort()

run this module and return the SQL extensions

    my $Result = $Object->Sort(
        Attribute => '...'      # required
    );

    $Result = {
        SQLAttrs   => [ ],          # optional
        SQLOrderBy => [ ]           # optional
    };

=cut

sub Sort {
    my ( $Self, %Param ) = @_;

    # map search attributes to table attributes
    my %AttributeMapping = (
        Type    => 'COALESCE(tl.value, tt.name) AS TanslateName',
        TypeID  => 'st.type_id',
    );

    my %OrderMapping = (
        Type    => 'TanslateName',
        TypeID  => 'st.type_id',
    );

    my %Join;
    if ( $Param{Attribute} eq 'Type' ) {
        $Join{SQLJoin} = [
            'INNER JOIN ticket_type tt ON tt.id = st.type_id',
	        'LEFT OUTER JOIN translation_pattern tlp ON tlp.value = tt.name',
            "LEFT OUTER JOIN translation_language tl ON tl.pattern_id = tlp.id AND tl.language = '$Param{Language}'"
        ];
    }
    return {
        SQLAttrs => [
            $AttributeMapping{$Param{Attribute}}
        ],
        SQLOrderBy => [
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
