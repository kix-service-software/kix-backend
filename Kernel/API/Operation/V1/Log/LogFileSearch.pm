# --
# Kernel/API/Operation/LogFile/LogFileCreate.pm - API LogFile Create operation backend
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

package Kernel::API::Operation::V1::Log::LogFileSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Log::LogFileSearch - API LogFile Search Operation backend

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

perform LogFileSearch Operation. This will return a LogFile ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            LogFile => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform LogFile search
    my %LogFileList = $Kernel::OM->Get('Kernel::System::LogFile')->LogFileList();

	# get already prepared LogFile data from LogFileGet operation
    if ( IsHashRefWithData(\%LogFileList) ) {  	
        my $LogFileGetResult = $Self->ExecOperation(
            OperationType => 'V1::Log::LogFileGet',
            Data      => {
                LogFileID => join(',', sort keys %LogFileList),
            }
        );    

        if ( !IsHashRefWithData($LogFileGetResult) || !$LogFileGetResult->{Success} ) {
            return $LogFileGetResult;
        }

        my @LogFileDataList = IsArrayRefWithData($LogFileGetResult->{Data}->{LogFile}) ? @{$LogFileGetResult->{Data}->{LogFile}} : ( $LogFileGetResult->{Data}->{LogFile} );

        if ( IsArrayRefWithData(\@LogFileDataList) ) {
            return $Self->_Success(
                LogFile => \@LogFileDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        LogFile => [],
    );
}

1;