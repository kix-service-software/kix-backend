# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::Base;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    Config
    Ticket
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Base - base module for object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item GetBackends()

empty method to be overridden by specific attribute module if necessary

    $Object->GetBackends();

=cut

sub GetBackends {
    my ( $Self, %Param ) = @_;

    my $Backends = $Kernel::OM->Get('Config')->Get('ObjectSearch::Database::Ticket::Module');
    my %AttributeModules;

    if ( !IsHashRefWithData($Backends) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No database search backend modules found!",
        );
        return;
    }

    BACKEND:
    foreach my $Backend ( sort keys %{$Backends} ) {

        my $Object = $Kernel::OM->Get($Backends->{$Backend}->{Module});

        # register module for each supported attribute
        my $SupportedAttributes = $Object->GetSupportedAttributes();
        if ( !IsHashRefWithData($SupportedAttributes) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "SupportedAttributes return by module $Backends->{$Backend}->{Module} are not a HashRef!",
            );
            next BACKEND;
        }

        foreach my $Attribute ( sort keys %{$SupportedAttributes} ) {
            $AttributeModules{$Attribute} = $SupportedAttributes->{$Attribute} || {};
            $AttributeModules{$Attribute}->{Object} = $Object;
        }
    }

    $Self->{AttributeModules} = \%AttributeModules;
    return \%AttributeModules;
}

sub BaseSQL {
    my ( $Self, %Param ) = @_;

    return {
        Select => 'SELECT DISTINCT(st.id), st.tn',
        From   => 'FROM ticket st',
        Where  => ' 1=1'
    };
}

sub BaseFlags {
    my ( $Self, %Param ) = @_;

    my %Result;

    return %Result;
}

=item CreatePermissionSQL()

generate SQL for ticket permission restrictions

    my %SQL = $Object->CreatePermissionSQL(
        UserID    => ...,                    # required
        UserType  => 'Agent' | 'Customer'    # required
    );

=cut

sub CreatePermissionSQL {
    my ( $Self, %Param ) = @_;
    my %Result;

    if (
        !$Param{UserID}
        || !$Param{UserType}
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No user information for permission check!',
        );
        return;
    }

    my $QueueIDs = $Kernel::OM->Get('Ticket')->BasePermissionRelevantObjectIDList(
        %Param,
        Types        => ['Base::Ticket'],
        UsageContext => $Param{UserType},
        Permission   => 'READ',
    );

    if ( IsArrayRef($QueueIDs) ) {
        $Result{From}  = 'INNER JOIN queue q ON q.id = st.queue_id ';
        $Result{Where} = 'q.id IN (' . join(q{,}, @{$QueueIDs}) . q{)};
    }

    return %Result;
}


sub SupportedList {
    my ( $Self, %Param ) = @_;

    my @List;
    for my $Attribute ( sort keys %{$Self->{AttributeModules}} ) {
        my $Module    = $Self->{AttributeModules}->{$Attribute};
        my $Property  = $Attribute;
        push (
            @List,
            {
                ObjectType      => 'Ticket',
                Property        => $Property,
                ObjectSpecifics => undef,
                IsSearchable    => $Module->{IsSearchable} || 0,
                IsSortable      => $Module->{IsSortable}   || 0,
                Operators       => $Module->{Operators}    || []
            }
        );
    }

    return \@List;
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
