# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Validator::MailFilterValidator;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData);

use base qw(
    Kernel::API::Validator::Common
);

# prevent 'Used once' warning for Kernel::OM
use Kernel::System::ObjectManager;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Validator::StateTypeValidator - validator module

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
    my $ValidatorObject = Kernel::API::Validator::MailFilterValidator->new(
        DebuggerObject => $DebuggerObject,
    );

=cut

sub new {
    my ( $MailFilter, %Param ) = @_;

    my $Self = {};
    bless( $Self, $MailFilter );

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

    my $XHeaders     = $Kernel::OM->Get('Kernel::Config')->Get('PostmasterX-Header') || [];
    my %MatchHeaders = ();
    my %SetHeaders   = ();
    for my $Header ( @{$XHeaders} ) {
        if ($Header) {
            $MatchHeaders{$Header} = 1;
            if ( $Header =~ m/^(X-KIX-|X-OTRS-)/ ) {
                $SetHeaders{$Header} = 1;
            }
        }
    }

    if ( $Param{Attribute} eq 'Match' ) {
        if ( IsArrayRefWithData( $Param{Data}->{ $Param{Attribute} } ) ) {
            my $Index = 1;
            for my $Match ( @{ $Param{Data}->{ $Param{Attribute} } } ) {
                for my $KeyValue (qw(Key Value)) {
                    if ( !defined $Match->{$KeyValue} ) {
                        return $Self->_Error(
                            Code    => 'Validator.Failed',
                            Message => "Element $Index of '" . $Param{Attribute} . "' has no $KeyValue!"
                        );
                    }
                }
                if ( !$MatchHeaders{ $Match->{Key} } ) {
                    return $Self->_Error(
                        Code    => 'Validator.Failed',
                        Message => "MailFilterValidator: Key '" . $Match->{Key} . "' of an element in attribute '" . $Param{Attribute} . "' is an unsupported mail header!"
                    );
                }
                $Index++;
            }
        }
    }
    elsif ( $Param{Attribute} eq 'Set' ) {
        if ( IsArrayRefWithData( $Param{Data}->{ $Param{Attribute} } ) ) {
            my $Index = 1;
            for my $Set ( @{ $Param{Data}->{ $Param{Attribute} } } ) {
                for my $KeyValue (qw(Key Value)) {
                    if ( !defined $Set->{$KeyValue} ) {
                        return $Self->_Error(
                            Code    => 'Validator.Failed',
                            Message => "Element $Index of '" . $Param{Attribute} . "' has no $KeyValue!"
                        );
                    }
                }
                if ( !$SetHeaders{ $Set->{Key} } ) {
                    return $Self->_Error(
                        Code    => 'Validator.Failed',
                        Message => "MailFilterValidator: Key '" . $Set->{Key} . "' of an element in attribute '" . $Param{Attribute} . "' is an unsupported mail header!"
                    );
                }
                $Index++;
            }
        }
    }
    else {
        return $Self->_Error(
            Code    => ' Validator . UnknownAttribute ',
            Message => "StateTypeValidator: cannot validate attribute $Param{Attribute}!",
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
