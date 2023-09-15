# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Validator::ContentTypeValidator;

use strict;
use warnings;
use Encode;

use Kernel::API::Validator::CharsetValidator;
use Kernel::API::Validator::MimeTypeValidator;

use base qw(
    Kernel::API::Validator::Common
);

# prevent 'Used once' warning for Kernel::OM
use Kernel::System::ObjectManager;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Validator::ContentTypeValidator - validator module

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

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

    if ( $Param{Attribute} eq 'ContentType' ) {
        my $ContentType = lc($Param{Data}->{$Param{Attribute}});

        if ( $ContentType =~ m/\R/ ) {
            return $Self->_Error(
                Code    => 'Validator.Failed',
                Message => "Validation of attribute $Param{Attribute} ($Param{Data}->{$Param{Attribute}}) failed! Line breaks are not allowed!",
            );
        }

        # check Charset part
        if ( $ContentType =~ /charset=/i ) {
            my $Charset = $ContentType;
            $Charset =~ s/.+?charset=("|'|)(\w+)/$2/gi;
            $Charset =~ s/"|'//g;
            $Charset =~ s/(.+?);.*/$1/g;
            my $Result = Kernel::API::Validator::CharsetValidator::Validate(
                $Self,
                Attribute => 'Charset',
                Data      => {
                    Charset => $Charset,
                }
            );
            if (!$Result->{Success}) {
                return $Self->_Error(
                    Code    => 'Validator.Failed',
                    Message => "Validation of attribute $Param{Attribute} ($Param{Data}->{$Param{Attribute}}) failed! Invalid Charset!",
                );
            }
        }

        # check MimeType part
        my $MimeType = q{};
        if ( $ContentType =~ /^(\w+\/[-.\w]+(?:\+[-.\w]+)?)/i ) {
            $MimeType = $1;
            $MimeType =~ s/["']//g;
        }
        elsif ( $ContentType eq 'text' || !$ContentType ) {
            return $Self->_Success();
        }
        my $Result = Kernel::API::Validator::MimeTypeValidator::Validate(
            $Self,
            Attribute => 'MimeType',
            Data      => {
                MimeType => $MimeType,
            }
        );
        if (!$Result->{Success}) {
            return $Self->_Error(
                Code    => 'Validator.Failed',
                Message => "Validation of attribute $Param{Attribute} ($Param{Data}->{$Param{Attribute}}) failed! Invalid MimeType!",
            );
        }
    }
    else {
        return $Self->_Error(
            Code    => 'Validator.UnknownAttribute',
            Message => "ContentTypeValidator: cannot validate attribute $Param{Attribute}!",
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
