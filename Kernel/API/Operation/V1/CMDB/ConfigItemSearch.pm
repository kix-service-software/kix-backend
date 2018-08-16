# --
# Kernel/API/Operation/CMDB/CMDBCreate.pm - API CMDB Create operation backend
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

package Kernel::API::Operation::V1::CMDB::ConfigItemSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::CMDB::ConfigItemSearch - API CMDB Search Operation backend

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

perform ConfigItemSearch Operation. This will return a class list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ConfigItem => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # prepare filter if given
    my %SearchFilter;
    if ( IsArrayRefWithData($Self->{Filter}->{ConfigItem}->{AND}) ) {
        foreach my $FilterItem ( @{$Self->{Filter}->{ConfigItem}->{AND}} ) {
            # ignore everything that we don't support in the core DB search (the rest will be done in the generic API filtering)
            next if ($FilterItem->{Field} !~ /^(ClassID|Name|Number)$/g);
            next if ($FilterItem->{Operator} ne 'EQ');

            if ($FilterItem->{Field} eq 'ClassID') {
                $SearchFilter{ClassIDs} = [ $FilterItem->{Value} ];
            }
            else {
                $SearchFilter{$FilterItem->{Field}} = $FilterItem->{Value};
            }
        }
    }

    # execute ConfigItem search
    my $ConfigItemList = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemSearchExtended(
        %SearchFilter,
        UserID  => $Self->{Authorization}->{UserID},
    );

	# get already prepared CI data from ConfigItemGet operation
    if ( IsArrayRefWithData($ConfigItemList) ) {  	
        my $GetResult = $Self->ExecOperation(
            OperationType => 'V1::CMDB::ConfigItemGet',
            Data      => {
                ConfigItemID => join(',', sort @{$ConfigItemList}),
            }
        );    

        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @DataList = IsArrayRefWithData($GetResult->{Data}->{ConfigItem}) ? @{$GetResult->{Data}->{ConfigItem}} : ( $GetResult->{Data}->{ConfigItem} );

        if ( IsArrayRefWithData(\@DataList) ) {
            return $Self->_Success(
                ConfigItem => \@DataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ConfigItem => [],
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