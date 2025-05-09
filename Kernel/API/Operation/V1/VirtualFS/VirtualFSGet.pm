# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::VirtualFS::VirtualFSGet;

use strict;
use warnings;

use JSON::WebToken;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::VirtualFS::VirtualFSGet - API VirtualFS Content Get Operation backend

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
        'Token' => {
            Type     => 'ARRAY',         # comma separated in case of multiple or arrayref (depending on transport)
            Required => 1
        }
    }
}

=item Run()

perform VirtualFSGet Operation. This function is able to return
one Content entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            Token => 'some token'
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '...'
        Message      => '',                               # In case of an error
        Data         => {
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @Files;

    # start loop
    foreach my $Token ( @{$Param{Data}->{Token}} ) {

        my $TokenData = decode_jwt(
            $Token,
            'ContentToken'
        );

        if ( !$TokenData ) {
            return $Self->_Error(
                Code    => 'Object.InternalError',
                Message => 'Got no Token!'
            );
        }

        NEEDED:
        for my $Needed ( qw(ObjectType ObjectID FileID ) ) {
            next NEEDED if $TokenData->{$Needed};

            return $Self->_Error(
                Code    => 'Object.InternalError',
                Message => 'Got invalid Token!'
            );
        }

        my $HasAccess = $Self->_ObjectPermissionCheck(
            %Param,
            %{$TokenData}
        );


        if ( !$HasAccess ) {
            return $Self->_Error(
                Code => 'Object.NoPermission',
            );
        }

        my $Mode = 'Preferences';
        if ( $Param{Data}->{include}->{Content} ) {
            $Mode = 'binary';
        }

        my %File = $Kernel::OM->Get('VirtualFS')->Read(
            ID   => $TokenData->{FileID},
            Mode => $Mode
        );

        if ( !%File ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        my %Data = (
            Filename    => $File{Preferences}->{Filename},
            FilesizeRaw => $File{Preferences}->{FilesizeRaw},
            FileID      => $TokenData->{FileID},
        );

        if ( $Param{Data}->{include}->{Content} ) {
            my $Content = $File{Content};
            $Data{Content} = ${$Content};
        }

        push(
            @Files,
            \%Data
        );

    }

    if ( scalar(@Files) == 1 ) {
        return $Self->_Success(
            VirtualFS => $Files[0]
        );
    }

    return $Self->_Success(
        VirtualFS => \@Files
    );
}

sub _ObjectPermissionCheck {
    my ( $Self, %Param ) = @_;

    my $MappingJSON = $Kernel::OM->Get('Config')->Get('VirtualFSObjectsMapping');
    return if !$MappingJSON;

    my $Mapping = $Kernel::OM->Get('JSON')->Decode(
        Data => $MappingJSON
    );

    return if !defined $Mapping->{$Param{ObjectType}};
    return if !$Mapping->{$Param{ObjectType}}->{Operation};
    return if !$Mapping->{$Param{ObjectType}}->{Parameters};

    my $Operation  = $Mapping->{$Param{ObjectType}}->{Operation};
    my $Parameters = $Mapping->{$Param{ObjectType}}->{Parameters};

    my $Data = {};
    for my $Key ( sort( keys( %{ $Parameters } ) ) ) {
        my $Value;
        if (
            IsHashRefWithData( $Parameters->{ $Key } )
            && $Parameters->{ $Key }->{Object}
            && $Parameters->{ $Key }->{Method}
            && IsHashRefWithData( $Parameters->{ $Key }->{Parameters} )
        ) {
            my $LookupObject = $Kernel::OM->Get( $Parameters->{ $Key }->{Object} );
            my $LookupMethod = $Parameters->{ $Key }->{Method};
            my %LookupParameters = ();
            for my $LookupKey ( keys( %{ $Parameters->{ $Key }->{Parameters} } ) ) {
                $LookupParameters{ $LookupKey } = $Param{ $Parameters->{ $LookupKey } } // $Data->{ $LookupKey };
            }
            $Value = $LookupObject->$LookupMethod( %LookupParameters );
        }
        else {
            $Value = $Param{ $Parameters->{ $Key } };
        }
        return if !$Value;

        $Data->{ $Key } = $Value;
    }

    my $GetResult = $Self->ExecOperation(
        OperationType            => $Operation,
        SuppressPermissionErrors => 1,
        Data                     => $Data
    );

    if (
        !IsHashRefWithData($GetResult)
        || !$GetResult->{Success}
    ) {
        return;
    }

    return 1;
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
