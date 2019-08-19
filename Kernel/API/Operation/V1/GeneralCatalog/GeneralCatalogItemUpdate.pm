# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemUpdate - API GeneralCatalogItem Update Operation backend

=head1 SYNOPSIS

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
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::GeneralCatalogItemUpdate');

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
        'GeneralCatalogItemID' => {
            Required => 1
        },
        'GeneralCatalogItem' => {
            Type => 'HASH',
            Required => 1
        },   
    }
}

=item Run()

perform GeneralCatalogItemUpdate Operation. This will return the updated GeneralCatalogItemID.

    my $Result = $OperationObject->Run(
        Data => {
            GeneralCatalogItemID => 123,
            GeneralCatalogItem  => {
                Class         => 'ITSM::Service::Type',     # (optional)
                Name          => 'Item Name',               # (optional)
                ValidID       => 1,                         # (optional)
                Comment       => 'Comment',                 # (optional)
            },
        },
    );
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            GeneralCatalogItemID  => 123,       # ID of the updated GeneralCatalogItem 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim GeneralCatalogItem parameter
    my $GeneralCatalogItem = $Self->_Trim(
        Data => $Param{Data}->{GeneralCatalogItem}
    );

    # check if GeneralCatalog exists 
    my $GeneralCatalogData = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemGet(
        ItemID => $Param{Data}->{GeneralCatalogItemID},
    );

    if ( !$GeneralCatalogData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # update GeneralCatalog
    my $Success = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemUpdate(
        ItemID   => $Param{Data}->{GeneralCatalogItemID},    
        Class    => $GeneralCatalogItem->{Class} || $GeneralCatalogData->{Class},
        Name     => $GeneralCatalogItem->{Name} || $GeneralCatalogData->{Name},
        Comment  => $GeneralCatalogItem->{Comment} || $GeneralCatalogData->{Comment},
        ValidID  => $GeneralCatalogItem->{ValidID} || $GeneralCatalogData->{ValidID},
        UserID   => $Self->{Authorization}->{UserID},                        
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result    
    return $Self->_Success(
        GeneralCatalogItemID => $Param{Data}->{GeneralCatalogID},
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
