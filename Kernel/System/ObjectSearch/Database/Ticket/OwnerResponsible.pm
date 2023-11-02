# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::OwnerResponsible;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::Common
);

our @ObjectDependencies = qw(
    Config
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::OwnerResponsible - attribute module for database object search

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
        'OwnerID'       => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','IN','!IN','NE','LT','LTE','GT','GTE']
        },
        'Owner'         => {
            IsSearchable => 0,
            IsSortable   => 1,
            Operators    => []
        },
        'ResponsibleID' => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','IN','!IN','NE','LT','LTE','GT','GTE']
        },
        'Responsible'    => {
            IsSearchable => 0,
            IsSortable   => 1,
            Operators    => []
        },
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

    my %AttributeMapping = (
        'OwnerID'       => 'st.user_id',
        'ResponsibleID' => 'st.responsible_user_id',
    );

    my @SQLWhere;
    my @Where = $Self->GetOperation(
        Operator  => $Param{Search}->{Operator},
        Column    => $AttributeMapping{$Param{Search}->{Field}},
        Value     => $Param{Search}->{Value},
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

    my %AttributeMapping = (
        Owner         => ['co.lastname', 'co.firstname'],
        Responsible   => ['cr.lastname', 'cr.firstname'],
        OwnerID       => ['st.user_id'],
        ResponsibleID => ['st.responsible_user_id'],
    );

    my %Join;
    if ( $Param{Attribute} eq 'Owner' ) {
        $Join{SQLJoin} = [
            'INNER JOIN contact co ON co.user_id = st.user_id'
        ];
    }
    elsif ( $Param{Attribute} eq 'Responsible' ) {
        $Join{SQLJoin} = [
            'INNER JOIN contact cr ON cr.user_id = st.responsible_user_id'
        ];
    }

    return {
        SQLAttrs   => $AttributeMapping{$Param{Attribute}},
        SQLOrderBy => $AttributeMapping{$Param{Attribute}},
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
