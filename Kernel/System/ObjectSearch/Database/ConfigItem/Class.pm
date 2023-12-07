# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::ConfigItem::Class;

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

Kernel::System::ObjectSearch::Database::ConfigItem::Class - attribute module for database object search

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
        ClassID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ', 'NE', 'IN','!IN'],
            ValueType    => 'Class.ID'
        },
        ClassIDs => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ', 'NE', 'IN','!IN'],
            ValueType    => 'Class.ID'
        },
        Class => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ', 'NE', 'IN','!IN'],
            ValueType    => 'Class.Name'
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
        Where   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my @SQLWhere;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    my @ClassIDs;
    if ( $Param{Search}->{Field} eq 'Class' ) {
        my %Classes = reverse(
            %{$Kernel::OM->Get('GeneralCatalog')->ItemList(
                Class => 'ITSM::ConfigItem::Class',
            )}
        );

        my @ClassList = ( $Param{Search}->{Value} );
        if ( IsArrayRef($Param{Search}->{Value}) ) {
            @ClassList = @{$Param{Search}->{Value}}
        }
        foreach my $Class ( @ClassList ) {
            if ( !$Classes{$Class} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown asset class $Class!",
                );
                return;
            }

            push( @ClassIDs, $Classes{$Class} );
        }
    }
    else {
        @ClassIDs = ( $Param{Search}->{Value} );
        if ( IsArrayRef($Param{Search}->{Value}) ) {
            @ClassIDs = @{$Param{Search}->{Value}}
        }
    }

    $Param{Flags}->{ClassIDs} = \@ClassIDs;

    my @Where = $Self->GetOperation(
        Operator  => $Param{Search}->{Operator},
        Column    => 'ci.class_id',
        Value     => \@ClassIDs,
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
        Class    => 'gc.name',
        ClassID  => 'ci.class_id',
        ClassIDs => 'ci.class_id',
    );

    my %Join;
    if ( $Param{Attribute} eq 'Class' ) {
        $Join{Join} = [
            'INNER JOIN general_catalog gc ON gc.id = ci.class_id'
        ];
    }

    return {
        Select => [
            $AttributeMapping{$Param{Attribute}}
        ],
        OrderBy => [
            $AttributeMapping{$Param{Attribute}}
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
