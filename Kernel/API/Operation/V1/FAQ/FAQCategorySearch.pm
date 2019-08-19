# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
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
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::FAQ::FAQCategorySearch - API FAQCategory Search Operation backend

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
    my $FAQCategoryList = $Kernel::OM->Get('Kernel::System::FAQ')->CategoryList(
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

        my $FAQCategoryGetResult = $Self->ExecOperation(
            OperationType => 'V1::FAQ::FAQCategoryGet',
            Data      => {
                FAQCategoryID => join(',', sort keys %{$FAQCategories}),
            }
        );
  
        if ( !IsHashRefWithData($FAQCategoryGetResult) || !$FAQCategoryGetResult->{Success} ) {
            return $FAQCategoryGetResult;
        }

        my @FAQCategoryDataList = IsArrayRefWithData($FAQCategoryGetResult->{Data}->{FAQCategory}) ? @{$FAQCategoryGetResult->{Data}->{FAQCategory}} : ( $FAQCategoryGetResult->{Data}->{FAQCategory} );

        if ( IsArrayRefWithData(\@FAQCategoryDataList) ) {
            return $Self->_Success(
                FAQCategory => \@FAQCategoryDataList,
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
