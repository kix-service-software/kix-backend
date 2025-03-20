# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemAttachmentGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

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
        'ConfigItemID' => {
            DataType => 'NUMERIC',
            Required => 1
        },
        'VersionID' => {
            DataType => 'NUMERIC',
            Required => 1
        },
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

    # check if attachment is "visible" (the version attribute)
    my $CustomerAttachmentAttributeCheck = $Self->_CheckAttachmentAttributeForCustomer(
        VersionID     => $Param{Data}->{VersionID},
        AttachmentIDs => $Param{Data}->{AttachmentID}
    );
    if ( !$CustomerAttachmentAttributeCheck->{Success} ) {
        return $Self->_Error(
            %{$CustomerAttachmentAttributeCheck},
        );
    }

    my @AttachmentList;
    foreach my $AttachmentID ( @{$Param{Data}->{AttachmentID}} ) {

        my $StoredAttachment = $Kernel::OM->Get('ITSMConfigItem')->AttachmentStorageGet(
            ID => $AttachmentID,
        );

        if (!$StoredAttachment->{Filename}) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        my %Attachment = (
            AttachmentID => $AttachmentID,
            Filename     => $StoredAttachment->{Filename},
            ContentType  => $StoredAttachment->{Preferences}->{Datatype},
            Content      => MIME::Base64::encode_base64(${$StoredAttachment->{ContentRef}}),
            FilesizeRaw  => 0 + $StoredAttachment->{Preferences}->{FileSizeBytes},
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
            Code => 'Object.NotFound',
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

=item _CheckAttachmentAttributeForCustomer()

checks the configitem ids for current customer user if necessary

    my $CustomerCheck = $OperationObject->_CheckAttachmentAttributeForCustomer(
        VersionID     => 1,
        AttachmentIDs => [1,2,3]
    );

    returns:

    $CustomerCheck = {
        Success => 1,                     # if everything is OK
    }

    $CustomerCheck = {
        Code    => 'Forbidden',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckAttachmentAttributeForCustomer {
    my ( $Self, %Param ) = @_;

    if ( IsHashRefWithData($Self->{Authorization}) && $Self->{Authorization}->{UserType} eq 'Customer') {
        if ( $Param{VersionID} ) {
            if ( $Param{AttachmentIDs} && !IsArrayRefWithData($Param{AttachmentIDs}) ) {
                $Param{AttachmentIDs} = [ $Param{AttachmentIDs} ];
            }

            if ( IsArrayRefWithData($Param{AttachmentIDs}) ) {
                my $VersionData = $Kernel::OM->Get('ITSMConfigItem')->VersionGet(
                    VersionID  => $Param{VersionID},
                    XMLDataGet => 1,
                );

                if ( IsHashRefWithData($VersionData) ) {
                    my $VisibleAttachments = $Self->_GetVisibleAttachments(
                        Definition => $VersionData->{XMLDefinition},
                        Data       => $VersionData->{XMLData}->[1]->{Version}
                    ) || {};

                    for my $AttachmentID ( @{ $Param{AttachmentIDs} } ) {
                        if ( !$VisibleAttachments->{$AttachmentID} ) {
                            return $Self->_Error(
                                Code => 'Forbidden',
                                Message => "Could not access attachment with id $AttachmentID"
                            );
                        }
                    }
                } else {
                    return $Self->_Error(
                        Code => 'Error',
                        Message => "No version for given VersionID $Param{VersionID} found"
                    );
                }
            }
        } else {
            return $Self->_Error(
                Code => 'Error',
                Message => "No VersionID given"
            );
        }
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

=item _GetVisibleAttachments()

checks the configitem ids for current customer user if necessary

    my $CustomerCheck = $OperationObject->_GetVisibleAttachments(
        Definition => $XMLDefinition,
        Data       => $XMLData
    );

    returns:

    $VisibleAttachments = {
        1 => 1,               # ID of attachment => 1 = visible | 0 = not visible
        2 => 0
    }

=cut

sub _GetVisibleAttachments {
    my ( $Self, %Param ) = @_;

    my %VisibleAttachments;

    if ( IsArrayRefWithData($Param{Data}) ) {
        ROOTHASH:
        for my $RootHash ( @{ $Param{Data} } ) {
            next ROOTHASH if !defined $RootHash || !IsHashRefWithData($RootHash);

            for my $RootHashKey ( sort keys %{$RootHash} ) {
                next if $RootHashKey eq 'TagKey' || !IsArrayRefWithData($RootHash->{$RootHashKey});

                # get attribute definition
                my %AttrDef = $Kernel::OM->Get('ITSMConfigItem')->GetAttributeDefByKey(
                    Key           => $RootHashKey,
                    XMLDefinition => $Param{Definition},
                );

                ARRAYITEM:
                for my $ArrayItem ( @{ $RootHash->{$RootHashKey} } ) {
                    next ARRAYITEM if !defined $ArrayItem || !IsHashRefWithData($ArrayItem);

                    # only attachments with content (AttachmentID) are relevant
                    if ( $AttrDef{Input}->{Type} && $AttrDef{Input}->{Type} eq 'Attachment' && $ArrayItem->{Content}) {
                        $VisibleAttachments{$ArrayItem->{Content}} = $AttrDef{CustomerVisible} || 0;
                    }

                    # look if we have a sub structure
                    if ( $AttrDef{Sub} ) {
                        delete $ArrayItem->{TagKey};

                        # start recursion
                        for my $ArrayItemKey ( sort keys %{$ArrayItem} ) {
                            next if $ArrayItemKey eq 'TagKey' || !IsArrayRefWithData($ArrayItem->{$ArrayItemKey});

                            my $ChildVisibleAttachments = $Self->_GetVisibleAttachments(
                                Definition => $Param{Definition},
                                Data       => [ undef, { $ArrayItemKey => $ArrayItem->{$ArrayItemKey} } ],
                                RootKey    => $RootHashKey
                            );

                            if ( IsHashRefWithData($ChildVisibleAttachments) ) {
                                %VisibleAttachments = (%VisibleAttachments, %{$ChildVisibleAttachments});
                            }
                        }
                    }
                }
            }
        }
    }

    return \%VisibleAttachments;
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
