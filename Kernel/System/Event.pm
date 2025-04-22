# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Event;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'DynamicField',
);

=head1 NAME

Kernel::System::Event - events management

=head1 SYNOPSIS

Global module to manage events.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $EventObject = $Kernel::OM->Get('Event');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item EventList()

get a list of available events in the system.

    my %Events = $EventObject->EventList(
        ObjectTypes => ['Ticket', 'Article'],    # optional filter
    );

    returns
    (
        Ticket => ['TicketCreate', 'TicketPriorityUpdate', ...],
        Article => ['ArticleCreate', ...],
    )

=cut

sub EventList {
    my ( $Self, %Param ) = @_;

    my %ObjectTypes = map { $_ => 1 } @{ $Param{ObjectTypes} || [] };

    my %EventConfig = %{ $Kernel::OM->Get('Config')->Get('Events') || {} };

    my %Result;
    for my $ObjectType ( sort keys %EventConfig ) {

        if ( !%ObjectTypes || $ObjectTypes{$ObjectType} ) {
            $Result{$ObjectType} = $EventConfig{$ObjectType};
        }

        # add DF events for this type
        my $DynamicFields = $Kernel::OM->Get('DynamicField')->DynamicFieldList(
            Valid      => 1,
            ObjectType => [ $ObjectType ],
            ResultType => 'HASH',
        );
        if ( IsHashRefWithData($DynamicFields) ) {
            my @DynamicFieldEvents = map {$ObjectType."DynamicFieldUpdate_$_"} sort values %{$DynamicFields};
            push @{ $Result{$ObjectType} || [] }, @DynamicFieldEvents;
        }
    }

    return %Result;

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
