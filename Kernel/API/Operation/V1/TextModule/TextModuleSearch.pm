# --
# Kernel/API/Operation/TextModule/TextModuleSearch.pm - API TextModule Search operation backend
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

package Kernel::API::Operation::V1::TextModule::TextModuleSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::TextModule::TextModuleGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::TextModule::TextModuleSearch - API TextModule Search Operation backend

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

perform TextModuleSearch Operation. This will return a TextModule ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            TextModule => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'WebService.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # prepare filter if given
    my %SearchFilter;
    if ( IsArrayRefWithData($Self->{Filter}->{TextModule}->{AND}) ) {
        foreach my $FilterItem ( @{$Self->{Filter}->{TextModule}->{AND}} ) {
            # ignore everything that we don't support in the core DB search (the rest will be done in the generic API filtering)
            next if ($FilterItem->{Field} !~ /^(Name|Category|Agent|Customer|Public|Language|ValidID)$/g);
            next if ($FilterItem->{Operator} ne 'EQ');

            $SearchFilter{$FilterItem->{Field}} = $FilterItem->{Value};
        }
    }

    # perform TextModule search
    my $TextModuleList = $Kernel::OM->Get('Kernel::System::TextModule')->TextModuleList(
        %SearchFilter
    );

	# get already prepared TextModule data from TextModuleGet operation
    if ( IsArrayRefWithData($TextModuleList) ) {  	
        my $TextModuleGetResult = $Self->ExecOperation(
            OperationType => 'V1::TextModule::TextModuleGet',
            Data      => {
                TextModuleID => join(',', @{$TextModuleList}),
            }
        );    

        if ( !IsHashRefWithData($TextModuleGetResult) || !$TextModuleGetResult->{Success} ) {
            return $TextModuleGetResult;
        }

        my @TextModuleDataList = IsArrayRefWithData($TextModuleGetResult->{Data}->{TextModule}) ? @{$TextModuleGetResult->{Data}->{TextModule}} : ( $TextModuleGetResult->{Data}->{TextModule} );

        if ( IsArrayRefWithData(\@TextModuleDataList) ) {
            return $Self->_Success(
                TextModule => \@TextModuleDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        TextModule => [],
    );
}

1;