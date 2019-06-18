# --
# Kernel/API/Operation/Translation/TranslationLanguageUpdate.pm - API LanguageTranslation Update operation backend
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::I18n::TranslationLanguageUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

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

=item new()

usually, you want to Update an instance of this
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
    my %PatternData = $Kernel::OM->Get('Kernel::System::Translation')->PatternGet(
        ID => $Param{Data}->{PatternID},
    );
    if ( !%PatternData ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    # get the Translation data
    my %TranslationData = $Kernel::OM->Get('Kernel::System::Translation')->TranslationLanguageGet(
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
    my $Success = $Kernel::OM->Get('Kernel::System::Translation')->TranslationLanguageUpdate(
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
