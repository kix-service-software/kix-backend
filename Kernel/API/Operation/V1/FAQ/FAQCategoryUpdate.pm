# --
# Kernel/API/Operation/FAQ/FAQCategoryUpdate.pm - API FAQCategory Update operation backend
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

package Kernel::API::Operation::V1::FAQ::FAQCategoryUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQCategoryUpdate - API FAQCategory Create Operation backend

=head1 SYNOPSIS

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
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::FAQCategoryUpdate');

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
                GroupIDs => [               # optional
                    1,2,3,...
                ]
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
    my %FAQCategoryData = $Kernel::OM->Get('Kernel::System::FAQ')->CategoryGet(
        CategoryID  => $Param{Data}->{FAQCategoryID},
        UserID      => 1
    );
 
    if ( !%FAQCategoryData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # check for duplicated
    my $Exists = $Kernel::OM->Get('Kernel::System::FAQ')->CategoryDuplicateCheck(
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
    my $Success = $Kernel::OM->Get('Kernel::System::FAQ')->CategoryUpdate(
        CategoryID => $Param{Data}->{FAQCategoryID},
        Name       => $FAQCategory->{Name} || $FAQCategoryData{Name},
        Comment    => $FAQCategory->{Comment} || $FAQCategoryData{Comment},
        ParentID   => $FAQCategory->{ParentID} || $FAQCategoryData{ParentID},
        ValidID    => $FAQCategory->{ValidID} || $FAQCategoryData{ValidID},
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # set groups
    if ( IsArrayRefWithData($FAQCategory->{GroupIDs}) ) {
        my $Success = $Kernel::OM->Get('Kernel::System::FAQ')->SetCategoryGroup(
            CategoryID => $Param{Data}->{FAQCategoryID},
            GroupIDs   => $FAQCategory->{GroupIDs},
            UserID     => $Self->{Authorization}->{UserID},
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToCreate',
                Message => 'Could not create group assignment, please contact the system administrator',
            );
        }
    }

    # return result    
    return $Self->_Success(
        FAQCategoryID => $Param{Data}->{FAQCategoryID},
    );    
}

1;
