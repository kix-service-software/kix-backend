# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogClassUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogClassUpdate - API GeneralCatalogClass Update Operation backend

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
        'GeneralCatalogClass' => {
            Required => 1
        },
        'Name' => {
            Required => 1
        },
    }
}

=item Run()

perform GeneralCatalogClassUpdate Operation. This will return the updated GeneralCatalogItemID.

    my $Result = $OperationObject->Run(
        Data => {
            GeneralCatalogClass => 'ITSM::Service::Type',
            Name        => '...'
        },
    );


    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            GeneralCatalogClass => '...',       # new class name
        },
    };

=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # trim Name parameter
    my $Name = $Self->_Trim(
        Data => $Param{Data}->{Name},
    );

    # check if Class exists
    my %ClassList = map { $_ => 1 } sort @{ $Kernel::OM->Get('GeneralCatalog')->ClassList() };

    if ( !%ClassList || !$ClassList{$Param{Data}->{GeneralCatalogClass}} ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # update GeneralCatalog
    my $Success = $Kernel::OM->Get('GeneralCatalog')->ClassRename(
        ClassOld => $Param{Data}->{GeneralCatalogClass},
        ClassNew => $Param{Data}->{Name},
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate'
        );
    }

    # return result
    return $Self->_Success(
        GeneralCatalogClass => $Param{Data}->{Name},
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
