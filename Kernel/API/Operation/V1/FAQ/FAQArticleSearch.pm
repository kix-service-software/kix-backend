# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
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

    my %ValidList = $Kernel::OM->Get('Valid')->ValidList();
    my @ValidIDs = %ValidList && keys %ValidList ? keys %ValidList : [ 1, 2, 3 ];

    # perform FAQArticle search (at the moment without any filters - we do filtering in the API)
    my @ArticleIDs = $Kernel::OM->Get('FAQ')->FAQSearch(
        UserID   => $Self->{Authorization}->{UserID},
        ValidIDs => \@ValidIDs
    );

    # get already prepared FAQ data from FAQArticleGet operation
    if (@ArticleIDs) {

        # we don't do any core search filtering, inform the API to do it for us, based on the given search
        $Self->HandleSearchInAPI();

        my $FAQArticleGetResult = $Self->ExecOperation(
            OperationType            => 'V1::FAQ::FAQArticleGet',
            SuppressPermissionErrors => 1,
            Data          => {
                FAQArticleID => join( ',', sort @ArticleIDs ),
            }
        );

        if ( !IsHashRefWithData($FAQArticleGetResult) || !$FAQArticleGetResult->{Success} ) {
            return $FAQArticleGetResult;
        }

        my @FAQArticleDataList = IsArrayRef( $FAQArticleGetResult->{Data}->{FAQArticle} ) ? @{ $FAQArticleGetResult->{Data}->{FAQArticle} } : ( $FAQArticleGetResult->{Data}->{FAQArticle} );

        if ( IsArrayRefWithData( \@FAQArticleDataList ) ) {
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

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
