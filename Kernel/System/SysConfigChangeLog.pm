# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::SysConfigChangeLog;

use strict;
use warnings;

use Carp ();

our @ObjectDependencies = (
    'Config',
    'Encode',
    'Main'
);

=head1 NAME

Kernel::System::SysConfigChangeLog - global log interface

=head1 SYNOPSIS

All log functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a log object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'SysConfigChangeLog' => {
            LogPrefix => 'InstallScriptX',  # not required, but highly recommend
        },
    );
    my $SysConfigChangeLogObject = $Kernel::OM->Get('SysConfigChangeLog');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    if ( !$Kernel::OM ) {
        Carp::confess('$Kernel::OM is not defined, please initialize your object manager')
    }

    my $ConfigObject = $Kernel::OM->Get('Config');
    $Self->{ProductVersion} = $ConfigObject->Get('Product') . ' ';
    $Self->{ProductVersion} .= $ConfigObject->Get('Version');

    # get system id
    my $SystemID = $ConfigObject->Get('SystemID');

    # check log prefix
    $Self->{LogPrefix} = $Param{LogPrefix} || '?LogPrefix?';
    $Self->{LogPrefix} .= '-' . $SystemID;

    # load log backend
    my $GenericModule = 'Kernel::System::SysConfigChangeLog::File';

    # get main object
    my $MainObject = $Kernel::OM->Get('Main');

    if ( !$MainObject->Require( $GenericModule ) ) {
        die "Can't load log backend module $GenericModule! $@";
    }

    # create backend handle
    $Self->{Backend} = $GenericModule->new(
        %Param,
    );

    return $Self;
}

1;

=item Log()

log something. log priorities are 'debug', 'info', 'notice' and 'error'.

These are mapped to the SysLog priorities. Please use the appropriate priority level:

=over

=item debug

Debug-level messages; info useful for debugging the application, not useful during operations.

=item info

Informational messages; normal operational messages - may be used for reporting etc, no action required.

=item notice

Normal but significant condition; events that are unusual but not error conditions, no immediate action required.

=item error

Error conditions. Non-urgent failures, should be relayed to developers or admins, each item must be resolved.

=back

    $LogObject->Log(
        Priority => 'error',
        Message  => "Need something!",
    );

=cut

sub Log {
    my ( $Self, %Param ) = @_;

    my $Priority = lc( $Param{Priority} ) || 'debug';
    my $Message  = $Param{MSG}            || $Param{Message} || '???';
    my $Caller   = $Param{Caller}         || 0;

    # returns the context of the current subroutine and sub-subroutine!
    my ( $Package1, $Filename1, $Line1, $Subroutine1 ) = caller( $Caller + 0 );
    my ( $Package2, $Filename2, $Line2, $Subroutine2 ) = caller( $Caller + 1 );

    $Subroutine2 ||= $0;

    # log backend
    $Self->{Backend}->Log(
        Priority  => $Priority,
        Message   => $Message,
        LogPrefix => $Self->{LogPrefix},
        Module    => $Subroutine2,
        Line      => $Line1,
    );

    return 1;
}

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
