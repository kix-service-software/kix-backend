# --
# Kernel/API/Operation/V1/SysConfig/SysConfigGet.pm - API SysConfig Get operation backend
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

package Kernel::API::Operation::V1::SysConfig::SysConfigItemDefinitionGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SysConfig::SysConfigItemDefinitionGet - API SysConfigItem Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::SysConfig::SysConfigItemDefinitionGet->new();

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

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::SysConfig::SysConfigItemDefinitionGet');

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
        'SysConfigItemDefinitionID' => {
            Type     => 'ARRAY',
            Required => 1
        },           
    }
}

=item Run()

perform SysConfigItemDefinitionGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            SysConfigItemID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            SysConfigItemDefinition => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @SysConfigList;

    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

    # start loop 
    foreach my $ItemID ( @{$Param{Data}->{SysConfigItemDefinitionID}} ) {

        # get the SysConfig data
        my %Config = $SysConfigObject->ConfigItemGet(
            Name => $ItemID,    
        );

        if ( IsHashRefWithData(\%Config) ) {

            my $RestructuredConfig = $Self->_RestructureConfig(
                %Config,
            );

            # add
            push(@SysConfigList, $RestructuredConfig);
        }
    }

    if ( scalar(@SysConfigList) == 1 ) {
        return $Self->_Success(
            SysConfigItemDefinition => $SysConfigList[0],
        );    
    }

    # return result
    return $Self->_Success(
        SysConfigItemDefinition => \@SysConfigList,
    );
}

sub _RestructureConfig {
    my ( $Self, %Param ) = @_;
    my %Result;
    
    # restructure for better use
    foreach my $Key ( qw(Group SubGroup Description Required) ) {
        if ( IsArrayRefWithData($Param{$Key}) ) {
            $Result{$Key} = $Param{$Key}->[1]->{Content};
        }
        else {
            $Result{$Key} = $Param{$Key};
        }
    }

    # map Name to ID
    $Result{ID} = $Param{Name};

    # map Valid to Active
    $Result{Active} = $Param{Valid};

    # handle Settings
    if ( IsArrayRefWithData($Param{Setting}) ) {
        if ($Param{Setting}->[1]->{String}) {
            $Result{Type} = 'String';
            $Result{Config} = $Param{Setting}->[1]->{String}->[1];
        }
        elsif ($Param{Setting}->[1]->{TextArea}) {
            $Result{Type} = 'TextArea';
            $Result{Config} = $Param{Setting}->[1]->{TextArea}->[1];
        }
        elsif ($Param{Setting}->[1]->{Array}) {
            $Result{Type} = 'Array';
            foreach my $Item (@{$Param{Setting}->[1]->{Array}->[1]->{Item}}) {
                next if !$Item;
                push(@{$Result{Config}->{Items}}, $Item->{Content});
            }
        }
        elsif ($Param{Setting}->[1]->{Option}) {
            $Result{Type} = 'Option';
            $Result{Config}->{Selected} = $Param{Setting}->[1]->{Option}->[1]->{SelectedID};
            $Result{Config}->{Default} = $Param{Setting}->[1]->{Option}->[1]->{Default};
            $Result{Config}->{Location} = $Param{Setting}->[1]->{Option}->[1]->{Location};
            foreach my $Item (@{$Param{Setting}->[1]->{Option}->[1]->{Item}}) {
                next if !$Item;
                push(@{$Result{Config}->{Items}}, {
                    Key   => $Item->{Key},
                    Label => $Item->{Content},
                });
            }
        }
        elsif ($Param{Setting}->[1]->{Hash}) {
            $Result{Type} = 'Hash';
            foreach my $Item (@{$Param{Setting}->[1]->{Hash}->[1]->{Item}}) {
                next if !$Item;
                push(@{$Result{Config}->{Items}}, {
                    Key   => $Item->{Key},
                    Value => $Item->{Content},
                });
            }
        }
        elsif ($Param{Setting}->[1]->{TimeVacationDays}) {
            $Result{Type} = 'TimeVacationDays';
            foreach my $Item (@{$Param{Setting}->[1]->{TimeVacationDays}->[1]->{Item}}) {
                next if !$Item;
                push(@{$Result{Config}->{Items}}, {
                    Date  => sprintf('%02i-%02i', $Item->{Month}, $Item->{Day}),
                    Label => $Item->{Content},
                });
            }
        }
        elsif ($Param{Setting}->[1]->{TimeVacationDaysOneTime}) {
            $Result{Type} = 'TimeVacationDaysOneTime';
            foreach my $Item (@{$Param{Setting}->[1]->{TimeVacationDaysOneTime}->[1]->{Item}}) {
                next if !$Item;
                push(@{$Result{Config}->{Items}}, {
                    Date  => sprintf('%04i-%02i-%02i', $Item->{Year}, $Item->{Month}, $Item->{Day}),
                    Label => $Item->{Content},
                });
            }
        }
        elsif ($Param{Setting}->[1]->{TimeWorkingHours}) {
            $Result{Type} = 'TimeWorkingHours';
            foreach my $Item (@{$Param{Setting}->[1]->{TimeWorkingHours}->[1]->{Item}}) {
                next if !$Item;
                # push(@{$Result{Config}->{Items}}, {
                #     Day          => $Item->{Name},
                #     WorkingHours => join(',', @WorkingHours),
                # });
            }            
        }
    }

    return \%Result;
}

1;
