# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::StandardAttachment::StandardAttachmentCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::StandardAttachment::StandardAttachmentCreate - API StandardAttachment Create Operation backend

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
        'StandardAttachment' => {
            Type     => 'HASH',
            Required => 1
        },
        'StandardAttachment::Name' => {
            Required => 1
        },            
        'StandardAttachment::Content' => {
            Required => 1
        },
        'StandardAttachment::ContentType' => {
            Required => 1
        },
        'StandardAttachment::Filename' => {
            Required => 1,
        },
    }
}

=item Run()

perform StandardAttachmentCreate Operation. This will return the created StandardAttachmentID.

    my $Result = $OperationObject->Run(
        Data => {
            StandardAttachment  => {
                Name        => 'Some Name',
                ValidID     => 1,
                Content     => $Content,
                ContentType => 'text/xml',
                Filename    => 'SomeFile.xml',
                Comment     => 'some comment',      # optional
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            StandardAttachmentID  => '',                         # ID of the created StandardAttachment
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim StandardAttachment parameter
    my $StandardAttachment = $Self->_Trim(
        Data => $Param{Data}->{StandardAttachment}
    );
    
    # check if name already exists
    my $ID = $Kernel::OM->Get('StdAttachment')->StdAttachmentLookup(
        StdAttachment => $StandardAttachment->{Name},
    );
    
    if ( $ID ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create StandardAttachment entry. Another StandardAttachment with the name already exists.",
        );
    }
    
    # create StandardAttachment
    my $StandardAttachmentID = $Kernel::OM->Get('StdAttachment')->StdAttachmentAdd(
        Name        => $StandardAttachment->{Name},
        Content     => $StandardAttachment->{Content},
        ContentType => $StandardAttachment->{ContentType},
        Filename    => $StandardAttachment->{Filename},
        Comment     => $StandardAttachment->{Comment} || '',
        ValidID     => $StandardAttachment->{ValidID} || 1,
        UserID      => $Self->{Authorization}->{UserID},
    );

    if ( !$StandardAttachmentID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create StandardAttachment, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        StandardAttachmentID => $StandardAttachmentID,
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
