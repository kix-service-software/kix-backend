# --
# Kernel/API/Operation/Translation/TranslationLanguageDelete.pm - API LanguageTranslation Delete operation backend
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

package Kernel::API::Operation::V1::I18n::TranslationLanguageDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

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

=item new()

usually, you want to Delete an instance of this
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
        'TranslationID' => {
            Required => 1
        },
        'Language' => {
            Required => 1
        },
    }
}

=item Run()

perform TranslationLanguageDelete Operation. This will return success.

    my $Result = $OperationObject->Run(
        Data => {
            TranslationID  => 12,
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
    my %PatternData = $Kernel::OM->Get('Kernel::System::Translation')->PatternGet(
        ID => $Param{Data}->{TranslationID},
    );
    if ( !%PatternData ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    # check if language entry exists
    my %TranslationList = $Kernel::OM->Get('Kernel::System::Translation')->TranslationLanguageList(
        PatternID => $Param{Data}->{TranslationID},
    );
    if ( !IsHashRefWithData(\%TranslationList) || !$TranslationList{$Param{Data}->{Language}} ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # delete translation Language
    my $Success = $Kernel::OM->Get('Kernel::System::Translation')->TranslationLanguageDelete(
        PatternID => $Param{Data}->{TranslationID},
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
