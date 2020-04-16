# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Validator::HistoryTypeValidator;

use strict;
use warnings;

use base qw(
    Kernel::API::Validator::Common
);

# prevent 'Used once' warning for Kernel::OM
use Kernel::System::ObjectManager;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Validator::HistoryTypeValidator - validator module

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object.

    use Kernel::API::Debugger;
    use Kernel::API::Validator;

    my $DebuggerObject = Kernel::API::Debugger->new(
        DebuggerConfig   => {
            DebugThreshold  => 'debug',
            TestMode        => 0,           # optional, in testing mode the data will not be written to the DB
            # ...
        },
        WebserviceID      => 12,
        CommunicationType => Requester, # Requester or Provider
        RemoteIP          => 192.168.1.1, # optional
    );
    my $ValidatorObject = Kernel::API::Validator::HistoryTypeValidator->new(
        DebuggerObject => $DebuggerObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    for my $Needed (qw( DebuggerObject)) {
        $Self->{$Needed} = $Param{$Needed} || return $Self->_Error(
            Code    => 'Validator.InternalError',
            Message => "Got no $Needed!",
        );
    }

    return $Self;
}

=item Validate()

validate given data attribute

    my $Result = $ValidatorObject->Validate(
        Attribute => '...',                     # required
        Data      => {                          # required but may be empty
            ...
        }
    );

    $Result = {
        Success         => 1,                   # 0 or 1
        ErrorMessage    => '',                  # in case of error
    };

=cut

sub Validate {
    my ( $Self, %Param ) = @_;

    # check params
    if ( !$Param{Attribute} ) {
        return $Self->_Error(
            Code    => 'Validator.InternalError',
            Message => 'Got no Attribute!',
        );
    }

    my $Found;
    if ( $Param{Attribute} eq 'HistoryTypeID' ) {
        $Found = $Kernel::OM->Get('Ticket')->HistoryTypeLookup(
            TypeID => $Param{Data}->{$Param{Attribute}},
        );        
    }
    elsif ( $Param{Attribute} eq 'HistoryType' ) {
        $Found = $Kernel::OM->Get('Ticket')->HistoryTypeLookup(
            Type => $Param{Data}->{$Param{Attribute}},
        );      
    }
    else {
        return $Self->_Error(
            Code    => 'Validator.UnknownAttribute',
            Message => "HistoryTypeValidator: cannot validate attribute $Param{Attribute}!",
        );
    }

    if ( !$Found ) {
        return $Self->_Error(
            Code    => 'Validator.Failed',
            Message => "Validation of attribute $Param{Attribute} failed!",
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
