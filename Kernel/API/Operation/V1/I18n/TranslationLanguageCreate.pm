# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::I18n::TranslationLanguageCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::I18n::TranslationLanguageCreate - API Translation TranslationLanguage Create Operation backend

=head1 SYNOPSIS

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
    for my $Needed (qw( DebuggerObject WebserviceID )) {
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
        'TranslationLanguage' => {
            Type     => 'HASH',
            Required => 1
        },
        'TranslationLanguage::Language' => {
            Required => 1
        },
        'TranslationLanguage::Value' => {
            Required => 1
        },
    }
}

=item Run()

perform TranslationLanguageCreate Operation. This will return success.

    my $Result = $OperationObject->Run(
        Data => {
            PatternID      => 12,
            TranslationLanguage  => {
                Language => '...',
                Value    => '...'
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
    my %PatternData = $Kernel::OM->Get('Kernel::System::Translation')->PatternGet(
        ID => $Param{Data}->{PatternID},
    );
    if ( !%PatternData ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    # check if translation already exists for this pattern
    my %TranslationData = $Kernel::OM->Get('Kernel::System::Translation')->TranslationLanguageGet(
        PatternID => $Param{Data}->{PatternID},
        Language  => $Language->{Language}
    );
    if ( %TranslationData ) {
        return $Self->_Error(
            Code => 'Object.AlreadyExists',
        );
    }

    # add language
    my $Success = $Kernel::OM->Get('Kernel::System::Translation')->TranslationLanguageAdd(
        PatternID => $Param{Data}->{PatternID},
        Language  => $Language->{Language},
        Value     => $Language->{Value},
        UserID    => $Self->{Authorization}->{UserID}
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToCreate',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code     => 'Object.Created',
        Language => $Language->{Language}
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
