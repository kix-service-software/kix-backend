# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemVersionGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ConfigItemVersionGet - API ConfigItemVersionGet Operation backend

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
            DataType => 'NUMERIC',
            Required => 1
        },
        'VersionID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        },
    }
}

=item Run()

perform ConfigItemVersionGet Operation.

    my $Result = $OperationObject->Run(
        ConfigItemID => 1,                                # required 
        VersionID    => 1                                 # required
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            ConfigItemVersion => [
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @VersionList;        

    # check if ConfigItem exists
    my $ConfigItem = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemGet(
        ConfigItemID => $Param{Data}->{ConfigItemID},
    );

    if (!IsHashRefWithData($ConfigItem)) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "ConfigItem $Param{Data}->{ConfigItemID} does not exist",
        );
    }

    # get all versions of ConfigItem (it's cheaper than getting selected version by single requests)
    my $Versions = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->VersionZoomList(
        ConfigItemID => $Param{Data}->{ConfigItemID},
    );

    if (IsArrayRefWithData($Versions)) {
        my %VersionListMap = map { $_->{VersionID} => $_ } @{$Versions};
    
        foreach my $VersionID ( @{$Param{Data}->{VersionID}} ) {                 

            my $Version = $VersionListMap{$VersionID};

            if (!IsHashRefWithData($Version)) {
                return $Self->_Error(
                    Code    => 'Object.NotFound',
                    Message => "Could not get data for VersionID $VersionID in ConfigItemID $Param{Data}->{ConfigItemID}",
                );
            }     

            # include Definition if requested
            if ( $Param{Data}->{include}->{Definition} ) {
                # get already prepared Definition data from ClassDefinitionGet operation
                my $Result = $Self->ExecOperation(
                    OperationType => 'V1::CMDB::ClassDefinitionGet',
                    Data          => {
                        ClassID      => $ConfigItem->{ClassID},
                        DefinitionID => $Version->{DefinitionID},
                    }
                );
                if ( IsHashRefWithData($Result) && $Result->{Success} ) {
                    $Version->{Definition} = $Result->{Data}->{ConfigItemClassDefinition};
                }
            }

            # include XMLData if requested
            if ( $Param{Data}->{include}->{XMLData} ) {
                my $VersionData = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->VersionGet(
                    VersionID  => $VersionID,
                    XMLDataGet => 1,
                );

                $Version->{XMLData} = $VersionData->{XMLData};
            }

            push(@VersionList, $Version);
        }

        if ( scalar(@VersionList) == 0 ) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "Could not get data for VersionID ".join(',', $Param{Data}->{VersionID}),
            );
        }
        elsif ( scalar(@VersionList) == 1 ) {
            return $Self->_Success(
                ConfigItemVersion => $VersionList[0],
            );    
        }
    }

    return $Self->_Success(
        ConfigItemVersion => \@VersionList,
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
