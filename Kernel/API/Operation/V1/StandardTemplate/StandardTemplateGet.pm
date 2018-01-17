# --
# Kernel/API/Operation/V1/StandardTemplate/StandardTemplateGet.pm - API StandardTemplate Get operation backend
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

package Kernel::API::Operation::V1::StandardTemplate::StandardTemplateGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::StandardTemplate::StandardTemplateGet - API StandardTemplate Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::StandardTemplate::StandardTemplateGet->new();

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
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::StandardTemplate::StandardTemplateGet');

    return $Self;
}

=item Run()

perform StandardTemplateGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            TemplateID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            StandardTemplate => [
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

    # init webservice
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
        Parameters => {
            'TemplateID' => {
                Type     => 'ARRAY',
                DataType => 'NUMERIC',
                Required => 1
            }                
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    my @StandardTemplateList;

    # start state loop
    StandardTemplate:    
    foreach my $TemplateID ( @{$Param{Data}->{TemplateID}} ) {

        # get the StandardTemplate data
        my %StandardTemplateData = $Kernel::OM->Get('Kernel::System::StandardTemplate')->StandardTemplateGet(
            ID => $TemplateID,
        );

        if ( !$Param{Data}->{include}->{Content} ) {
            delete $StandardTemplateData{Content};
        }

        if ( !IsHashRefWithData( \%StandardTemplateData ) ) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "No data found for TemplateID $TemplateID.",
            );
        }
        
        # add
        push(@StandardTemplateList, \%StandardTemplateData);
    }

    if ( scalar(@StandardTemplateList) == 1 ) {
        return $Self->_Success(
            StandardTemplate => $StandardTemplateList[0],
        );    
    }

    # return result
    return $Self->_Success(
        StandardTemplate => \@StandardTemplateList,
    );
}

1;
