# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::SysConfig::Event::LogSysConfigChanges;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Log',
    'SysConfigChangeLog',
    'User',
);

=head1 NAME

Kernel::System::SysConfig::Event::LogSysConfigChanges

=head1 SYNOPSIS

SysConfig change logger

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a SysConfig::Event::LogSysConfigChanges object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $SysConfigEventLogSysConfigChangesObject = $Kernel::OM->Get('SysConfig::Event::LogSysConfigChanges');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{LogObject}                = $Kernel::OM->Get('Log');
    $Self->{UserObject}               = $Kernel::OM->Get('User');
    $Self->{SysConfigChangeLogObject} = $Kernel::OM->Get('SysConfigChangeLog');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Event Data UserID)) {
        if ( !$Param{$Needed} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $Needed!" );
            return;
        }
    }
    for my $Needed (qw(Name OldOption NewOption)) {
        if ( !$Param{Data}->{$Needed} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $Needed in Data!" );
            return;
        } elsif ($Needed ne 'Name' && !IsHashRefWithData($Param{Data}->{$Needed})) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Data->$Needed has no data!" );
            return;
        }
    }

    # get user data
    my %UserData = $Self->{UserObject}->GetUserData(
        UserID => $Param{UserID},
    );
    if (!IsHashRefWithData(\%UserData)) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Could not load user data!" );
        return;
    }

    if ( $Param{Data}->{OldOption}->{ValidID} != $Param{Data}->{NewOption}->{ValidID} ) {
        my $Enabled = $Param{Data}->{NewOption}->{ValidID} == 1 ? 'enabled' : 'disabled';
        $Self->{SysConfigChangeLogObject}->Log(
            Priority => 'notice',
            Message  => "User $UserData{UserLogin} $Enabled option '$Param{Data}->{Name}'",
        );
    }
    if (
        DataIsDifferent(
            Data1 => $Param{Data}->{OldOption}->{Value} || \(''),
            Data2 => $Param{Data}->{NewOption}->{Value} || \('')
        )
    ) {
        use Data::Dumper;
        my $OldValueDump = !defined $Param{Data}->{OldOption}->{Value} ?
            "(DEFAULT) " . Dumper( $Param{Data}->{OldOption}->{Default} ) :
            Dumper( $Param{Data}->{OldOption}->{Value} );
        $OldValueDump =~ s/\$VAR1 = //g;
        my $NewValueDump = !defined $Param{Data}->{NewOption}->{Value} ?
            "(DEFAULT) " . Dumper( $Param{Data}->{NewOption}->{Default} ) :
            Dumper( $Param{Data}->{NewOption}->{Value} );
        $NewValueDump =~ s/\$VAR1 = //g;

        # write SysConfig changelog
        $Self->{SysConfigChangeLogObject}->Log(
            Priority => 'notice',
            Message  => "User $UserData{UserLogin} changed option '$Param{Data}->{Name}'\nOLD: "
                . $OldValueDump . "NEW: "
                . $NewValueDump,
        );
    }

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
