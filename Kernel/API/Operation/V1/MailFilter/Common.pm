# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::MailFilter::Common;

use strict;
use warnings;

use MIME::Base64();

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::MailFilter::Common - Base class for all MailFilter Operations

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=begin Internal:

=item _CheckMailFilter()

checks if the given MailFilter parameter is valid.

    my $Result = $OperationObject->_CheckMailFilter(
        MailFilter => $MailFilter,
    );

    returns:

    $Result = {
        Success => 1,                               # if everything is OK
    }

    $Result = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckMailFilter {
    my ( $Self, %Param ) = @_;

    my $MailFilter = $Param{MailFilter};

    my $XHeaders     = $Kernel::OM->Get('Config')->Get('PostmasterX-Header') || [];
    my %MatchHeaders = ();
    my %SetHeaders   = ();
    for my $Header ( @{$XHeaders} ) {
        if ($Header) {
            $MatchHeaders{$Header} = 1;
            if ( $Header =~ m/^(X-KIX-)/ ) {
                $SetHeaders{$Header} = 1;
            }
        }
    }

    if ( IsArrayRefWithData( $MailFilter->{Match} ) ) {
        my $Index = 1;
        for my $Match ( @{ $MailFilter->{Match} } ) {
            for my $KeyValue (qw(Key Value)) {
                if ( !defined $Match->{$KeyValue} ) {
                    return $Self->_Error(
                        Code    => 'BadRequest',
                        Message => "Element $Index of Match has no $KeyValue!"
                    );
                }
            }
            if ( !$MatchHeaders{ $Match->{Key} } ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Email header '$Match->{Key}' is not supported!"
                );
            }

            my $regex = eval { qr/$Match->{Value}/ };
            if ( $@ ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Element $Match->{Key} of Match has not a valid Regex value ($Match->{Value})!"
                );
            }

            $Index++;
        }
    }

    if ( IsArrayRefWithData( $MailFilter->{Set} ) ) {
        my $Index = 1;
        for my $Set ( @{ $MailFilter->{Set} } ) {
            for my $KeyValue (qw(Key Value)) {
                if ( !defined $Set->{$KeyValue} ) {
                    return $Self->_Error(
                        Code    => 'BadRequest',
                        Message => "Element $Index of Set has no $KeyValue!"
                    );
                }
            }
            if ( !$SetHeaders{ $Set->{Key} } ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Email header '$Set->{Key}' is not supported!"
                );
            }
            $Index++;
        }
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

1;

=end Internal:





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
