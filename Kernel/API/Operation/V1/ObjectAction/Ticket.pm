# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::ObjectAction::Ticket;

use strict;
use warnings;

use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::API::Operation::V1::ObjectAction::Common);

our @ObjectDependencies = (
    'Config'
);

=head1 NAME

Kernel::API::Operation::V1::ObjectAction::Ticket

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $MacroActionObject = $Kernel::OM->Get('Automation::MacroAction::Common');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ObjectName} = 'Ticket';

    return $Self;
}

sub ActionList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Object ObjectID) ) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }    

    my $TicketObject = $Kernel::OM->Get('Ticket');
    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{ObjectID}
    );

    if(!%Ticket) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to require Ticket!"
        );  
        return;
    }

    my $QueueObject = $Kernel::OM->Get('Queue');
    my %Queue = $QueueObject->QueueGet(
        ID => $Ticket{QueueID}
    );    

    if(%Queue) {
        $Ticket{Queue} = \%Queue;
    }

    my @AllObjectActions = $Kernel::OM->Get('ObjectAction')->ObjectActionList(
        Object   => $Param{Object}
    );    

    my @Result = ();
    
    if ( IsHashRefWithData( \%Ticket ) ) {
        for my $ObjectAction (@AllObjectActions) {

            my $match = 1;

            if ( $ObjectAction->{Filter} ) {
                $match = $Self->_CheckFilter(
                    Ticket  => \%Ticket,
                    Filter  => $ObjectAction->{Filter}
                );
            }            

            if ( $match ) {
                push(@Result, $ObjectAction);    
            }
        }
    }

    return @Result;
}

sub _CheckFilter() {
    my ( $Self, %Param ) = @_;

    for my $Filter ( @{ $Param{Filter} } ) {
        my @TicketArray = ( $Param{Ticket} );
        my $Data = {
            Ticket => \@TicketArray
        };

        my $Result = $Self->_ApplyFilter(
            Filter => $Filter,
            Data   => $Data
        );

        my $TicketCount = (scalar @{ $Data->{Ticket} } );
        if ( $TicketCount gt 0 ) {
            return 1;
        }
    }

    return 0;
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