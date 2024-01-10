# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQCategoryCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::FAQ::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQCategoryCreate - API FAQCategory Create Operation backend

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
        'FAQCategory' => {
            Type     => 'HASH',
            Required => 1
        },
        'FAQCategory::Name' => {
            Required => 1
        }
    }
}

=item Run()

perform FAQCategoryCreate Operation. This will return the created FAQCategoryID.

    my $Result = $OperationObject->Run(
        Data => {
            FAQCategory  => {
                Name     => 'CategoryA',
                Comment  => 'Some comment', # optional
                ParentID => 2,              # optional
                ValidID  => 1,              # optional, default 1
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            FAQCategoryID  => '',                         # ID of the created FAQCategory
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim FAQCategory parameter
    my $FAQCategory = $Self->_Trim(
        Data => $Param{Data}->{FAQCategory}
    );

    # check if exists
    my $Exists = $Kernel::OM->Get('FAQ')->CategoryDuplicateCheck(
        Name     => $FAQCategory->{Name},
        ParentID => $FAQCategory->{ParentID},
        UserID   => 1
    );
    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create FAQCategory. Another FAQCategory with the same name and parent already exists.",
        );
    }

    # create FAQCategory
    my $FAQCategoryID = $Kernel::OM->Get('FAQ')->CategoryAdd(
        Name     => $FAQCategory->{Name},
        Comment  => $FAQCategory->{Comment} || '',
        ParentID => $FAQCategory->{ParentID} || 0,
        ValidID  => $FAQCategory->{ValidID} || 1,
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( !$FAQCategoryID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create FAQCategory, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        FAQCategoryID => $FAQCategoryID,
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
