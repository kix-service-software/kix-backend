# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Session::SessionDelete;
use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsStringWithData IsHashRefWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Session::SessionDelete - API Logout Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

remove token (invalidate)

    my $Result = $OperationObject->Run(
        Data => {
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Kernel::OM->Get('Token')->RemoveToken(
        Token => $Self->{Authorization}->{Token}
    );

    # check result
    if ( !$Result ) {
        return $Self->_Error(
            Code => 'Object.UnableToDelete',
        );
    }

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
