# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Validator::MimeTypeValidator;

use strict;
use warnings;

use MIME::Types;

use base qw(
    Kernel::API::Validator::Common
);

# prevent 'Used once' warning for Kernel::OM
use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Validator::MimeTypeValidator - validator module

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

    my $Valid;
    if ( $Param{Attribute} eq 'MimeType' ) {

        if ( !$Self->{MimeTypeList} ) {
            my $MimeObject = MIME::Types->new();
            %{$Self->{MimeTypeList}} = map { $_ => 1 } $MimeObject->listTypes();
        }

        my %MimeTypes = %{$Self->{MimeTypeList}};
        if (
            IsHashRefWithData($Param{Parameters})
            && IsHashRefWithData($Param{Parameters}->{MimeTypes})
        ) {
            for my $Type ( keys %{$Param{Parameters}->{MimeTypes}} ) {
                next if $MimeTypes{$Type};
                $MimeTypes{$Type} = 1;
            }
        }
        $Valid = $MimeTypes{$Param{Data}->{$Param{Attribute}}} || 0;
    }
    else {
        return $Self->_Error(
            Code    => 'Validator.UnknownAttribute',
            Message => "MimeTypeValidator: cannot validate attribute $Param{Attribute}!",
        );
    }

    if ( !$Valid ) {
        return $Self->_Error(
            Code    => 'Validator.Failed',
            Message => "Validation of attribute $Param{Attribute} ($Param{Data}->{$Param{Attribute}}) failed!",
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
