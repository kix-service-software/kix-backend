# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::I18n::TranslationPatternUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::I18n::TranslationPatternUpdate - API Translation Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::I18n::TranslationPatternUpdate');

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
            DataType => 'NUMERIC',
            Required => 1
        },
        'TranslationPattern' => {
            Type     => 'HASH',
            Required => 1
        },
        'TranslationPattern::Value' => {
            RequiresValueIfUsed => 1
        },
    }
}

=item Run()

perform TranslationPatternUpdate Operation. This will return the updated TranslationID.

    my $Result = $OperationObject->Run(
        Data => {
            TranslationPattern => {
                Value       => '...'                                        # requires a value if given
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Message    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            TranslationID  => '',                   # TranslationID 
            Error => {                              # should not return errors
                    Code    => 'Translation.Create.Code'
                    Message => 'Error Description'
            },
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
    my %PatternData = $Kernel::OM->Get('Kernel::System::Translation')->PatternGet(
        ID     => $Param{Data}->{PatternID},
    );
    if ( !%PatternData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # check if pattern already exists
    if ( IsStringWithData($TranslationPattern->{Value}) ) {
        my $PatternID = $Kernel::OM->Get('Kernel::System::Translation')->PatternExistsCheck(
            Value => $TranslationPattern->{Value},
        );
        if ( $PatternID && $PatternID != $Param{Data}->{PatternID} ) {        
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
            );
        }
    }

    # update Translation
    my $Success = $Kernel::OM->Get('Kernel::System::Translation')->PatternUpdate(
        ID     => $Param{Data}->{PatternID},
        Value  => $TranslationPattern->{Value} || $PatternData{Value},
        UserID => $Self->{Authorization}->{UserID}
    );    
    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }
    
    return $Self->_Success(
        PatternID => $PatternData{ID},
    );   
}
=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
