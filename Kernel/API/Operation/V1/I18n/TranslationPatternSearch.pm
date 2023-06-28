# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::I18n::TranslationPatternSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::I18n::TranslationPatternSearch - API Translation Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

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
    my %PatternList = $Kernel::OM->Get('Translation')->PatternList(
        UserID    => $Self->{Authorization}->{UserID}
    );

    if (IsHashRefWithData(\%PatternList)) {

        # get already prepared Pattern data from TranslationPatternGet operation
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::I18n::TranslationPatternGet',
            SuppressPermissionErrors => 1,
            Data          => {
                PatternID => join(',', sort keys %PatternList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{TranslationPattern} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{TranslationPattern}) ? @{$GetResult->{Data}->{TranslationPattern}} : ( $GetResult->{Data}->{TranslationPattern} );
        }

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

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
