# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::I18n::TranslationLanguageGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::I18n::TranslationLanguageGet - API TranslationLanguageGet Operation backend

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
            Type     => 'ARRAY',
            Required => 1
        }
    }
}

=item Run()

perform TranslationGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            PatternID => 123,
            Language      => '...'     # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '...'
        Message      => '',                               # In case of an error
        Data         => {
            TranslationLanguage => [
                {
                    ...
                },
                {
                    ...
                },
            ]
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

    my @TranslationLanguageList;

    # start loop
    foreach my $Language ( @{$Param{Data}->{Language}} ) {

        # get the Translation data
        my %TranslationData = $Kernel::OM->Get('Translation')->TranslationLanguageGet(
            PatternID => $Param{Data}->{PatternID},
            Language  => $Language,
            UserID    => $Self->{Authorization}->{UserID}
        );

        if ( !IsHashRefWithData( \%TranslationData ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # add
        push(@TranslationLanguageList, \%TranslationData);
    }

    if ( scalar(@TranslationLanguageList) == 1 ) {
        return $Self->_Success(
            TranslationLanguage => $TranslationLanguageList[0],
        );
    }

    return $Self->_Success(
        TranslationLanguage => \@TranslationLanguageList,
    );
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
