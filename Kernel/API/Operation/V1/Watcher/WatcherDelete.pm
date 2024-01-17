# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Watcher::WatcherDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Watcher::WatcherDelete - API WatcherDelete Operation backend

=head1 SYNOPSIS

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
        'WatcherID' => {
            DataType => 'NUMERIC',
            Required => 1
        },
    }
}

=item Run()

perform WatcherDelete Operation. This will return nothing.

    my $Result = $OperationObject->Run(
        Data => {
            WatcherID => 1                                     # required
        },
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check if Watcher exists
    my %WatcherData = $Kernel::OM->Get('Watcher')->WatcherGet(
        ID => $Param{Data}->{WatcherID}
    );

    if ( !%WatcherData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    my $Success = $Kernel::OM->Get('Watcher')->WatcherDelete(
        ID     => $Param{Data}->{WatcherID},
        UserID => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToDelete',
            Message => 'Unable to to delete Watcher, please contact system administrator!',
        );
    }

    # return result
    return $Self->_Success();
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
