# --
# Kernel/API/Operation/Translation/TranslationGet.pm - API Translation Get operation backend
# based upon Kernel/API/Operation/Ticket/TicketGet.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
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

package Kernel::API::Operation::V1::I18n::TranslationLanguageGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

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

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::I18n::TranslationLanguageGet->new();

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

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::I18n::TranslationLanguageGet');

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
            TranslationID => 123,
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
    my %PatternData = $Kernel::OM->Get('Kernel::System::Translation')->PatternGet(
        ID => $Param{Data}->{TranslationID},
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
        my %TranslationData = $Kernel::OM->Get('Kernel::System::Translation')->TranslationLanguageGet(
            PatternID => $Param{Data}->{TranslationID},
            Language  => $Language,
            UserID    => $Self->{Authorization}->{UserID}
        );

        if ( !IsHashRefWithData( \%TranslationData ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # replace PatternID with TranslationID
        $TranslationData{TranslationID} = $TranslationData{PatternID};
        delete $TranslationData{PatternID};

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
