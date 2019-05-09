# --
# Kernel/API/Operation/GeneralCatalog/GeneralCatalogClassUpdate.pm - API GeneralCatalogItem Update operation backend
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogClassUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::GeneralCatalogClassUpdate');

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
    my %ClassList = map { $_ => 1 } sort @{ $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ClassList() };

    if ( !%ClassList || !$ClassList{$Param{Data}->{GeneralCatalogClass}} ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # update GeneralCatalog
    my $Success = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ClassRename(
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
