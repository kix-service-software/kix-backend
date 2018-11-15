# --
# Kernel/API/Operation/StandardAttachment/StandardAttachmentDelete.pm - API StandardAttachment Delete operation backend
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

package Kernel::API::Operation::V1::StandardAttachment::StandardAttachmentDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::StandardAttachment::StandardAttachmentDelete - API StandardAttachment StandardAttachmentDelete Operation backend

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
        'AttachmentID' => {
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform StandardAttachmentDelete Operation. This will return the deleted StandardAttachmentID.

    my $Result = $OperationObject->Run(
        Data => {
            AttachmentID  => '...',
        },		
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # start loop
    foreach my $AttachmentID ( @{$Param{Data}->{AttachmentID}} ) {

        my %Result = $Kernel::OM->Get('Kernel::System::StdAttachment')->StdAttachmentStandardTemplateMemberList(
            AttachmentID => $AttachmentID,
        );

        if ( IsHashRefWithData(\%Result) ) {
            return $Self->_Error(
                Code    => 'Object.DependingObjectExists',
                Message => 'Can not delete StandardAttachment. The StandardAttachment has been assigned to at least one StandardTemplate.',
            );
        }

        # delete StandardAttachment	    
        my $Success = $Kernel::OM->Get('Kernel::System::StdAttachment')->StdAttachmentDelete(
            ID     => $AttachmentID,
            UserID => $Self->{Authorization}->{UserID},
        );
 
        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete StandardAttachment, please contact the system administrator',
            );
        }
    }

    # return result
    return $Self->_Success();
}

1;
