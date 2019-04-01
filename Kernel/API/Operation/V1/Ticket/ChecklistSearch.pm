# --
# Kernel/API/Operation/User/ArticleFlagSearch.pm - API User Search operation backend
# based upon Kernel/API/Operation/Ticket/TicketSearch.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::ChecklistSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Ticket::ChecklistSearch - API ChecklistSearch Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'TicketID' => {
            Required => 1
        },
    }
}

=item Run()

perform TicketChecklistSearch Operation. This will return a checklist item list.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID  => 1'                                             # required 
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                                    # In case of an error
        Data         => {
            ChecklistItem => [
                {
                },
                {
                }
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Checklist = $Kernel::OM->Get('Kernel::System::Ticket')->TicketChecklistGet(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( IsHashRefWithData($Checklist) ) {

        return $Self->_Success(
            ChecklistItem => [ map {$Checklist->{$_}} sort keys %{$Checklist} ],
        )
    }

    # return result
    return $Self->_Success(
        ChecklistItem => [],
    );
}

1;
