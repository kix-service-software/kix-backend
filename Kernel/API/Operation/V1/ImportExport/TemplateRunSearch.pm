# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ImportExport::TemplateRunSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::ImportExport::TemplateRunSearch - API ImportExport Template Run Search Operation backend

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
            Required => 1
        }
    }
}

=item Run()

perform ImportExport Template Run Search Operation. This will return a Template Run list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ImportExportTemplateRun => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check if Template exists
    my $TemplateDataRef = $Kernel::OM->Get('ImportExport')->TemplateGet(
        TemplateID => $Param{Data}->{TemplateID},
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !IsHashRefWithData( $TemplateDataRef ) ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # perform template run search
    my @TemplateRunList = $Kernel::OM->Get('ImportExport')->TemplateRunList(
        TemplateID => $Param{Data}->{TemplateID},
        UserID     => $Self->{Authorization}->{UserID}
    );

    if ( IsArrayRefWithData(\@TemplateRunList) ) {
        return $Self->_Success(
            ImportExportTemplateRun => \@TemplateRunList,
        );
    }

    # return result
    return $Self->_Success(
        ImportExportTemplateRun => [],
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
