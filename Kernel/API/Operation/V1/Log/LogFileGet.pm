# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Log::LogFileGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Log::LogFileGet - API LogFile Get Operation backend

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
        'LogFileID' => {
            Type     => 'ARRAY',
            Required => 1
        }
    }
}

=item Run()

perform LogFileGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            LogFileID => '....'       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            LogFile => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @LogFileList;
    my @Categories = split(',', $Param{Data}->{Categories});

    # start loop
    foreach my $LogFileID ( @{$Param{Data}->{LogFileID}} ) {

        # get the LogFile data
        my %LogFileData = $Kernel::OM->Get('LogFile')->LogFileGet(
            ID         => $LogFileID,
            NoContent  => $Param{Data}->{include}->{Content} ? 0 : 1,
            Tail       => $Param{Data}->{Tail},
            Categories => \@Categories
        );

        if ( !%LogFileData ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        if ( $Param{Data}->{include}->{Content} ) {
            $LogFileData{Content} = MIME::Base64::encode_base64($LogFileData{Content}),
        }

        # add
        push(@LogFileList, \%LogFileData);
    }

    if ( scalar(@LogFileList) == 1 ) {
        return $Self->_Success(
            LogFile => $LogFileList[0],
        );
    }

    # return result
    return $Self->_Success(
        LogFile => \@LogFileList,
    );
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
