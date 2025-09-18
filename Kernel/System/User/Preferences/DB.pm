# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::User::Preferences::DB;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # preferences table data
    $Self->{PreferencesTable} = $Kernel::OM->Get('Config')->Get('PreferencesTable')
        || 'user_preferences';
    $Self->{PreferencesTableKey} = $Kernel::OM->Get('Config')->Get('PreferencesTableKey')
        || 'preferences_key';
    $Self->{PreferencesTableValue} = $Kernel::OM->Get('Config')->Get('PreferencesTableValue')
        || 'preferences_value';
    $Self->{PreferencesTableUserID} = $Kernel::OM->Get('Config')->Get('PreferencesTableUserID')
        || 'user_id';

    $Self->{CacheType} = 'User';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    # create cache prefix
    $Self->{CachePrefix} = 'UserPreferencesDB'
        . $Self->{PreferencesTable}
        . $Self->{PreferencesTableKey}
        . $Self->{PreferencesTableValue}
        . $Self->{PreferencesTableUserID};

    return $Self;
}

sub SetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(UserID Key)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # prepare multiple values (i.e. MyQueues, MyServices, ...)
    my @Values;
    if ( IsArrayRefWithData($Param{Value}) ) {
        @Values = @{$Param{Value}};
    }
    else {
        push @Values, ($Param{Value} // '');
    }

    my $DBObject = $Kernel::OM->Get('DB');

    # delete old data
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM $Self->{PreferencesTable}
            WHERE $Self->{PreferencesTableUserID} = ?
                AND $Self->{PreferencesTableKey} = ?",
        Bind => [ \$Param{UserID}, \$Param{Key} ],
    );

    foreach my $Value ( @Values ) {
        # insert new data
        return if !$DBObject->Do(
            SQL => "
                INSERT INTO $Self->{PreferencesTable}
                ($Self->{PreferencesTableUserID}, $Self->{PreferencesTableKey}, $Self->{PreferencesTableValue})
                VALUES (?, ?, ?)",
            Bind => [ \$Param{UserID}, \$Param{Key}, \$Value ],
        );
    }

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # TODO: find another solution to delete caches depending on user language
    # trigger special cache delete for cached transaltions/localisation
    if ( $Param{Key} eq 'UserLanguage' ) {
        $Kernel::OM->Get('Cache')->CleanUp(
            Type => 'UserLanguage',
        );
    }

    # TODO: find another solution to delete caches depending on 'MyQueues'
    # trigger special cache delete for cached ticket searches
    if ( $Param{Key} eq 'MyQueues' ) {
        $Kernel::OM->Get('Cache')->CleanUp(
            Type => 'ObjectSearch_Ticket',
        );
    }

    return 1;
}

sub GetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $Self->{CachePrefix} . $Param{UserID},
    );
    return %{$Cache} if $Cache;

    my $DBObject = $Kernel::OM->Get('DB');

    # get preferences
    return if !$DBObject->Prepare(
        SQL => "
            SELECT $Self->{PreferencesTableKey}, $Self->{PreferencesTableValue}
            FROM $Self->{PreferencesTable}
            WHERE $Self->{PreferencesTableUserID} = ?",
        Bind => [ \$Param{UserID} ],
    );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( exists $Data{ $Row[0] } && !IsArrayRefWithData($Data{ $Row[0] }) ) {
            # create array if there are multiple attributes
            my $Value = $Data{ $Row[0] };
            $Data{ $Row[0] } = [
                $Value
            ];
        }
        if ( IsArrayRefWithData($Data{ $Row[0] }) ) {
            push @{$Data{ $Row[0] }}, $Row[1];
        }
        else {
            $Data{ $Row[0] } = $Row[1];
        }
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $Self->{CachePrefix} . $Param{UserID},
        Value => \%Data,
    );

    return %Data;
}

sub DeletePreferences {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $DBObject = $Kernel::OM->Get('DB');

    my $SQL = "DELETE FROM $Self->{PreferencesTable} WHERE $Self->{PreferencesTableUserID} = ?";
    my @Bind = (
        \$Param{UserID}
    );

    if ( $Param{Key} ) {
        push @Bind, \$Param{Key};
        $SQL .= " AND $Self->{PreferencesTableKey} = ?";
    }

    # delete old data
    return if !$DBObject->Do(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # TODO: find another solution to delete caches depending on user language
    # trigger special cache delete for cached transaltions/localisation
    if ( $Param{Key} eq 'UserLanguage' ) {
        $Kernel::OM->Get('Cache')->CleanUp(
            Type => 'UserLanguage',
        );
    }

    # TODO: find another solution to delete caches depending on 'MyQueues'
    # trigger special cache delete for cached ticket searches
    if ( $Param{Key} eq 'MyQueues' ) {
        $Kernel::OM->Get('Cache')->CleanUp(
            Type => 'ObjectSearch_Ticket',
        );
    }

    return 1;
}

sub SearchPreferences {
    my ( $Self, %Param ) = @_;

    my $Key   = $Param{Key}   || '';
    my $Value = $Param{Value} // '';

    my $DBObject = $Kernel::OM->Get('DB');

    my $Lower = '';
    if ( $DBObject->GetDatabaseFunction('CaseSensitive') ) {
        $Lower = 'LOWER';
    }

    my $SQL = "
        SELECT $Self->{PreferencesTableUserID}, $Self->{PreferencesTableValue}
        FROM $Self->{PreferencesTable}
        WHERE $Self->{PreferencesTableKey} = ?";
    my @Bind = ( \$Key );

    if ( $Value ne '' ) {
        $SQL .= " AND $Lower($Self->{PreferencesTableValue}) LIKE $Lower(?)";
        push @Bind, \$Value;
    }

    # get preferences
    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => $Param{Limit},
    );

    # fetch the result
    my %UserID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $UserID{ $Row[0] } = $Row[1];
    }

    return %UserID;
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
