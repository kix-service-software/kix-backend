# --
# Kernel/API/Operation/Translation/TranslationPatternCreate.pm - API Translation Create operation backend
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

package Kernel::API::Operation::V1::I18n::TranslationPatternCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

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
    my $Exists = $Kernel::OM->Get('Kernel::System::Translation')->PatternExistsCheck(
        Value  => $TranslationPattern->{Value},
        UserID => $Self->{Authorization}->{UserID}
    );
    if ( $Exists ) {
        return $Self->_Error(
            Code => 'Object.AlreadyExists',
        );
    }
    
    # create pattern
    my $PatternID = $Kernel::OM->Get('Kernel::System::Translation')->PatternAdd(
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
