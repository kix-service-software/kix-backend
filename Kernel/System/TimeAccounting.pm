# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::TimeAccounting;

use strict;
use warnings;

use base qw(
    Kernel::System::EventHandler
);

our @ObjectDependencies = qw(
    ClientRegistration
    Cache
    Contact
    DB
    Log
    User
    Valid
    Ticket
);

use Kernel::System::VariableCheck qw(:all);


=head1 NAME

Kernel::System::TimeAccounting - time accounting lib

=head1 SYNOPSIS

All time accounting functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TimeAccountingObject = $Kernel::OM->Get('TimeAccounting');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=on;
    $Self->{Debug} = $Param{Debug} || 0;

    $Self->{CacheType} = 'TimeAccounting';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    # init of event handler
    $Self->EventHandlerInit(
        Config => 'TimeAccounting::EventModulePost',
    );

    return $Self;
}

=item TimeAccountingMoveTo()

moves time accounting from a ticket to a other ticket

    my $Success = $TimeAccountingbject->TimeAccountingMoveTo(
        NewTicketID => 123,   # required
        UserID      => 123,   # required
        TicketID    => 123,   # required, if all accounted times on the ticket are to be moved
                              # If the ArticleID is given, only the accounted time of article linked to the ticket will be moved
        ArticleID   => 123    # required, if you only want to postpone the accounted time for an article
    );

=cut

sub TimeAccountingMoveTo {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (
        qw(
            NewTicketID UserID
        )
    ) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
                Silent   => $Param{Silent}
            );
            return;
        }
    }

    if (
        !$Param{ArticleID}
        && !$Param{TicketID}
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need TicketID or ArticleID!",
            Silent   => $Param{Silent}
        );
        return;
    }

    my @WHERE;
    my $SQL = <<'END';
UPDATE time_accounting
SET
    ticket_id = ?,
    change_time = current_timestamp,
    change_by = ?
WHERE
END
    my @Bind = ( \$Param{NewTicketID}, \$Param{UserID} );

    if ( $Param{ArticleID} ) {
        push( @WHERE, 'article_id = ?' );
        push( @Bind, \$Param{ArticleID} );
    }

    if ( $Param{TicketID} ) {
        push( @WHERE, 'ticket_id = ?' );
        push( @Bind, \$Param{TicketID} );
    }

    $SQL .= q{ } . join( ' AND ', @WHERE );

    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    return 1;
}

=item TimeAccountingTotal()

gets the total accounted time of the ticket or article

    my $TotalTime = $TimeAccountingbject->TimeAccountingTotal(
        TicketID  => 123,  # required, or ArticleID
        ArticleID => 123,  # required, or TicketID
    );

=cut

sub TimeAccountingTotal {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if (
        !$Param{TicketID}
        && !$Param{ArticleID}
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need TicketID or ArticleID!'
        );
        return;
    }

    my @Bind;
    my $SQL = <<'END';
SELECT SUM(time_unit)
FROM time_accounting
WHERE
END

    my @WHERE;
    if ( $Param{ArticleID} ) {
        push( @WHERE, 'article_id = ?' );
        push( @Bind, \$Param{ArticleID} );
    }

    if ( $Param{TicketID} ) {
        push( @WHERE, 'ticket_id = ?' );
        push( @Bind, \$Param{TicketID} );
    }

    $SQL .= q{ } . join( ' AND ', @WHERE );

    # db query
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    my $AccountedTime = 0;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        if (@Row && $Row[0]) {
            $Row[0] =~ s/,/./g;
            $AccountedTime = $AccountedTime + (0 + $Row[0]);
        }
    }

    return $AccountedTime;
}

=item TimeAccountingCreate()

creates a new time accounting

    my $ID = $TimeAccountingbject->TimeAccountingCreate(
        TicketID           => 123,                      # required
        ArticleID          => 123,                      # optional
        TimeUnit           => 123,                      # required
        ExecutingContactID => 123,                      # required
        StartTime          => '2026-01-01 12:00:00',    # required
        Description        => 'some text',              # optional
        IsInvoiced         => 1                         # optional, 0|1 default is 0
        UserID             => 123,                      # required
    );

=cut

sub TimeAccountingCreate {
    my ( $Self, %Param ) = @_;

    my $Data = $Self->_CheckParams(
        %Param,
        Type => 'Create'
    );
    return if !IsHashRefWithData($Data);

    $Data->{TimeUnit} = $Self->_TimeUnitCalculate(
        Value => $Data->{TimeUnit}
    );

    my %Condition = $Self->_PrepareCondition(
        %{$Data},
        Type => 'Create'
    );

    my $Columns = join( q{,}, @{$Condition{Columns}} );
    my $Values  = join( q{,}, @{$Condition{Values}} );

    # db insert
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => <<"END",
INSERT INTO time_accounting
    ( $Columns )
VALUES ( $Values )
END
        Bind => $Condition{Bind},
    );

    my $TimeAccountingID = $Self->_GetLastInsertID(
        %{$Data}
    );

    return if !$TimeAccountingID;

    $Self->ClearCache();

    # trigger event
    $Self->EventHandler(
        Event => 'TimeAccountingCreate',
        Data  => {
            TicketID         => $Data->{TicketID},
            ArticleID        => $Data->{ArticleID},
            TimeUnit         => $Data->{TimeUnit},
            TimeAccountingID => $TimeAccountingID
        },
        UserID => $Data->{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'Update',
        Namespace => 'Ticket' . ($Data->{ArticleID} ? '.Article.AccountedTime' : '.AccountedTime'),
        ObjectID  => $Data->{TicketID} . ($Data->{ArticleID} ? '::' . $Data->{ArticleID} : ''),
    );

    return $TimeAccountingID;
}

=item TimeAccountingUpdate()

updates a existing time accounting

    my $ID = $TimeAccountingbject->TimeAccountingUpdate(
        TicketID           => 123,                      # required
        ArticleID          => 123,                      # optional
        TimeUnit           => 123,                      # optional
        ExecutingContactID => 123,                      # optional
        StartTime          => '2026-01-01 12:00:00',    # optional
        Description        => 'some text',              # optional
        IsInvoiced         => 1                         # optional, 0|1 default is 0
        UserID             => 123,                      # required
    );

=cut

sub TimeAccountingUpdate {
    my ( $Self, %Param ) = @_;

    my $Data = $Self->_CheckParams(
        %Param,
        Type => 'Update'
    );
    return if !IsHashRefWithData($Data);

    $Data->{TimeUnit} = $Self->_TimeUnitCalculate(
        Value => $Data->{TimeUnit}
    );

    my %Condition = $Self->_PrepareCondition(
        %{$Data},
        Type => 'Update'
    );

    if ( $Data->{TimeAccountingID} ) {
        my %TimeAccounting = $Self->TimeAccountingGet(
            TimeAccountingID => $Data->{TimeAccountingID}
        );
        if ( !%TimeAccounting ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No time accounting were found to update!",
                Silent   => $Data->{Silent}
            );
            return;
        }
        $Data->{OldTimeUnit} = $TimeAccounting{TimeUnit};
        $Data->{TicketID}    = $TimeAccounting{TicketID};
    }

    my $Columns = join( q{,}, @{$Condition{Columns}} );
    my $Where   = join( ' AND ', @{$Condition{Where}} );
    my @Bind    = (
        @{$Condition{Bind}},
        @{$Condition{WBind}}
    );
    # db insert
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => <<"END",
UPDATE time_accounting
    SET $Columns
WHERE $Where
END
        Bind => \@Bind,
    );

    $Self->ClearCache();

    # trigger event
    $Self->EventHandler(
        Event => 'TimeAccountingUpdate',
        Data  => {
            Data             => $Data,
            TicketID         => $Data->{TicketID},
            ArticleID        => $Data->{ArticleID},
            TimeUnit         => $Data->{TimeUnit},
            OldTimeUnit      => $Data->{OldTimeUnit},
            TimeAccountingID => $Data->{TimeAccountingID}
        },
        UserID => $Data->{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'Update',
        Namespace => 'Ticket' . ($Data->{ArticleID} ? '.Article.AccountedTime' : '.AccountedTime'),
        ObjectID  => $Data->{TicketID} . ($Data->{ArticleID} ? '::' . $Data->{ArticleID} : ''),
    );

    return $Data->{TimeAccountingID};
}

=item TimeAccountingDelete()

delete a existing time accounting

    my $ID = $TimeAccountingbject->TimeAccountingDelete(
        TimeAccountingID => 123,   # required, or TicketID|ArticleID
        TicketID         => 123,   # required, or TimeAccountingID|ArticleID
        ArticleID        => 123,   # required, or TimeAccountingID|TicketID
        UserID           => 123,   # required
    );

=cut
sub TimeAccountingDelete {
    my ( $Self, %Param ) = @_;

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Needed UserID",
            Silent   => $Param{Silent}
        );
        return;
    }

    if (
        !$Param{TimeAccountingID}
        && !$Param{TicketID}
        && !$Param{ArticleID}
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need TimeAccountingID or TicketID or ArticleID!",
            Silent   => $Param{Silent}
        );
        return;
    }

    if ( $Param{TimeAccountingID} ) {
        my %TimeAccounting = $Self->TimeAccountingGet(
            TimeAccountingID => $Param{TimeAccountingID}
        );
        if ( !%TimeAccounting ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No time accounting were found to delete!",
                Silent   => $Param{Silent}
            );
            return;
        }
        $Param{TicketID}    = $TimeAccounting{TicketID};
        $Param{OldTimeUnit} = $TimeAccounting{TimeUnit};
    }

    my @Where;
    my @Bind;
    my $SQL = <<'END';
DELETE FROM time_accounting
WHERE
END

    if ( $Param{TimeAccountingID} ) {
        push( @Where, ' id = ?' );
        push( @Bind, \$Param{TimeAccountingID} );
    }
    else {
        if ( $Param{TicketID} ) {
            push( @Where, ' ticket_id = ?' );
            push( @Bind, \$Param{TicketID} );
        }
        if ( $Param{ArticleID} ) {
            push( @Where, ' article_id = ?' );
            push( @Bind, \$Param{ArticleID} );
        }
    }

    $SQL .= join( ' AND', @Where );

    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => $SQL,
        Bind => \@Bind
    );

    # trigger event
    $Self->EventHandler(
        Event => 'TimeAccountingDelete',
        Data  => {
            TicketID         => $Param{TicketID},
            ArticleID        => $Param{ArticleID},
            OldTimeUnit      => $Param{OldTimeUnit},
            TimeAccountingID => $Param{TimeAccountingID}
        },
        UserID => $Param{UserID},
    );

    return 1;
}

=item TimeAccountingExists()

returns a existing time accounting ID

    my $TimeAccountingID = $TimeAccountingObject->TimeAccountingExists(
        TimeAccountingID => 123,     # optional
        TicketID         => 123,     # optional
        ArticleID        => 123,     # optional
        UserID           => 132      # required
    );
=cut

sub TimeAccountingExists {
    my ( $Self, %Param ) = @_;

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need UserID",
            Silent   => $Param{Silent}
        );
        return;
    }

    if (
        !$Param{TimeAccountingID}
        && (
            !$Param{TicketID}
            || (
                defined $Param{ArticleID}
                && !$Param{ArticleID}
            )
        )
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need TimeAccountingID or TicketID and ArticleID!",
            Silent   => $Param{Silent}
        );
        return;
    }

    my @Where;
    my @Bind;
    my $SQL = <<'END';
SELECT id
FROM time_accounting
WHERE
END
    if ( $Param{TimeAccountingID} ) {
        push( @Where, ' id = ?');
        push( @Bind, \$Param{TimeAccountingID} );
    }
    else {
        if ( !$Param{ArticleID} ) {
            push( @Where, ' ticket_id = ?', ' article_id IS NULL');
            push( @Bind, \$Param{TicketID} );
        }
        else {
            push( @Where, ' ticket_id = ?', ' article_id = ?');
            push( @Bind, \$Param{TicketID}, \$Param{ArticleID} );
        }

    }

    $SQL .= join( ' AND', @Where );
    $SQL .= ' ORDER BY id DESC';

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => 1
    );

    # fetch the result
    my $ID;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $ID = $Row[0];
    }

    return $ID;
}


=item TimeAccountingGet()

returns a existing time accounting

    my %TimeAccounting = $TimeAccountingObject->TimeAccountingGet(
        TimeAccountingID => 123,   # required
    );

    %TimeAccounting = (
        ID                 => 123,
        TicketID           => 123,
        ArticleID          => 123,
        TimeUnit           => 12,
        ExecutingContactID => 123,
        Description        => 'some text',
        StartTime          => '01-01-2026',
        IsInvoiced         => 0,
        CreateTime         => '2024-09-03 11:15:00'
        CreateBy           => 123,
        ChangeTime         => '2024-09-03 11:15:15',
        ChangeBy           => 123
    );

=cut

sub TimeAccountingGet {
    my ( $Self, %Param ) = @_;

    if ( !$Param{TimeAccountingID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need TimeAccountingID!',
            Silent   => $Param{Silent}
        );
        return;
    }

    # check cache
    my $CacheKey = 'TimeAccountingGet::' . $Param{TimeAccountingID};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => <<'END',
SELECT *
FROM time_accounting
WHERE id = ?
END
        Bind => [ \$Param{TimeAccountingID} ],
    );

    my @Columns = $Kernel::OM->Get('DB')->GetColumnNames();
    for my $Column ( @Columns ) {
        my @Names = split(/_/sm, $Column);
        for my $Name ( @Names) {
            $Name = ( $Name =~ /^(?:ta|id)$/sm ) ? uc($Name) : ucfirst($Name);
        }

        $Column = join( q{}, @Names);
    }

    # fetch the result
    my %TimeAccounting;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        my $Index = 0;
        COLUMN:
        for my $Column ( @Columns ) {
            $TimeAccounting{ $Column } = $Row[$Index];
            $Index++;
        }
    }

    # no data found...
    if ( !%TimeAccounting ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "TimeAccounting with TimeAccountingID $Param{TimeAccountingID} not found!",
            Silent   => $Param{Silent}
        );
        return;
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%TimeAccounting,
    );

    return %TimeAccounting;
}

=item TimeAccountingUpdatable()

checks for updatable time accounting

    my $Success = $TimeAccountingObject->TimeAccountingUpdatable(
        TimeAccountingID => 123,      # required
    );

=cut

sub TimeAccountingUpdatable {
    my ( $Self, %Param ) = @_;

    for my $Needed ( qw( TimeAccountingID ) ) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed",
                Silent   => $Param{Silent}
            );
            return;
        }
    }

    my $IsInvoiced = 0;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => <<'END',
SELECT id
FROM time_accounting
WHERE id = ? AND is_invoiced = ?
END
        Bind => [ \$Param{TimeAccountingID}, \$IsInvoiced ],
    );

    # fetch the result
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        return 1;
    }

    $Kernel::OM->Get('Log')->Log(
        Priority => 'error',
        Message  => "Time accounting ($Param{TimeAccountingID}) is not updatable!",
        Silent   => $Param{Silent}
    );

    return 0;
}

=item ClearCache()

clean up the cache of TimeAccouning

=cut

sub ClearCache {
    my ( $Self, %Param ) = @_;

    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    $Kernel::OM->Get('Cache')->CleanUp(
        Type => 'ObjectSearch_TimeAccounting'
    );

    return 1;
}

=item _CheckParams()

Checks the requirements and specified parameters

=cut

sub _CheckParams {
    my ( $Self, %Param ) = @_;

    my $Type = $Param{Type} || 'Create';
    my $Data = $Kernel::OM->Get('Storable')->Clone( Data => \%Param );

    if ( $Type eq 'Create' ) {

        # check needed stuff
        for my $Needed (
            qw(
                TicketID TimeUnit UserID
                StartTime IsInvoiced ExecutingContactID
            )
        ) {
            if ( !defined $Data->{$Needed} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!",
                    Silent   => $Data->{Silent}
                );
                return;
            }
        }

        if ( $Data->{ArticleID} ) {
            if (
                $Self->TimeAccountingExists(
                    TicketID  => $Data->{TicketID},
                    ArticleID => $Data->{ArticleID},
                    UserID    => $Data->{UserID},
                    Silent    => $Param{Silent}
                )
            ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "TimeAccounting for TicketID ($Data->{TicketID}) and ArticleID ($Data->{ArticleID}) already exists!",
                    Silent   => $Data->{Silent}
                );
                return;
            }
        }
    }
    # Only article are updated, or if a TimeAccountingID exists
    elsif ( $Type eq 'Update' ) {

        for my $Needed (
            qw(
                TimeUnit UserID
            )
        ) {
            if ( !defined $Data->{$Needed} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!",
                    Silent   => $Data->{Silent}
                );
                return;
            }
        }

        if (
            !$Data->{TimeAccountingID}
            && (
                !$Data->{TicketID}
                || !$Data->{ArticleID}
            )
        ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need TimeAccountingID or TicketID and ArticleID!",
                Silent   => $Data->{Silent}
            );
            return;
        }

        my $TimeAccountingID = $Self->TimeAccountingExists(
            TimeAccountingID => $Data->{TimeAccountingID},
            TicketID         => $Data->{TicketID},
            ArticleID        => $Data->{ArticleID},
            UserID           => $Data->{UserID},
            Silent           => $Param{Silent}
        );

        if ( !$TimeAccountingID ) {
            my $ErrorMsg = "TimeAccounting with TimeAccountingID ($Data->{TimeAccountingID})";
            if ( $Data->{TicketID} ) {
                $ErrorMsg = "TimeAccounting with TicketID ($Data->{TicketID})";
                if ( $Data->{ArticleID} ) {
                    $ErrorMsg .= " and ArticleID ($Data->{ArticleID})";
                }
            }
            $ErrorMsg .= ' not found!';

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => $ErrorMsg,
                Silent   => $Data->{Silent}
            );
            return;
        }
        elsif (
            $Data->{TimeAccountingID}
            && $TimeAccountingID ne $Data->{TimeAccountingID}
        ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "TimeAccounting with TicketID ($Data->{TicketID}) and ArticleID ($Data->{ArticleID}) already exists!",
                Silent   => $Data->{Silent}
            );
            return;
        }

        # sets time accounting id if exists
        $Data->{TimeAccountingID} = $TimeAccountingID if !$Data->{TimeAccountingID};

        return if !$Self->TimeAccountingUpdatable(
            TimeAccountingID => $Data->{TimeAccountingID},
            Silent           => $Param{Silent}
        );
    }

    # checks of existing contact
    if (
        $Data->{ExecutingContactID}
        && !$Kernel::OM->Get('Contact')->ContactLookup(
            ID      => $Data->{ExecutingContactID},
            Silent  => $Param{Silent}
        )
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Contact (' . $Data->{ExecutingContactID} . ') does not exist!',
            Silent   => $Data->{Silent}
        );
        return;
    }

    return if !$Self->_CheckTimeUnit(%Param);

    return $Data;
}

sub _CheckTimeUnit {
    my ( $Self, %Param ) = @_;

    if ( $Param{TimeUnit} ) {
        # check some wrong formats
        $Param{TimeUnit} =~ s/,/\./g;
        $Param{TimeUnit} =~ s/ //g;
        $Param{TimeUnit} =~ s/^(-?\d{1,10}\.\d\d).+?$/$1/g;
        chomp $Param{TimeUnit};

        if ( !IsNumber($Param{TimeUnit}) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "TimeUnit is not a number!",
                Silent   => $Param{Silent}
            );
            return;
        }

        if (
            $Param{TimeUnit} >= 86_400 ||
            $Param{TimeUnit} <= -86_400
        ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "TimeUnit has to be between -86400 and 86400!",
                Silent   => $Param{Silent}
            );
            return;
        }
    }

    return 1
}

=item _PrepareCondition()

Set the parameters for the SQL statement

=cut

sub _PrepareCondition {
    my ( $Self, %Param ) = @_;

    my $Type = $Param{Type} || 'Create';
    my $Columns;
    my $Values;
    my $Where;
    my @Bind;
    my @WBind;

    # db quote
    $Param{TimeUnit} = $Kernel::OM->Get('DB')->Quote( $Param{TimeUnit}, 'Number' );

    my %AvailableCols = (
        TicketID           => 'ticket_id',
        ArticleID          => 'article_id',
        TimeUnit           => 'time_unit',
        StartTime          => 'start_time',
        ExecutingContactID => 'executing_contact_id',
        IsInvoiced         => 'is_invoiced',
        Description        => 'description'
    );

    for my $Key ( sort keys %AvailableCols ) {
        next if !defined $Param{$Key};
        if ( $Type eq 'Create' ) {
            push( @{$Columns}, $AvailableCols{$Key} );
            push( @{$Values}, q{?} );
            push( @Bind, \$Param{$Key} );
        }
        elsif ( $Type eq 'Update' ) {
            push( @{$Columns}, $AvailableCols{$Key} . ' = ?' );
            push( @Bind, \$Param{$Key} );
        }
    }

    if ( $Type eq 'Create' ) {
        push( @{$Columns}, 'create_by', 'create_time', 'change_by', 'change_time' );
        push( @{$Values}, q{?}, 'current_timestamp', q{?}, 'current_timestamp' );
        push( @Bind, \$Param{UserID}, \$Param{UserID} );
    }
    elsif ( $Type eq 'Update' ) {
        push( @{$Columns}, 'change_by = ?', 'change_time = current_timestamp' );
        push( @Bind, \$Param{UserID} );

        if (
            defined $Param{TimeAccountingID}
            && $Param{TimeAccountingID}
        ) {
            push( @{$Where} , 'id = ?' );
            push( @WBind, \$Param{TimeAccountingID} );
        }
        else {
            for my $Key ( qw( TicketID ArticleID UserID ) ) {
                next if !$Param{$Key} ;
                push( @{$Where} , "$AvailableCols{$Key} = ?" );
                push( @WBind, \$Param{$Key} );
            }
        }
    }

    return (
        Columns => $Columns,
        Values  => $Values,
        Bind    => \@Bind,
        Where   => $Where,
        WBind   => \@WBind
    );
}

=item _TimeUnitCalculate()

calculate time unit

=cut

sub _TimeUnitCalculate {
    my ( $Self, %Param ) = @_;

    $Param{Value} =~ s/,/\./g;
    $Param{Value} =~ s/ //g;
    $Param{Value} =~ s/^(-?\d{1,10}\.\d\d).+?$/$1/g;
    chomp $Param{Value};

    return $Param{Value};
}

=item _GetLastInsertID()

Returns the most recently created ID of the accounting time entry

=cut
sub _GetLastInsertID {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (
        qw( TicketID TimeUnit UserID )
    ) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
                Silent   => $Param{Silent}
            );
            return;
        }
    }

    # sql query
    my $SQL = <<'END';
SELECT id
FROM time_accounting
WHERE ticket_id = ? AND time_unit = ? AND create_by = ?
END
    my @Bind = ( \$Param{TicketID}, \$Param{TimeUnit}, \$Param{UserID} );

    if ( $Param{ArticleID} ) {
        $SQL .= ' AND article_id = ?';
        push( @Bind, \$Param{ArticleID} );
    }
    else {
        $SQL .= ' AND article_id IS NULL';
    }

    $SQL .= ' ORDER BY id DESC';

    # start query
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => 1,
    );

    my $TimeAccountingID;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $TimeAccountingID = $Row[0];
    }

    return $TimeAccountingID;
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