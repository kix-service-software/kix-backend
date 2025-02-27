# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::ImportExport::TemplateSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::ImportExport::TemplateGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::ImportExport::TemplateSearch - API ImportExport Template Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform ImportExport Template Search Operation. This will return a Template list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ImportExportTemplate => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform template search
    my $TemplateListRef = $Kernel::OM->Get('ImportExport')->TemplateList(
        UserID => $Self->{Authorization}->{UserID}
    );

    # get already prepared Template data from TemplateGet operation
    if ( IsArrayRefWithData($TemplateListRef) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType => 'V1::ImportExport::TemplateGet',
            Data      => {
                TemplateID => join(',', @{$TemplateListRef}),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{ImportExportTemplate} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{ImportExportTemplate}) ? @{$GetResult->{Data}->{ImportExportTemplate}} : ( $GetResult->{Data}->{ImportExportTemplate} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                ImportExportTemplate => \@ResultList,
            );
        }
    }

    # return result
    return $Self->_Success(
        ImportExportTemplate => [],
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
