# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ClassUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ClassUpdate - API Class Update Operation backend

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
        'ClassID' => {
            Required => 1
        },
        'ConfigItemClass' => {
            Type => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform Class Update Operation. This will return the updated ClassID.

    my $Result = $OperationObject->Run(
        Data => {
            ClassID => 123,
            ConfigItemClass  => {
                Name    => 'class name',              # (optional)
                ValidID => 1,                         # (optional)
                Comment => 'Comment',                 # (optional)
            },
        },
    );


    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            ConfigItemClassID  => 123,          # ID of the updated class
        },
    };

=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim ConfigItemClass parameter
    my $ConfigItemClass = $Self->_Trim(
        Data => $Param{Data}->{ConfigItemClass}
    );

    # check if class exists
    my $GeneralCatalogData = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
        ItemID => $Param{Data}->{ClassID},
    );

    if ( !$GeneralCatalogData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    my $ItemList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    foreach my $Item ( keys %$ItemList ) {
    	if ( $ItemList->{$Item} eq $ConfigItemClass->{Name} && $Param{Data}->{ClassID} != $Item ) {
	        return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => "Cannot update class. Another class with the same name '$ConfigItemClass->{Name}' already exists.",
	        );
    	}
    }

    # update GeneralCatalog
    my $Success = $Kernel::OM->Get('GeneralCatalog')->ItemUpdate(
        ItemID   => $Param{Data}->{ClassID},
        Class    => 'ITSM::ConfigItem::Class',
        Name     => $ConfigItemClass->{Name} || $GeneralCatalogData->{Name},
        Comment  => exists $ConfigItemClass->{Comment} ? $ConfigItemClass->{Comment} : $GeneralCatalogData->{Comment},
        ValidID  => $ConfigItemClass->{ValidID} || $GeneralCatalogData->{ValidID},
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update class, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        ConfigItemClassID => $Param{Data}->{ClassID},
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
