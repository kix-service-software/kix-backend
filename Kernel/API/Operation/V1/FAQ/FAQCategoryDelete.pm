# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQCategoryDelete;

use strict;
use warnings;

use base qw(
    Kernel::API::Operation::V1::FAQ::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQCategoryDelete - API FAQCategory FAQCategoryDelete Operation backend

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
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform FAQCategoryDelete Operation. This will return the deleted FAQCategoryID.

    my $Result = $OperationObject->Run(
        Data => {
            FAQCategoryID => 1,                      # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $FAQObject = $Kernel::OM->Get('FAQ');

    my $CategoryTree = $FAQObject->CategoryTreeList(
        Valid  => 0,
        UserID => $Self->{Authorization}->{UserID},
    );

    my %Checked    = ();
    my $ArticleErr = 0;
    my $DeleteErr  = 0;

    for my $FAQCategoryID ( @{$Param{Data}->{FAQCategoryID}} ) {
        next if !$CategoryTree->{$FAQCategoryID};

        $Self->_CheckCategory(
            ParentID => $FAQCategoryID,
            Checked  => \%Checked
        );

        if ( $Checked{$FAQCategoryID}->{ArticleErr} ) {
            $ArticleErr = 1;
        }
        if ( $Checked{$FAQCategoryID}->{DeleteErr} ) {
            $DeleteErr = 1;
        }
    }

    # return result
    if ( $ArticleErr ) {
        return $Self->_Error(
            Code    => 'Object.DependingObjectExists',
            Message => 'Cannot delete FAQCategory. At least one article is assigned to this category.'
        );
    }
    elsif ( $DeleteErr ) {
        return $Self->_Error(
            Code    => 'Object.UnableToDelete',
            Message => 'Could not delete FAQCategory, please contact the system administrator',
        );
    }

    return $Self->_Success();
}

sub _CheckCategory {
    my ($Self, %Param) = @_;

    my $FAQObject = $Kernel::OM->Get('FAQ');

    return if !$Param{ParentID};
    return if !$Param{Checked};
    return if ref $Param{Checked} ne 'HASH';

    my $ParentID = $Param{ParentID};

    if ( $Param{Checked}->{$ParentID} ) {
        return $Param{Checked}->{$ParentID};
    }

    $Param{Checked}->{$ParentID} = {
        ArticleErr => 0,
        DeleteErr  => 0
    };

    # get sub category list
    my $CategoryIDs = $FAQObject->CategorySubCategoryIDList(
        ParentID => $ParentID,
        UserID   => $Self->{Authorization}->{UserID},
    );

    my $ArticleErr = 0;
    my $DeleteErr  = 0;
    if ( scalar @{ $CategoryIDs } ) {
        for my $ID ( @{ $CategoryIDs } ) {
            $Self->_CheckCategory(
                Checked  => $Param{Checked},
                ParentID => $ID,
            );

            if ( $Param{Checked}->{$ID}->{ArticleErr} ) {
                $ArticleErr = 1;
            }
            if ( $Param{Checked}->{$ID}->{DeleteErr} ) {
                $DeleteErr = 1;
            }
        }
    }

    if (
        $ArticleErr
        || $DeleteErr
    ) {
        $Param{Checked}->{$ParentID}->{ArticleErr} = $ArticleErr;
        $Param{Checked}->{$ParentID}->{DeleteErr}  = $DeleteErr;
        return %Param;
    }

    my @ArticleIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        Search => {
            AND => [
                {
                    Field    => 'CategoryID',
                    Operator => 'IN',
                    Value    => [ $ParentID ]
                }
            ]
        },
        ObjectType => 'FAQArticle',
        Result     => 'ARRAY',
        UserType   => $Self->{Authorization}->{UserType},
        UserID     => $Self->{Authorization}->{UserID}
    );

    if ( scalar @ArticleIDs ) {
        $Param{Checked}->{$ParentID}->{ArticleErr} = 1;
        return %Param;
    }

    my $Success = $FAQObject->CategoryDelete(
        CategoryID => $ParentID,
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        $Param{Checked}->{$ParentID}->{DeleteErr} = 1;
        return %Param;
    }

    return %Param;
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
