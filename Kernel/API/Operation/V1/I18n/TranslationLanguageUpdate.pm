# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::I18n::TranslationLanguageUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::I18n::TranslationLanguageUpdate - API TranslationLanguage Update Operation backend

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
            Required => 1
        },
        'Language' => {
            Required => 1
        },
        'TranslationLanguage' => {
            Type     => 'HASH',
            Required => 1
        },
        'TranslationLanguage::Value' => {
            Required => 1
        },
    }
}

=item Run()

perform TranslationLanguageUpdate Operation. This will return success.

    my $Result = $OperationObject->Run(
        Data => {
            PatternID       => 12,
            Language => '...',
            TranslationLanguage   => {
                Value => '...'
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            Language => '...'
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Language parameter
    my $Language = $Self->_Trim(
        Data => $Param{Data}->{TranslationLanguage},
    );

    # check if pattern already exists
    my %PatternData = $Kernel::OM->Get('Translation')->PatternGet(
        ID => $Param{Data}->{PatternID},
    );
    if ( !%PatternData ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    # get the Translation data
    my %TranslationData = $Kernel::OM->Get('Translation')->TranslationLanguageGet(
        PatternID => $Param{Data}->{PatternID},
        Language  => $Param{Data}->{Language},
        UserID    => $Self->{Authorization}->{UserID}
    );

    if ( !IsHashRefWithData( \%TranslationData ) ) {

        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # update language
    my $Success = $Kernel::OM->Get('Translation')->TranslationLanguageUpdate(
        PatternID => $Param{Data}->{PatternID},
        Language  => $Param{Data}->{Language},
        Value     => $Language->{Value},
        UserID    => $Self->{Authorization}->{UserID}
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result
    return $Self->_Success(
        Language => $Param{Data}->{Language}
    );
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
