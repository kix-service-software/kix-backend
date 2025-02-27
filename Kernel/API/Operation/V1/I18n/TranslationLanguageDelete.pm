# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::I18n::TranslationLanguageDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::I18n::TranslationLanguageDelete - API TranslationLanguage Delete Operation backend

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
            Required => 1
        },
        'Language' => {
            DataType => 'STRING',
            Required => 1
        },
    }
}

=item Run()

perform TranslationLanguageDelete Operation. This will return success.

    my $Result = $OperationObject->Run(
        Data => {
            PatternID  => 12,
            Language       => 'de',
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check if pattern already exists
    my %PatternData = $Kernel::OM->Get('Translation')->PatternGet(
        ID => $Param{Data}->{PatternID},
    );
    if ( !%PatternData ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    # check if language entry exists
    my %TranslationList = $Kernel::OM->Get('Translation')->TranslationLanguageList(
        PatternID => $Param{Data}->{PatternID},
    );
    if ( !IsHashRefWithData(\%TranslationList) || !$TranslationList{$Param{Data}->{Language}} ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # delete translation Language
    my $Success = $Kernel::OM->Get('Translation')->TranslationLanguageDelete(
        PatternID => $Param{Data}->{PatternID},
        Language  => $Param{Data}->{Language},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToDelete',
        );
    }

    # return result
    return $Self->_Success();
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
