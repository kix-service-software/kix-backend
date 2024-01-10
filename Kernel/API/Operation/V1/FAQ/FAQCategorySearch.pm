# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQCategorySearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::FAQ::FAQCategoryGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::FAQ::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::FAQ::FAQCategorySearch - API FAQCategory Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform FAQCategorySearch Operation. This will return a FAQCategory ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            FAQCategory => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform FAQCategory search
    my $FAQCategoryList = $Kernel::OM->Get('FAQ')->CategoryList(
        UserID => $Self->{Authorization}->{UserID},
    );

    # get already prepared FAQ data from FAQCategoryGet operation
    if ( IsHashRefWithData($FAQCategoryList) ) {
        my $FAQCategories;

        foreach my $ParentID ( keys %{$FAQCategoryList} ){
            foreach my $Key ( keys %{$FAQCategoryList->{$ParentID}}){
                $FAQCategories->{$Key} = $FAQCategoryList->{$ParentID}->{$Key};
            }
        }

        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::FAQ::FAQCategoryGet',
            SuppressPermissionErrors => 1,
            Data      => {
                FAQCategoryID => join(',', sort keys %{$FAQCategories}),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{FAQCategory} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{FAQCategory}) ? @{$GetResult->{Data}->{FAQCategory}} : ( $GetResult->{Data}->{FAQCategory} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                FAQCategory => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        FAQCategory => [],
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
