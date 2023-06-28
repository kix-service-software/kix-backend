# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::I18n::TranslationPatternDelete;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::I18n::TranslationPatternDelete - API Translation Delete Operation backend

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
        'PatternID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        }
    }
}

=item Run()

perform TranslationPatternDelete Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            PatternID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '...'
        Message      => '',                               # In case of an error
        Data         => {
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # start loop
    foreach my $PatternID ( @{$Param{Data}->{PatternID}} ) {

        # get the pattern data
        my %PatternData = $Kernel::OM->Get('Translation')->PatternGet(
            ID     => $PatternID,
            UserID => $Self->{Authorization}->{UserID}
        );

        if ( !IsHashRefWithData( \%PatternData ) ) {

            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # delete the translation
        my $Success = $Kernel::OM->Get('Translation')->PatternDelete(
            ID     => $PatternID,
            UserID => $Self->{Authorization}->{UserID}
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code => 'Object.UnableToDelete'
            );
        }
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
