# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketTemplate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::Main',
    'Kernel::System::Log',
    'Kernel::System::SysConfig',
    'Kernel::System::JSON'
);

=head1 NAME

Kernel::System::Ticket::TicketTemplate

=head1 SYNOPSIS

All ticket temaplte functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TicketTemplateObject = $Kernel::OM->Get('Kernel::System::TicketTemplate');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=on;
    $Self->{Debug} = $Param{Debug} || 0;

    $Self->{CacheType} = 'TicketTemplate';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    return $Self;
}

=item TicketTemplateGet()

Returns data of one ticket template

    my %Hash = $TicketObject->TicketTemplateGet(
        Name  => 'TicketTemplateName'
    );

    my %Result = {
    Name => 'TicketTemplateName',
    title => 'some template title',
    ....
    }

=cut

sub TicketTemplateGet {
    my ($Self, %Param) = @_;

    my %Template;

    # check needed stuff
    if (!$Param{Name}) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message => "TicketTemplateGet: Need Name!");
        return;
    }

    # check if template is cached
    my $CacheKey = 'Cache::TicketTemplateGet::' . $Param{Name};
    if ($Self->{$CacheKey}) {
        return %{$Self->{$CacheKey}};
    }

    my %SysConfigOption = $Kernel::OM->Get('Kernel::System::SysConfig')->OptionGet(
        Name => 'Ticket::Template::Definitions'
    );

    my $AllTemplates = $Kernel::OM->Get('Kernel::System::JSON')->Decode(
        Data => ($SysConfigOption{isModified}) ? $SysConfigOption{Value} : $SysConfigOption{Default},
    );

    if(!isArrayRefWithData($AllTemplates)) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message => "TicketTemplateGet: No templates found!");
        return;
    }

    my $Result;
    foreach my $Template (@{$AllTemplates}) {
        next if $Template->{TemplateID} ne $Param{Name};

        $Result = $Template;
        last;
    }

    if (!$Result) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message => "TicketTemplateGet: No template wit name '$Param{Name}' found!");
        return;
    }
    
    # set ticket template cache
    $Self->{$CacheKey} = {
        $Result,
    };

    return $Result;
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
