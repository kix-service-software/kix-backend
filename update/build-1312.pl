#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Getopt::Std;

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1312',
    },
);
my $LogObject = $Kernel::OM->Get('Log');

use vars qw(%INC);

# migrate filter structures of existing jobs
_MigrateJobFilters();

# migrate filter structures of existing notifications
_MigrateNotificationFilters();

# delete whole cache
$Kernel::OM->Get('Cache')->CleanUp();

exit 0;

sub _MigrateJobFilters {
    my $AutomationObject = $Kernel::OM->Get('Automation');

    my %ObjectList = (
        Type      => { reverse $Kernel::OM->Get('Type')->TypeList() },
        State     => { reverse $Kernel::OM->Get('State')->StateList( UserID => 1 ) },
        StateType => { reverse $Kernel::OM->Get('State')->StateTypeList( UserID => 1 ) },
    );

    my %Jobs = $AutomationObject->JobList();

    foreach my $JobID ( keys %Jobs ) {
        my %Job = $AutomationObject->JobGet(
            ID => $JobID
        );
        if ( !%Job ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Job with ID bot found!"
            );
            next;
        }

        next if !IsHashRefWithData($Job{Filter});

        my @Filter;
        foreach my $Attribute ( sort keys %{$Job{Filter}} ) {
            my $Field = $Attribute;
            if ( $Attribute =~ /^(.*?)::(.*?)$/g ) {
                $Field = $2;
            }
            my $ValueCount = scalar(@{$Job{Filter}->{$Attribute}});

            if ( $ObjectList{$Field} ) {
                my @Values;
                foreach my $Value ( @{$Job{Filter}->{$Attribute}} ) {
                    if ( $ObjectList{$Field}->{$Value} ) {
                        push @Values, $ObjectList{$Field}->{$Value};
                    }
                }
                $Job{Filter}->{$Attribute} = \@Values;
                $Field = $Field . 'ID';
            }

            push @Filter, {
                Field    => $Field,
                Operator => $ValueCount > 1 ? 'IN' : 'EQ',
                Value    => $ValueCount > 1 ? $Job{Filter}->{$Attribute} : $Job{Filter}->{$Attribute}->[0]
            };
        }
        if ( IsArrayRefWithData(\@Filter) ) {
            $Job{Filter} = {
                AND => \@Filter
            };
        }

        my $Result = $AutomationObject->JobUpdate(
            %Job,
            UserID => 1,
        );
        if ( !$Result ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to update job $JobID ($Job{Name})!"
            );
        }
    }

    return 1;
}

sub _MigrateNotificationFilters {
    my $NotificationObject = $Kernel::OM->Get('NotificationEvent');

    my %ObjectList = (
        Type      => { reverse $Kernel::OM->Get('Type')->TypeList() },
        State     => { reverse $Kernel::OM->Get('State')->StateList( UserID => 1 ) },
        StateType => { reverse $Kernel::OM->Get('State')->StateTypeList( UserID => 1 ) },
    );

    my %Notifications = $NotificationObject->NotificationList(
        Details => 1
    );

    foreach my $NotificationID ( keys %Notifications ) {
        my %Notification = %{$Notifications{$NotificationID}};

        next if !IsHashRefWithData($Notification{Data});

        my @Filter;
        foreach my $Key ( sort keys %{$Notification{Data}} ) {
            # ignore everything that's not a filter item
            next if $Key !~ /^(Ticket|Article)::/;

            my $Field = $Key;
            if ( $Field =~ /^(.*?)::(.*?)$/g ) {
                $Field = $2;
            }
            my $ValueCount = scalar(@{$Notification{Data}->{$Key}});

            if ( $ObjectList{$Field} ) {
                # map to ID
                my @Values;
                foreach my $Value ( @{$Notification{Data}->{$Key}} ) {
                    if ( $ObjectList{$Field}->{$Value} ) {
                        push @Values, $ObjectList{$Field}->{$Value};
                    }
                }
                $Notification{Data}->{$Key} = \@Values;

                $Field = $Field . 'ID';
            }

            push @Filter, {
                Field    => $Field,
                Operator => $ValueCount > 1 ? 'IN' : 'EQ',
                Value    => $ValueCount > 1 ? $Notification{Data}->{$Key} : $Notification{Data}->{$Key}->[0]
            };
        }
        if ( IsArrayRefWithData(\@Filter) ) {
            $Notification{Filter} = {
                AND => \@Filter
            };
        }

        my $Result = $NotificationObject->NotificationUpdate(
            %Notification,
            UserID => 1,
        );
        if ( !$Result ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to update notification $NotificationID ($Notification{Name})!"
            );
        }
    }

    return 1;
}

exit 0;

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
