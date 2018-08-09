# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::CMDB::ClassGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ClassGet - API ClassGet Operation backend

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

    return {
        'ClassID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        },
    }
}

=item Run()

perform ClassGet Operation. 

    my $Result = $OperationObject->Run(
        ClassID  => 1                                              # required 
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            ConfigItemClass => [
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @ClassList;        
    foreach my $ClassID ( @{$Param{Data}->{ClassID}} ) {                 

        my $ItemData = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemGet(
            ItemID => $ClassID,
        );

        if (!IsHashRefWithData($ItemData) || $ItemData->{Class} ne 'ITSM::ConfigItem::Class') {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "Could not get data for ClassID $ClassID",
            );
        }        

        my %Class = %{$ItemData};
            
        # prepare data
        $Class{ID} = $ClassID;
        foreach my $Key (qw(ItemID Class Permission)) {
            delete $Class{$Key};
        }

        # include CurrentDefinition if requested
        if ( $Param{Data}->{include}->{CurrentDefinition} ) {
            # get already prepared data of current definition from ClassDefinitionSearch operation
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::CMDB::ClassDefinitionSearch',
                Data          => {
                    ClassID   => $ClassID,
                    sort      => 'ConfigItemClassDefinition.-DefinitionID',
                    limit     => 1,
                }
            );
            if ( IsHashRefWithData($Result) && $Result->{Success} ) {
                $Class{CurrentDefinition} = $Result->{Data}->{ConfigItemClassDefinition};
            }
        }

        # include Definitions if requested
        if ( $Param{Data}->{include}->{Definitions} ) {
            # get already prepared Definitions data from ClassDefinitionSearch operation
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::CMDB::ClassDefinitionSearch',
                Data          => {
                    ClassID   => $ClassID,
                }
            );
            if ( IsHashRefWithData($Result) && $Result->{Success} ) {
                $Class{Definitions} = $Result->{Data}->{ConfigItemClassDefinition};
            }
        }

        push(@ClassList, \%Class);
    }

    if ( scalar(@ClassList) == 0 ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Could not get data for ClassID ".join(',', $Param{Data}->{ClassID}),
        );
    }
    elsif ( scalar(@ClassList) == 1 ) {
        return $Self->_Success(
            ConfigItemClass => $ClassList[0],
        );    
    }

    return $Self->_Success(
        ConfigItemClass => \@ClassList,
    );
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