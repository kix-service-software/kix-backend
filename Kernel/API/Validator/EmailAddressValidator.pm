# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Validator::EmailAddressValidator;

use strict;
use warnings;
use Mail::Address;

use base qw(
    Kernel::API::Validator::Common
);

# prevent 'Used once' warning for Kernel::OM
use Kernel::System::ObjectManager;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Validator::EmailAddressValidator - validator module

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
    my $ValidatorObject = Kernel::API::Validator::EmailAddressValidator->new(
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

    my $Valid;
    if ( $Param{Attribute} =~ /^(From|Cc|Bcc|To)$/g ) {
        $Found = 1;
        for my $Email ( Mail::Address->parse( $Param{Data}->{$Param{Attribute}} ) ) {
            if ( !$Kernel::OM->Get('Kernel::System::CheckItem')->CheckEmail( Address => $Email->address() ) ) {
                $Found = 0;
                last;
            }
        }
    }
    else {
        return $Self->_Error(
            Code    => 'Validator.UnknownAttribute',
            Message => 'EmailAddressValidator: cannot validate attribute $Param{Attribute}!',
        );
    }

    if ( !$Valid ) {
        return $Self->_Error(
            Code    => 'Validator.Failed',
            Message => 'Validation of attribute $Param{Attribute} failed!',
        );        
    }

    return $Self->_Success();        
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
