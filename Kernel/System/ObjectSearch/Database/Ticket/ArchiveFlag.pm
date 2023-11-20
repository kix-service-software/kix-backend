# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::ArchiveFlag;

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

Kernel::System::ObjectSearch::Database::Ticket::ArchiveFlag - attribute module for database object search

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
        Archived => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'Flag.y/n'
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

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    if ( !$Kernel::OM->Get('Config')->Get('Ticket::ArchiveSystem') ) {
        # do nothing if archive system is not used
        return {};
    }

    # check params
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    my $Value;
    my %Flags;
    if ( IsArrayRef( $Param{Search}->{Value} ) ) {
        %Flags = map{ lc( $_ ) => 1 } @{ $Param{Search}->{Value} };
    }
    else {
        $Flags{ lc( $Param{Search}->{Value} ) } = 1;
    }

    # both flags are set
    if (
        (
            $Flags{0}
            || $Flags{n}
        )
        && (
            $Flags{1}
            || $Flags{y}
        )
    ) {
        $Value = [0,1];
    }
    # active flag is set
    elsif(
        $Flags{1}
        || $Flags{y}
    ) {
        $Value = 1;
    }
    # inactive flag is set
    elsif(
        $Flags{0}
        || $Flags{n}
    ) {
        $Value = 0;
    }

    # check mappend value
    if (
        !defined( $Value )
        && (
            ref( $Param{Search}->{Value} ) ne 'ARRAY'
            || @{ $Param{Search}->{Value} }
        )
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid search value!",
            );
        }
        return;
    }

    # switch to IN-based operation, if value is array
    if (
        $Param{Search}->{Operator} !~ m/IN$/
        && ref( $Value ) eq 'ARRAY'
    ) {
        if ( $Param{Search}->{Operator} eq 'EQ' ) {
            $Param{Search}->{Operator} = 'IN';
        }
        else {
            $Param{Search}->{Operator} = '!IN';
        }
    }

    # convert value to array if operation is IN-based
    if (
        $Param{Search}->{Operator} =~ m/IN$/
        && ref( $Value ) ne 'ARRAY'
    ) {
        # fallback to empty array, if value is undefined
        if ( !defined( $Value ) ) {
            $Value = [];
        }
        else {
            $Value = [ $Value ];
        }
    }

    my @SQLWhere;
    my @Where = $Self->GetOperation(
        Operator  => $Param{Search}->{Operator},
        Column    => 'st.archive_flag',
        Value     => $Value,
        Type      => 'NUMERIC',
        Supported => $Self->{Supported}->{$Param{Search}->{Field}}->{Operators},
        Silent    => $Param{Silent}
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

    if ( !$Kernel::OM->Get('Config')->Get('Ticket::ArchiveSystem') ) {
        # do nothing if archive system is not used
        return [];
    }

    return {
        Select => [
            'st.archive_flag'
        ],
        OrderBy => [
            'st.archive_flag'
        ],
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
