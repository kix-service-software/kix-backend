# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::I18n::TranslationLanguageSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::I18n::TranslationLanguageSearch - API I18n TranslationLanguage Search Operation backend

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
    }
}

=item Run()

perform TranslationLanguageSearch Operation. This will return a list of preferences.

    my $Result = $OperationObject->Run(
        Data => {
            PatternID  => 123
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            TranslationLanguage => [
                ...
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check if pattern already exists
    my %PatternData = $Kernel::OM->Get('Translation')->PatternGet(
        ID => $Param{Data}->{PatternID},
        IncludeAvailableLanguages => 1,
    );
    if ( !%PatternData ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    if ( IsArrayRefWithData($PatternData{AvailableLanguages}) ) {

        # get already prepared Translation data from TranslationLanguageGet operation
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::I18n::TranslationLanguageGet',
            SuppressPermissionErrors => 1,
            Data          => {
                PatternID => $Param{Data}->{PatternID},
                Language      => join(',', @{$PatternData{AvailableLanguages}}),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{TranslationLanguage} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{TranslationLanguage}) ? @{$GetResult->{Data}->{TranslationLanguage}} : ( $GetResult->{Data}->{TranslationLanguage} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                TranslationLanguage => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        TranslationLanguage => [],
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
