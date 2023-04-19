# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ImportExport::TemplateGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ImportExport::TemplateGet - API ImportExport Template Get Operation backend

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
        'TemplateID' => {
            Type     => 'ARRAY',
            Required => 1
        }
    }
}

=item Run()

perform TemplateGet Operation. This function is able to return
one or more templates in one call.

    my $Result = $OperationObject->Run(
        Data => {
            TemplateID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            ImportExportTemplate => [
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

    my @TemplateList;

    # start loop
    foreach my $TemplateID ( @{$Param{Data}->{TemplateID}} ) {

        # get the Template data
        my $TemplateDataRef = $Kernel::OM->Get('ImportExport')->TemplateGet(
            TemplateID => $TemplateID,
            UserID     => $Self->{Authorization}->{UserID},
        );

        if ( !IsHashRefWithData( $TemplateDataRef ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # change ID property
        $TemplateDataRef->{ID} = $TemplateDataRef->{TemplateID};
        delete $TemplateDataRef->{TemplateID};

        # get object data if included
        if ( $Param{Data}->{include}->{ObjectData} ) {
            my $ObjectData = $Kernel::OM->Get('ImportExport')->ObjectDataGet(
                TemplateID => $TemplateID,
                UserID     => $Self->{Authorization}->{UserID},
            );
            if (IsHashRefWithData($ObjectData)) {
                $TemplateDataRef->{ObjectData} = $ObjectData;
            } else {
                $TemplateDataRef->{ObjectData} = {};
            }
        }

        # add
        push(@TemplateList, $TemplateDataRef);
    }

    if ( scalar(@TemplateList) == 1 ) {
        return $Self->_Success(
            ImportExportTemplate => $TemplateList[0],
        );
    }

    # return result
    return $Self->_Success(
        ImportExportTemplate => \@TemplateList,
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
