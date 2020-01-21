# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQArticleHistorySearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::FAQ::FAQArticleHistoryGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::FAQ::FAQArticleHistorySearch - API FAQArticle History Search Operation backend

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
        'FAQArticleID' => {
            Required => 1
        },      
    }
}

=item Run()

perform FAQArticleHistorySearch Operation. This will return a FAQArticleHistory ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            FAQHistory => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform FAQHistory search (at the moment without any search filters - instead we do filtering in the API)
    my $HistoryIDs = $Kernel::OM->Get('Kernel::System::FAQ')->FAQHistoryList(
        ItemID => $Param{Data}->{FAQArticleID},
        UserID => $Self->{Authorization}->{UserID},
    );

    # get already prepared FAQ data from FAQArticleHistoryGet operation
    if ( IsArrayRefWithData($HistoryIDs) ) {

        # we don't do any core search filtering, inform the API to do it for us, based on the given search
        $Self->HandleSearchInAPI();

        my $FAQArticleHistoryGetResult = $Self->ExecOperation(
            OperationType => 'V1::FAQ::FAQArticleHistoryGet',
            Data      => {
                FAQArticleID => $Param{Data}->{FAQArticleID},
                FAQHistoryID => join(',', sort @{$HistoryIDs}),
            }
        );

        if ( !IsHashRefWithData($FAQArticleHistoryGetResult) || !$FAQArticleHistoryGetResult->{Success} ) {
            return $FAQArticleHistoryGetResult;
        }

        my @FAQArticleHistoryDataList = IsArrayRef($FAQArticleHistoryGetResult->{Data}->{FAQHistory}) ? @{$FAQArticleHistoryGetResult->{Data}->{FAQHistory}} : ( $FAQArticleHistoryGetResult->{Data}->{FAQHistory} );

        if ( IsArrayRefWithData(\@FAQArticleHistoryDataList) ) {
            return $Self->_Success(
                FAQHistory => \@FAQArticleHistoryDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        FAQHistory => [],
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
