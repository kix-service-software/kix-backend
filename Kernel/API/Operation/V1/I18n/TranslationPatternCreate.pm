# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::I18n::TranslationPatternCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::I18n::TranslationPatternCreate - API TranslationPatternCreate Operation backend

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
        'TranslationPattern' => {
            Type     => 'HASH',
            Required => 1
        },
        'TranslationPattern::Value' => {
            Required => 1
        },
    }
}

=item Run()

perform TranslationPatternCreate Operation. This will return the created TranslationID.

    my $Result = $OperationObject->Run(
        Data => {
            TranslationPattern => {
                Value     => '...'                                        # required
                Languages => [                                            # optional
                    {
                        Language  => '...',
                        Value => '...'
                    }
                ]
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            TranslationID  => '',                   # TranslationID
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim TranslationPattern parameter
    my $TranslationPattern = $Self->_Trim(
        Data => $Param{Data}->{TranslationPattern},
    );

    # check if pattern exists
    my $Exists = $Kernel::OM->Get('Translation')->PatternExistsCheck(
        Value  => $TranslationPattern->{Value},
        UserID => $Self->{Authorization}->{UserID}
    );
    if ( $Exists ) {
        return $Self->_Error(
            Code => 'Object.AlreadyExists',
        );
    }

    # create pattern
    my $PatternID = $Kernel::OM->Get('Translation')->PatternAdd(
        Value  => $TranslationPattern->{Value},
        UserID => $Self->{Authorization}->{UserID},
    );
    if ( !$PatternID ) {
        return $Self->_Error(
            Code => 'Object.UnableToCreate',
        );
    }

    # add preferences
    if ( IsArrayRefWithData($TranslationPattern->{Languages}) ) {

        foreach my $Language ( @{$TranslationPattern->{Languages}} ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::I18n::TranslationLanguageCreate',
                Data          => {
                    PatternID           => $PatternID,
                    TranslationLanguage => $Language
                }
            );

            if ( !$Result->{Success} ) {
                return $Result;
            }
        }
    }

    return $Self->_Success(
        Code      => 'Object.Created',
        PatternID => $PatternID,
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
