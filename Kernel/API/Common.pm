# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Common;

use strict;
use warnings;

use Kernel::Config;
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Common - Base class for all modules

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item _Success()

Take parameters from request processing.
Success reposonse is generated to be passed to provider/requester.

    my $Result = $TransportObject->_Success(
        Code => '...'               # optional return code
        <Content>                   # optional content
    );

    $Result = {
        Success => 1,
        <Content>
    };

=cut

sub _Success {
    my ( $Self, %Param ) = @_;

    # return to provider/requester
    return {
        Success => 1,
        %Param,
    };
}

=item _Error()

Take error parameters from request processing.
Error message is written to debugger, written to environment for response.
Error is generated to be passed to provider/requester.

    my $Result = $TransportObject->_Error(
        Code       => 'Code'        # error code (textual)
        Message    => 'Message',    # error message
        Additional => {             # optional information that can be used in transport backend
            <Header Attribute> => <Value>
        }
    );

    $Result = {
        Success => 0,
        Code    => 'Code'
        Message => 'Message',
    };

=cut

sub _Error {
    my ( $Self, %Param ) = @_;

    # check needed params
    if ( !IsString( $Param{Code} ) ) {
        return $Self->_Error(
            Code      => 'Transport.InternalError',
            Message   => 'Need Code!',
        );
    }

    # log to debugger
    $Self->{DebuggerObject}->Error(
        Summary => $Param{Code}.': '.($Param{Message} || ''),
    );
    
    # return to provider/requester
    return {
        Success => 0,
        %Param,
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
