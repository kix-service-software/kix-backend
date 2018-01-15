# --
# Kernel/API/Operation/TextModule/TextModuleCreate.pm - API TextModule Create operation backend
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

package Kernel::API::Operation::V1::TextModule::TextModuleCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TextModule::TextModuleCreate - API TextModule Create Operation backend

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

    return $Self;
}

=item Run()

perform TextModuleCreate Operation. This will return the created TextModuleID.

    my $Result = $OperationObject->Run(
        Data => {
            TextModule  => {
                Name                => '...',
                Text                => '...',
                Language            => '...',       # optional, if not given set to DefaultLanguage with fallback 'en'
                Category            => '...',       # optional
                Comment             => '...',       # optional
                Keywords            => '...',       # optional
                Subject             => '...',       # optional
                AgentFrontend       => 0|1,         # optional
                CustomerFrontend    => 0|1,         # optional
                PublicFrontend      => 0|1,         # optional
                ValidID             => 1            # optional
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            TextModuleID  => '',                    # ID of the created TextModule
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webTextModule
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'WebService.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # get system LanguageIDs
    my $Languages = $Kernel::OM->Get('Kernel::Config')->Get('DefaultUsedLanguages');
    my @LanguageIDs = sort keys %{$Languages};

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'TextModule' => {
                Type     => 'HASH',
                Required => 1
            },
            'TextModule::Name' => {
                Required => 1
            },            
            'TextModule::Text' => {
                Required => 1
            },
            'TextModule::Language' => {
                RequiresValueIfUsed => 1,
                OneOf => \@LanguageIDs
            },
            'TextModule::AgentFrontend' => {
                RequiresValueIfUsed => 1,
                OneOf    => [
                    0,
                    1
                ]
            },
            'TextModule::CustomerFrontend' => {
                RequiresValueIfUsed => 1,
                OneOf    => [
                    0,
                    1
                ]
            },
            'TextModule::PublicFrontend' => {
                RequiresValueIfUsed => 1,
                OneOf    => [
                    0,
                    1
                ]
            },
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # isolate and trim TextModule parameter
    my $TextModule = $Self->_Trim(
        Data => $Param{Data}->{TextModule}
    );

    # check attribute values
    my $CheckResult = $Self->_CheckTextModule( 
        TextModule => $TextModule
    );

    if ( !$CheckResult->{Success} ) {
        return $Self->_Error(
            %{$CheckResult},
        );
    }

    # check if TextModule exists
    my $ExistingTextModuleIDs = $Kernel::OM->Get('Kernel::System::TextModule')->TextModuleList(
        Name => $TextModule->{Name},
    );
    
    if ( IsArrayRefWithData($ExistingTextModuleIDs) ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create TextModule. A TextModule with the same name already exists.",
        );
    }
    
    # create TextModule
    my $TextModuleID = $Kernel::OM->Get('Kernel::System::TextModule')->TextModuleAdd(
        Name               => $TextModule->{Name},
        Text               => $TextModule->{Text} || '',
        Category           => $TextModule->{Category} || '',
        Language           => $TextModule->{Language} || '',
        Subject            => $TextModule->{Subject} || '',
        Keywords           => $TextModule->{Keywords} || '',
        Comment            => $TextModule->{Comment} || '',
        AgentFrontend      => $TextModule->{AgentFrontend},
        CustomerFrontend   => $TextModule->{CustomerFrontend},
        PublicFrontend     => $TextModule->{PublicFrontend},        
        ValidID            => $TextModule->{ValidID} || 1,
        UserID             => $Self->{Authorization}->{UserID},
    );

    if ( !$TextModuleID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create TextModule, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        TextModuleID => $TextModuleID,
    );    
}


1;
