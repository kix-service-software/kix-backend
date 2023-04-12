# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Queue::QueueSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Queue::QueueGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Queue::QueueSearch - API Queue Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

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
        'requiredPermission' => {
            Type     => 'HASH',
        }
    }
}

=item Run()

perform QueueSearch Operation. This will return a Queue ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Queue => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform Queue search
    my %QueueList = $Kernel::OM->Get('Queue')->QueueList(
        Valid => 0
    );

    if ( %QueueList && IsHashRefWithData($Param{Data}->{requiredPermission}) && $Param{Data}->{requiredPermission}->{Permission}) {
        my %BasePermissionQueueIDs;

        my $Result = $Kernel::OM->Get('Ticket')->BasePermissionRelevantObjectIDList(
            UserID       => $Self->{Authorization}->{UserID},
            UsageContext => $Self->{Authorization}->{UserType},
            Permission   => $Param{Data}->{requiredPermission}->{Permission},
        );

        if ( IsArrayRefWithData($Result) ) {
            %BasePermissionQueueIDs = (
                %BasePermissionQueueIDs,
                map { $_ => 1 } @{$Result},
            );
        }

        if ( %BasePermissionQueueIDs ) {
            %QueueList = %BasePermissionQueueIDs;
        } elsif ( $Result ne 1 ) {
            %QueueList = ();
        }

        $Self->AddCacheKeyExtension(
            Extension => ['requiredPermission']
        );
    }

    # get already prepared Queue data from QueueGet operation
    if ( %QueueList ) {

        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Queue::QueueGet',
            SuppressPermissionErrors => 1,
            Data      => {
                QueueID => join(',', sort keys %QueueList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Queue} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Queue}) ? @{$GetResult->{Data}->{Queue}} : ( $GetResult->{Data}->{Queue} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Queue => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Queue => [],
    );
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
