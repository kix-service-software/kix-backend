# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::TicketTemplate::TicketTemplateGet;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

 Kernel::API::Operation::V1::TicketTemplate::TicketTemplateGet - API Ticket Template Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ($Type, %Param) = @_;

    my $Self = {};
    bless($Self, $Type);

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if (!$Param{$Needed}) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }
    # get config for this screen
    # $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::TicketTemplate::TicketTemplateGet');

    return $Self;
}

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            TemplateName => 'some template name, some other name'   # required, can be comma separated list of names
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ($Self, %Param) = @_;

    return {
        'TemplateName' => {
            Type     => 'ARRAY',
            DataType => 'STRING',
            Required => 1
        },
    }
}

=item Run()

perform TicketTemplateGet Operation. This function is able to return
one or more ticket templates in one call.

    my $Result = $OperationObject->Run(
        Data => {
            TemplateName => 'some name,some other name',     # required, could be coma separated Names
        },
    );

    $Result = {}

=cut

sub Run {
    my ($Self, %Param) = @_;

    my @TicketTemplateList;
    foreach my $Name (@{$Param{Data}->{TemplateName}}) {
        my %TemplateData = $Kernel::OM->Get('Kernel::System::TicketTemplate')->TicketTemplateGet(
            Name => $Name,
        );
        if (!IsHashRefWithData(\%TemplateData)) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        push(@TicketTemplateList, \%TemplateData);
    }

    if (scalar(@TicketTemplateList) == 1) {
        return $Self->_Success(
            TicketTemplate => $TicketTemplateList[0],
        );
    }

    return $Self->_Success(
        TicketTemplate => \@TicketTemplateList,
    );
}


