# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQCategoryGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::FAQ::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQCategoryGet - API FAQCategory Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

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
        'FAQCategoryID' => {
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform FAQCategoryGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            FAQCategoryID => 1,                      # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            FAQCategory => [
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

    my @FAQCategoryData;

    # start loop
    foreach my $FAQCategoryID ( @{$Param{Data}->{FAQCategoryID}} ) {

        # get the FAQCategory data
        my %FAQCategory = $Kernel::OM->Get('FAQ')->CategoryGet(
            CategoryID => $FAQCategoryID,
            UserID     => $Self->{Authorization}->{UserID},
        );

        if ( !IsHashRefWithData( \%FAQCategory ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # undef ParentID if not set
        if ( $FAQCategory{ParentID} == 0 ) {
            $FAQCategory{ParentID} = undef;
        }

        # include SubCategories if requested
        if ( $Param{Data}->{include}->{SubCategories} ) {
            $FAQCategory{SubCategories} = $Kernel::OM->Get('FAQ')->CategorySearch(
                ParentID => $FAQCategoryID,
                UserID   => $Self->{Authorization}->{UserID},
            );

            # force numeric IDs
            my $Index = 0;
            foreach my $Value ( @{$FAQCategory{SubCategories}} ) {
                $FAQCategory{SubCategories}->[$Index++] = 0 + $Value;
            }
        }

        # include Articles if requested
        if ( $Param{Data}->{include}->{Articles} ) {
            my @ArticleIDs = $Kernel::OM->Get('ObjectSearch')->Search(
                Search => {
                    AND => [
                        {
                            Field    => 'CategoryID',
                            Operator => 'IN',
                            Value    => [ $FAQCategoryID ]
                        }
                    ]
                },
                ObjectType => 'FAQArticle',
                Result     => 'ARRAY',
                UserType   => $Self->{Authorization}->{UserType},
                UserID     => $Self->{Authorization}->{UserID}
            );

            $FAQCategory{Articles} = \@ArticleIDs;
        }

        # add
        push(@FAQCategoryData, \%FAQCategory);
    }

    if ( scalar(@FAQCategoryData) == 1 ) {
        return $Self->_Success(
            FAQCategory => $FAQCategoryData[0],
        );
    }

    # return result
    return $Self->_Success(
        FAQCategory => \@FAQCategoryData,
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
