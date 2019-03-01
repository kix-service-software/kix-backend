# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::CMDB::ClassDefinitionDelete;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ClassDefinitionDelete - API ClassDefinitionDelete Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

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

    # get valid ClassIDs
    my $ItemList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
        Valid => 1,
    );

    my @ClassIDs = sort keys %{$ItemList};

    return {
        'ClassID' => {
            DataType => 'NUMERIC',
            Required => 1,
            OneOf    => \@ClassIDs,            
        },       
        'DefinitionID' => {
            DataType => 'NUMERIC',
            Required => 1,
            Type     => 'ARRAY',            
        },
    }
}

=item Run()

perform ClassDefinitionDelete Operation.

    my $Result = $OperationObject->Run(
        Data => {
            DefinitionID  => '...',     
        },      
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    foreach my $DefinitionID ( @{$Param{Data}->{DefinitionID}} ) {
     
        my $Definition = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->DefinitionGet(
            DefinitionID => $DefinitionID,
        );

        if ( !IsHashRefWithData($Definition) ) {
            return $Self->_Error(
                Code => 'Object.NotFound'
            );
        }
        
        my $Success = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->DefinitionDelete(
            DefinitionID => $DefinitionID,
            UserID       => $Self->{Authorization}->{UserID},
        );
    
        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete class definition, please contact the system administrator',
            );
        }
    }
    
    # return result
    return $Self->_Success();
}

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
