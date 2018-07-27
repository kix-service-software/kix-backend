# --# --
# Kernel/API/Operation/FAQ/FAQArticleSearch.pm - API FAQArticle Search operation backend
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

package Kernel::API::Operation::V1::FAQ::FAQArticleSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::FAQ::FAQArticleGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::FAQ::FAQArticleSearch - API FAQArticle Search Operation backend

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

perform FAQArticleSearch Operation. This will return a FAQArticle ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            FAQArticle => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform FAQArticle search (at the moment without any filters - we do filtering in the API)
    my @ArticleIDs = $Kernel::OM->Get('Kernel::System::FAQ')->FAQSearch(
        UserID     => $Self->{Authorization}->{UserID},
    );

    # get already prepared FAQ data from FAQArticleGet operation
    if ( @ArticleIDs ) {

        my $FAQArticleGetResult = $Self->ExecOperation(
            OperationType => 'V1::FAQ::FAQArticleGet',
            Data      => {
                FAQArticleID => join(',', sort @ArticleIDs),
            }
        );
  
        if ( !IsHashRefWithData($FAQArticleGetResult) || !$FAQArticleGetResult->{Success} ) {
            return $FAQArticleGetResult;
        }

        my @FAQArticleDataList = IsArrayRefWithData($FAQArticleGetResult->{Data}->{FAQArticle}) ? @{$FAQArticleGetResult->{Data}->{FAQArticle}} : ( $FAQArticleGetResult->{Data}->{FAQArticle} );

        if ( IsArrayRefWithData(\@FAQArticleDataList) ) {
            return $Self->_Success(
                FAQArticle => \@FAQArticleDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        FAQArticle => [],
    );
}


1;