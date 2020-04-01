# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
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

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
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
        my $TemplateGetResult = $Self->ExecOperation(
            OperationType => 'V1::ImportExport::TemplateGet',
            Data      => {
                TemplateID => join(',', @{$TemplateListRef}),
            }
        );

        if ( !IsHashRefWithData($TemplateGetResult) || !$TemplateGetResult->{Success} ) {
            return $TemplateGetResult;
        }

        my @TemplateDataList = IsArrayRef($TemplateGetResult->{Data}->{ImportExportTemplate})
            ? @{$TemplateGetResult->{Data}->{ImportExportTemplate}} : ( $TemplateGetResult->{Data}->{ImportExportTemplate} );

        if ( IsArrayRefWithData(\@TemplateDataList) ) {
            return $Self->_Success(
                ImportExportTemplate => \@TemplateDataList,
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
