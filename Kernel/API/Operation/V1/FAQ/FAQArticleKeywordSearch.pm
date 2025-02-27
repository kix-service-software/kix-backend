# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQArticleKeywordSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::FAQ::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::FAQ::FAQArticleKeywordSearch - API FAQArticle Keyword Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform FAQArticleKeywordSearch Operation. This will return a FAQArticleKeyword list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            FAQKeyword => [
                "...",
                "..."
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform keyword search
    my %KeywordList = $Kernel::OM->Get('FAQ')->KeywordList(
        UserID => $Self->{Authorization}->{UserID},
    );
    my @KeywordArray = sort keys %KeywordList;

    # return result
    return $Self->_Success(
        FAQKeyword => \@KeywordArray,
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
