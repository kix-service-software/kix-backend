# --
# Kernel/API/Operation/StandardAttachment/StandardAttachmentCreate.pm - API StandardAttachment Create operation backend
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

package Kernel::API::Operation::V1::StandardAttachment::StandardAttachmentCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

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

    # init webStandardAttachment
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'WebService.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }
use Data::Dumper;
print STDERR "Param".Dumper(\%Param);

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
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
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # isolate and trim StandardAttachment parameter
    my $StandardAttachment = $Self->_Trim(
        Data => $Param{Data}->{StandardAttachment}
    );
    
    my $ID = $Kernel::OM->Get('Kernel::System::StdAttachment')->StdAttachmentLookup(
        StandardAttachment => $StandardAttachment->{Name},
    );
    
    if ( $ID ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create StandardAttachment entry. Another StandardAttachment with same email name already exists.",
        );
    }
    
    # create StandardAttachment
    my $StandardAttachmentID = $Kernel::OM->Get('Kernel::System::StdAttachment')->StdAttachmentAdd(
        Name        => $StandardAttachment->{Name},
        ValidID     => $StandardAttachment->{ValidID} || 1,
        Content     => $StandardAttachment->{Content},
        ContentType => $StandardAttachment->{ContentType},
        Filename    => $StandardAttachment->{Filename},
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
