# --
# Kernel/API/Operation/StandardAttachment/StandardAttachmentUpdate.pm - API StandardAttachment Update operation backend
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

package Kernel::API::Operation::V1::StandardAttachment::StandardAttachmentUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::StandardAttachment::StandardAttachmentUpdate - API StandardAttachment Update Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::StandardAttachmentUpdate');

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
            Required => 1
        },
        'StandardAttachment' => {
            Type => 'HASH',
            Required => 1
        },   
    }
}

=item Run()

perform StandardAttachmentUpdate Operation. This will return the updated StandardAttachmentID.

    my $Result = $OperationObject->Run(
        Data => {
            AttachmentID => 123,
            StandardAttachment  => {
                Name        => 'Some Name',     # optional
                ValidID     => 1,               # optional
                Content     => $Content,        # optional
                ContentType => 'text/xml',      # optional
                Filename    => 'SomeFile.xml',  # optional
                Comment     => 'some comment'   # optional
            },
        },
    );

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            StandardAttachmentID  => 123,              # ID of the updated StandardAttachment 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim User parameter
    my $StandardAttachment = $Self->_Trim(
        Data => $Param{Data}->{StandardAttachment}
    );
    
    # check if StandardAttachment exists 
    my %StandardAttachmentData = $Kernel::OM->Get('Kernel::System::StdAttachment')->StdAttachmentGet(
        ID     => $Param{Data}->{AttachmentID},
    );
 
    if ( !IsHashRefWithData(\%StandardAttachmentData) ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # check if name already exists
    if ( $StandardAttachment->{Name} ) {
        my $ID = $Kernel::OM->Get('Kernel::System::StdAttachment')->StdAttachmentLookup(
            StdAttachment => $StandardAttachment->{Name},
        );
        
        if ( $ID && $ID != $Param{Data}->{AttachmentID}) {
            return $Self->_Error(
                Code => 'Object.AlreadyExists',
            );
        }
    }

    # update StandardAttachment
    my $Success = $Kernel::OM->Get('Kernel::System::StdAttachment')->StdAttachmentUpdate(
        ID          => $Param{Data}->{AttachmentID},
        Name        => $StandardAttachment->{Name} || $StandardAttachmentData{Name},
        Content     => $StandardAttachment->{Content} || $StandardAttachmentData{Content},
        ContentType => $StandardAttachment->{ContentType} || $StandardAttachmentData{ContentType},
        Filename    => $StandardAttachment->{Filename} || $StandardAttachmentData{Filename},
        Comment     => $StandardAttachment->{Comment} || $StandardAttachmentData{Comment},
        ValidID     => $StandardAttachment->{ValidID} || $StandardAttachmentData{ValidID},
        UserID      => $Self->{Authorization}->{UserID},
    );
    
    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result    
    return $Self->_Success(
        StandardAttachmentID => $Param{Data}->{AttachmentID},
    );    
}

1;
