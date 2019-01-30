# --
# Kernel/API/Operation/Translation/TranslationUpdate.pm - API Translation Create operation backend
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

package Kernel::API::Operation::V1::I18n::TranslationUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::I18n::TranslationUpdate - API Translation Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::I18n::TranslationUpdate');

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
            DataType => 'NUMERIC',
            Required => 1
        },
        'Translation' => {
            Type     => 'HASH',
            Required => 1
        },
        'Translation::Pattern' => {
            RequiresValueIfUsed => 1
        },
    }
}

=item Run()

perform TranslationUpdate Operation. This will return the updated TranslationID.

    my $Result = $OperationObject->Run(
        Data => {
            Translation => {
                Pattern       => '...'                                        # requires a value if given
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

    # isolate and trim Translation parameter
    my $Translation = $Self->_Trim(
        Data => $Param{Data}->{Translation},
    );

    # check if pattern exists
    my %PatternData = $Kernel::OM->Get('Kernel::System::Translation')->PatternGet(
        ID     => $Param{Data}->{TranslationID},
    );
    if ( !%PatternData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update translation. No translation with ID '$Param{Data}->{TranslationID}' found.",
        );
    }

    # check if pattern already exists
    if ( IsStringWithData($Translation->{Pattern}) ) {
        my $PatternID = $Kernel::OM->Get('Kernel::System::Translation')->PatternExistsCheck(
            Value => $Translation->{Pattern},
        );
        if ( $PatternID && $PatternID != $Param{Data}->{TranslationID} ) {        
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => 'Cannot update translation. Another translation with the same pattern already exists.',
            );
        }
    }

    # update Translation
    my $Success = $Kernel::OM->Get('Kernel::System::Translation')->PatternUpdate(
        ID     => $Param{Data}->{TranslationID},
        Value  => $Translation->{Pattern} || $PatternData{Value},
        UserID => $Self->{Authorization}->{UserID}
    );    
    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update translation, please contact the system administrator',
        );
    }
    
    return $Self->_Success(
        TranslationID => $Param{Data}->{TranslationID},
    );   
}