# --
# Kernel/API/Operation/Translation/TranslationPatternSearch.pm - API Translation Search operation backend
# based upon Kernel/API/Operation/Ticket/TicketSearch.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::I18n::TranslationPatternSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::I18n::TranslationPatternSearch - API Translation Search Operation backend

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

=item Run()

perform TranslationPatternSearch Operation. This will return a Translation ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            TranslationPattern => [
                {
                },
                {                    
                }
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform pattern search
    my %PatternList = $Kernel::OM->Get('Kernel::System::Translation')->PatternList(
        UserID    => $Self->{Authorization}->{UserID}
    );

    if (IsHashRefWithData(\%PatternList)) {

        # get already prepared Pattern data from TranslationPatternGet operation
        my $PatternGetResult = $Self->ExecOperation(
            OperationType => 'V1::I18n::TranslationPatternGet',
            Data          => {
                PatternID => join(',', sort keys %PatternList),
            }
        );
        if ( !IsHashRefWithData($PatternGetResult) || !$PatternGetResult->{Success} ) {
            return $PatternGetResult;
        }

        my @ResultList = IsArrayRefWithData($PatternGetResult->{Data}->{TranslationPattern}) ? @{$PatternGetResult->{Data}->{TranslationPattern}} : ( $PatternGetResult->{Data}->{TranslationPattern} );
        
        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                TranslationPattern => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        TranslationPattern => [],
    );
}

1;
