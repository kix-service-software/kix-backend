# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemAttachmentGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ConfigItemAttachmentGet - API ConfigItemAttachmentGet Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
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
            DataType => 'NUMERIC',
            Required => 1
        },
    }
}

=item Run()

perform ConfigItemAttachmentGet Operation. 

    my $Result = $OperationObject->Run(
        AttachmentID => 1,                                # required 
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            Attachment => [
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @AttachmentList;        
    foreach my $AttachmentID ( @{$Param{Data}->{AttachmentID}} ) {                 

        my $StoredAttachment = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->AttachmentStorageGet(
            ID => $AttachmentID,
        );

        if (!$StoredAttachment->{Filename}) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "Could not get data for AttachmentID $AttachmentID",
            );
        }     

        my %Attachment = (
            AttachmentID => $AttachmentID,
            Filename     => $StoredAttachment->{Filename},
            ContentType  => $StoredAttachment->{Preferences}->{Datatype},
            Content      => MIME::Base64::encode_base64(${$StoredAttachment->{ContentRef}}),                    
            FilesizeRaw  => (bytes::length ${$StoredAttachment->{ContentRef}}),
        );

        # human readable file size
        if ( $Attachment{FilesizeRaw} ) {
            if ( $Attachment{FilesizeRaw} > ( 1024 * 1024 ) ) {
                $Attachment{Filesize} = sprintf "%.1f MBytes", ( $Attachment{FilesizeRaw} / ( 1024 * 1024 ) );
            }
            elsif ( $Attachment{FilesizeRaw} > 1024 ) {
                $Attachment{Filesize} = sprintf "%.1f KBytes", ( ( $Attachment{FilesizeRaw} / 1024 ) );
            }
            else {
                $Attachment{Filesize} = $Attachment{FilesizeRaw} . ' Bytes';
            }
        }

        push(@AttachmentList, \%Attachment);
    }

    if ( scalar(@AttachmentList) == 0 ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Could not get data for AttachmentID ".join(',', $Param{Data}->{AttachmentID}),
        );
    }
    elsif ( scalar(@AttachmentList) == 1 ) {
        return $Self->_Success(
            Attachment => $AttachmentList[0],
        );    
    }

    return $Self->_Success(
        Attachment => \@AttachmentList,
    );
}

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
