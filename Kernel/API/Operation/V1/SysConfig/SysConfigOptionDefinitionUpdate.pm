# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SysConfig::SysConfigOptionDefinitionUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SysConfig::SysConfigOptionDefinitionUpdate - API SysConfigOptionDefinitionUpdate Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to update an instance of this
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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::SysConfigOptionDefinitionUpdate');

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

    my @SupportedTypes = $Kernel::OM->Get('Kernel::System::SysConfig')->OptionTypeList();

    return {
        'Option' => {
            Required => 1
        },
        'SysConfigOptionDefinition' => {
            Type => 'HASH',
            Required => 1
        },
        'SysConfigOptionDefinition::Description' => {
            RequiresValueIfUsed => 1,
        },
        'SysConfigOptionDefinition::AccessLevel' => {
            RequiresValueIfUsed => 1,
        },
        'SysConfigOptionDefinition::IsRequired' => {
            RequiresValueIfUsed => 1,
            OneOf               => [ 0, 1 ]
        },
        'SysConfigOptionDefinition::Type' => {
            RequiresValueIfUsed => 1,
            OneOf               => \@SupportedTypes
        },
    }
}

=item Run()

perform SysConfigOptionDefinitionUpdate Operation. This will return the updated Option.

    my $Result = $OperationObject->Run(
        Data => {
            Option => 'test',
    	    SysConfigOptionDefinition   => {
                ...
    	    },
        }
    );
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            Option  => '',                      # Option
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim SysConfigOptionDefinition parameter
    my $SysConfigOptionDefinition = $Self->_Trim(
        Data => $Param{Data}->{SysConfigOptionDefinition}
    );

    # check if SysConfigOptionDefinition exists
    my $Exists = $Kernel::OM->Get('Kernel::System::SysConfig')->Exists(
        Name => $Param{Data}->{Option},
    );
    
    if ( !$Exists ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
        );
    }

    # get SysConfigOptionDefinition
    my %OptionData = $Kernel::OM->Get('Kernel::System::SysConfig')->OptionGet(
        Name => $Param{Data}->{Option},
    );    

    # update SysConfigOptionDefinition
    my $Success = $Kernel::OM->Get('Kernel::System::SysConfig')->OptionUpdate(
        Name            => $Param{Data}->{Option},
        Type            => exists $SysConfigOptionDefinition->{Type} ? $SysConfigOptionDefinition->{Type} : $OptionData{Type},
        Context         => exists $SysConfigOptionDefinition->{Context} ? $SysConfigOptionDefinition->{Context} : $OptionData{Context},
        ContextMetadata => exists $SysConfigOptionDefinition->{ContextMetadata} ? $SysConfigOptionDefinition->{ContextMetadata} : $OptionData{ContextMetadata},
        Description     => exists $SysConfigOptionDefinition->{Description} ? $SysConfigOptionDefinition->{Description} : $OptionData{Description},
        Comment         => exists $SysConfigOptionDefinition->{Comment} ? $SysConfigOptionDefinition->{Comment} : $OptionData{Comment},
        AccessLevel     => exists $SysConfigOptionDefinition->{AccessLevel} ? $SysConfigOptionDefinition->{AccessLevel} : $OptionData{AccessLevel},
        ExperienceLevel => exists $SysConfigOptionDefinition->{ExperienceLevel} ? $SysConfigOptionDefinition->{ExperienceLevel} : $OptionData{ExperienceLevel},
        Group           => exists $SysConfigOptionDefinition->{Group} ? $SysConfigOptionDefinition->{Group} : $OptionData{Group},
        IsRequired      => exists $SysConfigOptionDefinition->{IsRequired} ? $SysConfigOptionDefinition->{IsRequired} : $OptionData{IsRequired},
        Setting         => exists $SysConfigOptionDefinition->{Setting} ? $SysConfigOptionDefinition->{Setting} : $OptionData{Setting},
        Default         => exists $SysConfigOptionDefinition->{Default} ? $SysConfigOptionDefinition->{Default} : $OptionData{Default},
        ValidID         => exists $SysConfigOptionDefinition->{ValidID} ? $SysConfigOptionDefinition->{ValidID} : $OptionData{ValidID},
        UserID          => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result    
    return $Self->_Success(
        Option => $Param{Data}->{Option},
    );    
}



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
