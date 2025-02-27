# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ObjectSearch::Database::Contact::Times;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our @ObjectDependencies = qw(
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Contact::Times - attribute module for database object search

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

    return {
        CreateTime => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType    => 'DATETIME'
        },
        ChangeTime => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType    => 'DATETIME'
        }
    };
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
    my $Value;
    my @SQLWhere;

    # check params
    return if !$Self->_CheckSearchParams( %Param );

    # map search attributes to table attributes
    my %AttributeMapping = (
        CreateTime => 'c.create_time',
        ChangeTime => 'c.change_time',
    );

    return q{} if !$Param{Search}->{Value};

    # calculate relative times
    my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
        String => $Param{Search}->{Value}
    );

    if ( !$SystemTime ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Invalid date format found in parameter $Param{Search}->{Field}!",
        );
        return;
    }

    $Value = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
        SystemTime => $SystemTime
    );

    # quote
    $Value = $Kernel::OM->Get('DB')->Quote( $Value );

    my $Condition = $Self->_GetCondition(
        Operator  => $Param{Search}->{Operator},
        Column    => $AttributeMapping{$Param{Search}->{Field}},
        Value     => $Value
    );

    return if ( !$Condition );



    return {
        Where      => [ $Condition ],
        IsRelative => $Param{Search}->{IsRelative}
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
    return if !$Self->_CheckSortParams(%Param);

    # map search attributes to table attributes
    my %AttributeMapping = (
        CreateTime => 'c.create_time',
        ChangeTime => 'c.change_time',
    );

    return {
        Select  => [$AttributeMapping{$Param{Attribute}}],
        OrderBy => [$AttributeMapping{$Param{Attribute}}],
    };
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
