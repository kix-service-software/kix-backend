# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::Ticket::TicketSearch::Database - ticket search lib

=head1 SYNOPSIS

All ticket search functions.

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $SearchBackendObject = $Kernel::OM->Get('Kernel::System::Ticket::TicketSearch::Database');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=on;
    $Self->{Debug} = $Param{Debug} || 0;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');
    
    my $Home = $ConfigObject->Get('Home');

    # load modules
    my @Modules;

    # load configs from registered custom packages
    my @CustomPackages = $Kernel::OM->Get('Kernel::System::KIXUtils')->GetRegisteredCustomPackages(
        Result => 'ARRAY',
    );

    # add our home
    push(@CustomPackages, '');

    for my $Dir (@CustomPackages) {
        my $Directory = $Home.'/'.$Dir.'/Kernel/System/Ticket/TicketSearch/Database';
        $Directory =~ s'\s'\\s'g;
        if ( -e "$Directory" ) {
            my @Files = $MainObject->DirectoryRead(
                Directory => $Directory,
                Filter    => "*.pm",
                Recursive => 1,
            );
            foreach my $File ( @Files ) {
                $File =~ s/$Directory\///g;
                $File =~ s/\//::/g;
                $File =~ s/\.pm$//g;
                push(@Modules, $File);
            }
        }
    }

    foreach my $Module ( sort @Modules ) {
        next if ( $Module =~ /^Common$/g);
        
        $Module = 'Kernel::System::Ticket::TicketSearch::Database::'.$Module;

        my $Object = $Kernel::OM->Get($Module);
        if ( !$Object ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Unable to create database search backend object $Module !",
            );
            return;
        }

        # register module for each supported attribute
        foreach my $Attribute ( $Object->GetSupportedAttributes() ) {
            $Self->{AttributeModules}->{$Attribute} = $Object;
        }        
    }

    return $Self;
}

=item TicketSearch()

To find tickets in your system.

    my @TicketIDs = $TicketObject->TicketSearch(
        # result (required)
        Result => 'ARRAY' || 'HASH' || 'COUNT',

        # result limit
        Limit => 100,

        # Use TicketSearch as a ticket filter on a single ticket,
        # or a predefined ticket list
        TicketID     => 1234,
        TicketID     => [1234, 1235],

        # ticket number (optional) as STRING or as ARRAYREF
        TicketNumber => '%123546%',
        TicketNumber => ['%123546%', '%123666%'],

        # ticket title (optional) as STRING or as ARRAYREF
        Title => '%SomeText%',
        Title => ['%SomeTest1%', '%SomeTest2%'],

        Queues   => ['system queue', 'other queue'],
        QueueIDs => [1, 42, 512],

        # use also sub queues of Queue|Queues in search
        UseSubQueues => 0,

        # You can use types like normal, ...
        Types   => ['normal', 'change', 'incident'],
        TypeIDs => [3, 4],

        # You can use states like new, open, pending reminder, ...
        States   => ['new', 'open'],
        StateIDs => [3, 4],

        # (Open|Closed) tickets for all closed or open tickets.
        StateType => 'Open',

        # You also can use real state types like new, open, closed,
        # pending reminder, pending auto, removed and merged.
        StateType    => ['open', 'new'],
        StateTypeIDs => [1, 2, 3],

        Priorities  => ['1 very low', '2 low', '3 normal'],
        PriorityIDs => [1, 2, 3],

        Services   => ['Service A', 'Service B'],
        ServiceIDs => [1, 2, 3],

        SLAs   => ['SLA A', 'SLA B'],
        SLAIDs => [1, 2, 3],

        Locks   => ['unlock'],
        LockIDs => [1, 2, 3],

        OwnerIDs => [1, 12, 455, 32]

        ResponsibleIDs => [1, 12, 455, 32]

        WatchUserIDs => [1, 12, 455, 32]

        # CustomerID (optional) as STRING or as ARRAYREF
        CustomerID => '123',
        CustomerID => ['123', 'ABC'],

        # CustomerIDRaw (optional) as STRING or as ARRAYREF
        # CustomerID without QueryCondition checking
        #The raw value will be used if is set this parameter
        CustomerIDRaw => '123 + 345',
        CustomerIDRaw => ['123', 'ABC','123 && 456','ABC % efg'],

        # CustomerUserLogin (optional) as STRING as ARRAYREF
        CustomerUserLogin => 'uid123',
        CustomerUserLogin => ['uid123', 'uid777'],

        # CustomerUserLoginRaw (optional) as STRING as ARRAYREF
        #The raw value will be used if is set this parameter
        CustomerUserLoginRaw => 'uid',
        CustomerUserLoginRaw => 'uid + 123',
        CustomerUserLoginRaw => ['uid  -  123', 'uid # 777 + 321'],

        # create ticket properties (optional)
        CreatedUserIDs     => [1, 12, 455, 32]
        CreatedTypes       => ['normal', 'change', 'incident'],
        CreatedTypeIDs     => [1, 2, 3],
        CreatedPriorities  => ['1 very low', '2 low', '3 normal'],
        CreatedPriorityIDs => [1, 2, 3],
        CreatedStates      => ['new', 'open'],
        CreatedStateIDs    => [3, 4],
        CreatedQueues      => ['system queue', 'other queue'],
        CreatedQueueIDs    => [1, 42, 512],

        # DynamicFields
        #   At least one operator must be specified. Operators will be connected with AND,
        #       values in an operator with OR.
        #   You can also pass more than one argument to an operator: ['value1', 'value2']
        DynamicField_FieldNameX => {
            Equals            => 123,
            Like              => 'value*',                # "equals" operator with wildcard support
            GreaterThan       => '2001-01-01 01:01:01',
            GreaterThanEquals => '2001-01-01 01:01:01',
            SmallerThan       => '2002-02-02 02:02:02',
            SmallerThanEquals => '2002-02-02 02:02:02',
        }

        # User ID for searching tickets by ticket flags (defaults to UserID)
        TicketFlagUserID => 1,

        # search for ticket flags
        TicketFlag => {
            Seen => 1,
        }

        # search for ticket flag that is absent, or a different value than the
        # one given:
        NotTicketFlag => {
            Seen => 1,
        },

        # User ID for searching tickets by article flags (defaults to UserID)
        ArticleFlagUserID => 1,


        # search for tickets by the presence of flags on articles
        ArticleFlag => {
            Important => 1,
        },

        # article stuff (optional)
        From    => '%spam@example.com%',
        To      => '%service@example.com%',
        Cc      => '%client@example.com%',
        Subject => '%VIRUS 32%',
        Body    => '%VIRUS 32%',

        # attachment stuff (optional, applies only for ArticleStorageDB)
        AttachmentName => '%anyfile.txt%',

        # use full article text index if configured (optional, default off)
        FullTextIndex => 1,

        # article content search (AND or OR for From, To, Cc, Subject and Body) (optional)
        ContentSearch => 'AND',

        # article content search prefix (for From, To, Cc, Subject and Body) (optional)
        ContentSearchPrefix => '*',

        # article content search suffix (for From, To, Cc, Subject and Body) (optional)
        ContentSearchSuffix => '*',

        # content conditions for From,To,Cc,Subject,Body
        # Title,CustomerID and CustomerUserLogin (all optional)
        ConditionInline => 1,

        # articles created more than 60 minutes ago (article older than 60 minutes) (optional)
        ArticleCreateTimeOlderMinutes => 60,
        # articles created less than 120 minutes ago (article newer than 60 minutes) (optional)
        ArticleCreateTimeNewerMinutes => 120,

        # articles with create time after ... (article newer than this date) (optional)
        ArticleCreateTimeNewerDate => '2006-01-09 00:00:01',
        # articles with created time before ... (article older than this date) (optional)
        ArticleCreateTimeOlderDate => '2006-01-19 23:59:59',

        # tickets created more than 60 minutes ago (ticket older than 60 minutes)  (optional)
        TicketCreateTimeOlderMinutes => 60,
        # tickets created less than 120 minutes ago (ticket newer than 120 minutes) (optional)
        TicketCreateTimeNewerMinutes => 120,

        # tickets with create time after ... (ticket newer than this date) (optional)
        TicketCreateTimeNewerDate => '2006-01-09 00:00:01',
        # tickets with created time before ... (ticket older than this date) (optional)
        TicketCreateTimeOlderDate => '2006-01-19 23:59:59',

        # ticket history entries that created more than 60 minutes ago (optional)
        TicketChangeTimeOlderMinutes => 60,
        # ticket history entries that created less than 120 minutes ago (optional)
        TicketChangeTimeNewerMinutes => 120,

        # tickets changed more than 60 minutes ago (optional)
        TicketLastChangeTimeOlderMinutes => 60,
        # tickets changed less than 120 minutes ago (optional)
        TicketLastChangeTimeNewerMinutes => 120,

        # tickets with changed time after ... (ticket changed newer than this date) (optional)
        TicketLastChangeTimeNewerDate => '2006-01-09 00:00:01',
        # tickets with changed time before ... (ticket changed older than this date) (optional)
        TicketLastChangeTimeOlderDate => '2006-01-19 23:59:59',

        # ticket history entry create time after ... (ticket history entries newer than this date) (optional)
        TicketChangeTimeNewerDate => '2006-01-09 00:00:01',
        # ticket history entry create time before ... (ticket history entries older than this date) (optional)
        TicketChangeTimeOlderDate => '2006-01-19 23:59:59',

        # tickets closed more than 60 minutes ago (optional)
        TicketCloseTimeOlderMinutes => 60,
        # tickets closed less than 120 minutes ago (optional)
        TicketCloseTimeNewerMinutes => 120,

        # tickets with closed time after ... (ticket closed newer than this date) (optional)
        TicketCloseTimeNewerDate => '2006-01-09 00:00:01',
        # tickets with closed time before ... (ticket closed older than this date) (optional)
        TicketCloseTimeOlderDate => '2006-01-19 23:59:59',

        # tickets with pending time of more than 60 minutes ago (optional)
        TicketPendingTimeOlderMinutes => 60,
        # tickets with pending time of less than 120 minutes ago (optional)
        TicketPendingTimeNewerMinutes => 120,

        # tickets with pending time after ... (optional)
        TicketPendingTimeNewerDate => '2006-01-09 00:00:01',
        # tickets with pending time before ... (optional)
        TicketPendingTimeOlderDate => '2006-01-19 23:59:59',

        # you can use all following escalation options with this four different ways of escalations
        # TicketEscalationTime...
        # TicketEscalationUpdateTime...
        # TicketEscalationResponseTime...
        # TicketEscalationSolutionTime...

        # ticket escalation time of more than 60 minutes ago (optional)
        TicketEscalationTimeOlderMinutes => -60,
        # ticket escalation time of less than 120 minutes ago (optional)
        TicketEscalationTimeNewerMinutes => -120,

        # tickets with escalation time after ... (optional)
        TicketEscalationTimeNewerDate => '2006-01-09 00:00:01',
        # tickets with escalation time before ... (optional)
        TicketEscalationTimeOlderDate => '2006-01-09 23:59:59',

        # search in archive (optional)
        # if archiving is on, if not specified the search processes unarchived only
        # 'y' searches archived tickets, 'n' searches unarchived tickets
        # if specified together all tickets are searched
        ArchiveFlags => ['y', 'n'],

        # OrderBy and SortBy (optional)
        OrderBy => 'Down',  # Down|Up
        SortBy  => 'Age',   # Created|Owner|Responsible|CustomerID|State|TicketNumber|Queue|Priority|Age|Type|Lock
                            # Changed|Title|Service|SLA|PendingTime|EscalationTime
                            # EscalationUpdateTime|EscalationResponseTime|EscalationSolutionTime
                            # DynamicField_FieldNameX

        # OrderBy and SortBy as ARRAY for sub sorting (optional)
        OrderBy => ['Down', 'Up'],
        SortBy  => ['Priority', 'Age'],

        # user search (UserID is required)
        UserID     => 123,
        Permission => 'ro' || 'rw',

        # customer search (CustomerUserID is required)
        CustomerUserID => 123,
        Permission     => 'ro' || 'rw',

        # CacheTTL, cache search result in seconds (optional)
        CacheTTL => 60 * 15,
    );

Returns:

Result: 'ARRAY'

    @TicketIDs = ( 1, 2, 3 );

Result: 'HASH'

    %TicketIDs = (
        1 => '2010102700001',
        2 => '2010102700002',
        3 => '2010102700003',
    );

Result: 'COUNT'

    $TicketIDs = 123;

=cut

sub TicketSearch {
    my ( $Self, %Param ) = @_;

    # the parts or SQL is comprised of
    my @SQLPartsDef = (
        {
            Name   => 'SQLAttrs',
            JoinBy => ', ',
        },
        {
            Name   => 'SQLFrom',
            JoinBy => ', ',
        },
        {
            Name   => 'SQLJoin',
            JoinBy => ' ',
        },
        {
            Name   => 'SQLWhere',
            JoinBy => ' AND ',
            BeginWith => 'WHERE'
        },
        {
            Name   => 'SQLOrderBy',
            JoinBy => ', ',
            BeginWith => 'ORDER BY'
        },
    );

    # empty SQL definition
    my %SQLDef = (
        SQLAttrs   => '',
        SQLFrom    => '',
        SQLJoin    => '',
        SQLWhere   => '',
        SQLOrderBy => '',
    );

    # check required params
    if ( !$Param{UserID} && !$Param{UserType} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID and UserType params for permission check!',
        );
        return;
    }

    my $Result = $Param{Result} || 'HASH';

    # create basic SQL
    my $SQL;
    if ( $Result eq 'COUNT' ) {
        $SQL = 'SELECT COUNT(DISTINCT(st.id))';
    }
    else {
        $SQL = 'SELECT DISTINCT st.id, st.tn';
    }
    $SQLDef{SQLFrom}  = 'FROM ticket st INNER JOIN queue sq ON sq.id = st.queue_id';

print STDERR "here!!!\n";

    # check permission and prepare relevat part of SQL statement
    my $PermissionSQL = $Self->_CreatePermissionSQL(
        %Param
    );
    if ( !$PermissionSQL ) {
        return;                    
    }
    $SQLDef{SQLWhere} .= ' '.$PermissionSQL;

print STDERR "Here!!!\n";
    # generate SQL from attribute modules
    foreach my $Filter ( @{$Param{Filter}->{Ticket}} ) {
        my $AttributeModule;

        # check if we have a search module for this field
        if ( !$Self->{AttributeModules}->{$Filter->{Field}} ) {
            # we don't have any directly registered search module for this field, check if we have a search module matching a pattern
            foreach my $SearchableAttribute ( sort keys %{$Self->{AttributeModules}} ) {
                next if $Filter->{Field} !~ /$SearchableAttribute/g;
                $AttributeModule = $Self->{AttributeModules}->{$SearchableAttribute};
                last;
            }
        }
        else {
            $AttributeModule = $Self->{AttributeModules}->{$Filter->{Field}};
        }

        # ignore this attribute if we don't have a module for it
        if ( !$AttributeModule ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Unable to search for attribute $Filter->{Field}. Don't know how to handle it!",
            );
            return;            
        }

        # execute filter module to prepare SQL
        my $Result = $AttributeModule->Run(
            Filter => $Filter,
        );

        if ( !IsHashRefWithData($Result) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Attribute module for $Filter->{Field} returned an error!",
            );
            return;
        }

use Data::Dumper;
print STDERR "$Filter->{Field}: ".Dumper($Result);
        foreach my $SQLPart ( @SQLPartsDef ) {
            next if !IsArrayRefWithData($Result->{$SQLPart->{Name}});

            # add each entry to the corresponding SQL part
            if ($SQLDef{$SQLPart->{Name}}) {
                $SQLDef{$SQLPart->{Name}} .= $SQLPart->{JoinBy};
            }
            $SQLDef{$SQLPart->{Name}} .= (join($SQLPart->{JoinBy}, @{$Result->{$SQLPart->{Name}}}));
        }
    }

    # generate SQL
    foreach my $SQLPart ( @SQLPartsDef ) {
        next if !$SQLDef{$SQLPart->{Name}};
        $SQL .= ' '.($SQLPart->{BeginWith} || '').' '.$SQLDef{$SQLPart->{Name}};
    }
    
    print STDERR "SQL: $SQL\n";

    return ();
}

=begin Internal:

=cut

=item _InConditionGet()

internal function to create an

    AND table.column IN (values)

condition string from an array.

    my $SQLWhere = $Object->_CreatePermissionSQL(
        UserID    => ...,                    # required
        UserType  => 'Agent' | 'Customer'    # required
        Permisson => '...'                   # optional
    );

=cut

sub _CreatePermissionSQL {
    my ( $Self, %Param ) = @_;
    my $SQLWhere = '1=1';

    if ( !$Param{UserID} && !$Param{UserType} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'No user information for permission check!',
        );
        return;
    }

    # permission check and restrictions
    my %GroupList;
    if ( $Param{UserID} && $Param{UserID} != 1 && $Param{UserType} eq 'Agent' ) {

        # get users groups
        %GroupList = $Kernel::OM->Get('Kernel::System::Group')->PermissionUserGet(
            UserID => $Param{UserID},
            Type   => $Param{Permission} || 'ro',
        );

        # return if we have no permissions
        return if !%GroupList;
    }
    if ( $Param{UserID} && $Param{UserType} eq 'Customer' ) {

        my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

        # get customer groups
        %GroupList = $Kernel::OM->Get('Kernel::System::CustomerGroup')->GroupMemberList(
            UserID => $Param{UserID},
            Type   => $Param{Permission} || 'ro',
            Result => 'HASH',
        );

        # return if we have no permissions
        return if !%GroupList;

        # get all customer ids
        $SQLWhere = '(';
        my @CustomerIDs = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerIDs(
            User => $Param{UserID},
        );

        if (@CustomerIDs) {

            my $Lower = '';
            if ( $DBObject->GetDatabaseFunction('CaseSensitive') ) {
                $Lower = 'LOWER';
            }

            $SQLWhere .= "$Lower(st.customer_id) IN (";
            my $Exists = 0;

            for (@CustomerIDs) {

                if ($Exists) {
                    $SQLWhere  .= ', ';
                }
                else {
                    $Exists = 1;
                }
                $SQLWhere  .= "$Lower('" . $DBObject->Quote($_) . "')";
            }
            $SQLWhere  .= ') OR ';
        }

        # get all own tickets
        my $UserIDQuoted = $DBObject->Quote( $Param{UserID} );
        $SQLWhere  .= "st.customer_user_id = '$UserIDQuoted') ";
    }

    # add group ids to sql string
    if (%GroupList) {
        $SQLWhere = 'sq.group_id IN ('.(join(',', sort keys %GroupList)).')';
    }

    return $SQLWhere;
}

1;

=end Internal:


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
