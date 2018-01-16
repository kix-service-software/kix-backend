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

=item Run()

perform StandardAttachmentUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            AttachmentID => 123,
            StandardAttachment  => {
                Name        => 'Some Name',     # optional
                ValidID     => 1,               # optional
                Content     => $Content,        # optional
                ContentType => 'text/xml',      # optional
                Filename    => 'SomeFile.xml',  # optional
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

    # prepare data
    $Result = $Self->PrepareData(
        Data         => $Param{Data},
        Parameters   => {
            'AttachmentID' => {
                Required => 1
            },
            'StandardAttachment' => {
                Type => 'HASH',
                Required => 1
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
            Code    => 'Object.NotFound',
            Message => "Cannot update StandardAttachment. No StandardAttachment with ID '$Param{Data}->{StandardAttachmentID}' found.",
        );
    }

    # update StandardAttachment
    my $Success = $Kernel::OM->Get('Kernel::System::StdAttachment')->StdAttachmentUpdate(
        ID          => $Param{Data}->{AttachmentID},
        Name        => $StandardAttachment->{Name} || $StandardAttachmentData{Name},
        Content     => $StandardAttachment->{Content} || $StandardAttachmentData{Content},
        ContentType => $StandardAttachment->{ContentType} || $StandardAttachmentData{ContentType},
        Filename    => $StandardAttachment->{Filename} || $StandardAttachmentData{Filename},
        ValidID     => $StandardAttachment->{ValidID} || $StandardAttachmentData{ValidID},
        UserID      => $Self->{Authorization}->{UserID},
    );
    
    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update StandardAttachment, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        StandardAttachmentID => $Param{Data}->{AttachmentID},
    );    
}

1;
