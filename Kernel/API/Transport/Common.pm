# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Transport::Common;

use strict;
use warnings;

use Kernel::Config;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Transport::Common - Base class for Transport modules

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ProviderCheckAuthorization()

Empty method to act as an interface

    my $Result = $TransportObject->ProviderCheckAuthorization();

    $Result = {
        Success      => 1,   # 0 or 1
    };

=cut

sub ProviderCheckAuthorization {
    my ( $Self, %Param ) = @_;

    return {
        Success => 1,
    };    
}

=item _MapReturnCode()

Take return code from request processing.
Map the internal return code to transport specific response

    my $MappedCode = $TransportObject->_MapReturnCode(
        Transport => 'REST'        # the specific transport to map to
        Code      => 'Code'        # texttual return code
    );

    $Result = ...

=cut

sub _MapReturnCode {
    my ( $Self, %Param ) = @_;

    # check needed params
    if ( !IsString( $Param{Code} ) ) {
        return $Self->_Error(
            Code    => 'Transport.InternalError',
            Message => 'Need Code!',
        );
    }
    if ( !IsString( $Param{Transport} ) ) {
        return $Self->_Error(
            Code    => 'Transport.InternalError',
            Message => 'Need Transport!',
        );
    }

    # get mapping
    my $Mapping = $Kernel::OM->Get('Config')->Get('API::Transport::ReturnCodeMapping');
    if ( !IsHashRefWithData($Mapping) ) {
        return $Self->_Error(
            Code    => 'Transport.InternalError',
            Message => 'No ReturnCodeMapping config!',
        );        
    }

    if ( !IsHashRefWithData($Mapping->{$Param{Transport}}) ) {
        # we don't have a mapping for the given transport, so just return the given code without mapping
        return $Param{Code};
    }
    my $TransportMapping = $Mapping->{$Param{Transport}};

    # get map entry
    my ($MappedCode, $MappedMessage) = split(/:/, $TransportMapping->{$Param{Code}} || $TransportMapping->{'DEFAULT'});
    
    # override defualt message from mapping if we have some special message
    if ( !$MappedMessage || $Param{Message} ) {
        $MappedMessage = $Param{Message} || ''; 
    }

    # log to debugger
    $Self->{DebuggerObject}->Debug(
        Summary => $MappedCode.': '.($MappedMessage || ''),
    );

    # return
    return "$MappedCode:$MappedMessage";
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
