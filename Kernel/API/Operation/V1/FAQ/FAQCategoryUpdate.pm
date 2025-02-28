# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQCategoryUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::FAQ::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQCategoryUpdate - API FAQCategory Create Operation backend

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
            Required => 1
        },
    }
}

=item Run()

perform FAQCategoryUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            FAQCategoryID => 123,
            FAQCategory  => {
                Name     => 'CategoryA',    # optional
                Comment  => 'Some comment', # optional
                ParentID => 2,              # optional
                ValidID  => 1,              # optional
            },
        },
    );

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            FAQCategoryID  => 123,              # ID of the updated FAQCategory
        },
    };

=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim FAQCategory parameter
    my $FAQCategory = $Self->_Trim(
        Data => $Param{Data}->{FAQCategory}
    );

    # check if FAQCategory exists
    my %FAQCategoryData = $Kernel::OM->Get('FAQ')->CategoryGet(
        CategoryID  => $Param{Data}->{FAQCategoryID},
        UserID      => 1
    );

    if ( !%FAQCategoryData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    if ( $FAQCategory->{ParentID} && $FAQCategory->{ParentID} == $Param{Data}->{FAQCategoryID}) {
        return $Self->_Error(
            Code    => 'Validator.Failed',
            Message => "Validation of attribute ParentID failed! It can not be its own parent.",
        );
    }

    # check for duplicated
    my $Exists = $Kernel::OM->Get('FAQ')->CategoryDuplicateCheck(
        CategoryID => $Param{Data}->{FAQCategoryID},
        Name       => $FAQCategory->{Name},
        ParentID   => $FAQCategory->{ParentID},
        UserID     => 1
    );
    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot update FAQ category. Another FAQ category with the same name and parent already exists.",
        );
    }

    # update FAQCategory
    my $Success = $Kernel::OM->Get('FAQ')->CategoryUpdate(
        CategoryID => $Param{Data}->{FAQCategoryID},
        Name       => $FAQCategory->{Name} || $FAQCategoryData{Name},
        Comment    => exists $FAQCategory->{Comment} ? $FAQCategory->{Comment} : $FAQCategoryData{Comment},
        ParentID   => exists $FAQCategory->{ParentID} ? ($FAQCategory->{ParentID}||0) : $FAQCategoryData{ParentID},
        ValidID    => $FAQCategory->{ValidID} || $FAQCategoryData{ValidID},
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result
    return $Self->_Success(
        FAQCategoryID => $Param{Data}->{FAQCategoryID},
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
