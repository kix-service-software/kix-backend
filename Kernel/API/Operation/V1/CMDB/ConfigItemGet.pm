# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ConfigItemGet - API ConfigItemGet Operation backend

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
        'ConfigItemID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        },
    }
}

=item Run()

perform ConfigItemGet Operation. 

    my $Result = $OperationObject->Run(
        ConfigItemID => 1,                                # required 
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            ConfigItem => [
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @ConfigItemList;        
    foreach my $ConfigItemID ( @{$Param{Data}->{ConfigItemID}} ) {                 

        my $ConfigItem = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemGet(
            ConfigItemID => $ConfigItemID,
        );

        if (!IsHashRefWithData($ConfigItem)) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "Could not get data for ConfigItemID $ConfigItemID",
            );
        }     

        # include CurrentVersion if requested
        if ( $Param{Data}->{include}->{CurrentVersion} ) {
            # get already prepared data of current version from VersionSearch operation
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::CMDB::ConfigItemVersionGet',
                Data          => {
                    ConfigItemID  => $ConfigItemID,
                    VersionID     => $ConfigItem->{LastVersionID},
                }
            );
            if ( IsHashRefWithData($Result) && $Result->{Success} ) {
                $ConfigItem->{CurrentVersion} = $Result->{Data}->{ConfigItemVersion};
            }
        }

        # include Versions if requested
        if ( $Param{Data}->{include}->{Versions} ) {
            # get already prepared Versions data from VersionSearch operation
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::CMDB::ConfigItemVersionSearch',
                Data          => {
                    ConfigItemID  => $ConfigItemID,
                }
            );
            if ( IsHashRefWithData($Result) && $Result->{Success} ) {
                $ConfigItem->{Versions} = $Result->{Data}->{ConfigItemVersion};
            }
        }

        # include Versions if requested
        if ( $Param{Data}->{include}->{History} ) {
            # get already prepared Versions data from VersionSearch operation
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::CMDB::ConfigItemHistorySearch',
                Data          => {
                    ConfigItemID  => $ConfigItemID,
                }
            );
            if ( IsHashRefWithData($Result) && $Result->{Success} ) {
                $ConfigItem->{History} = $Result->{Data}->{ConfigItemHistory};
            }
        }

        push(@ConfigItemList, $ConfigItem);
    }

    if ( scalar(@ConfigItemList) == 0 ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Could not get data for ConfigItemID ".join(',', $Param{Data}->{ConfigItemID}),
        );
    }
    elsif ( scalar(@ConfigItemList) == 1 ) {
        return $Self->_Success(
            ConfigItem => $ConfigItemList[0],
        );    
    }

    return $Self->_Success(
        ConfigItem => \@ConfigItemList,
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
