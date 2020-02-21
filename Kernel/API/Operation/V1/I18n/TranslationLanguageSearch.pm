# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
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

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

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
    my %PatternData = $Kernel::OM->Get('Kernel::System::Translation')->PatternGet(
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
        my $TranslationLanguageGetResult = $Self->ExecOperation(
            OperationType => 'V1::I18n::TranslationLanguageGet',
            Data          => {
                PatternID => $Param{Data}->{PatternID},
                Language      => join(',', @{$PatternData{AvailableLanguages}}),
            }
        );
        if ( !IsHashRefWithData($TranslationLanguageGetResult) || !$TranslationLanguageGetResult->{Success} ) {
            return $TranslationLanguageGetResult;
        }

        my @ResultList = IsArrayRef($TranslationLanguageGetResult->{Data}->{TranslationLanguage}) ? @{$TranslationLanguageGetResult->{Data}->{TranslationLanguage}} : ( $TranslationLanguageGetResult->{Data}->{TranslationLanguage} );
        
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
