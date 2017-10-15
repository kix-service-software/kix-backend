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

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::Ticket::TicketSearch - ticket search lib

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

    # load xml config files
    my @Files = $MainObject->DirectoryRead(
        Directory => $Home.'/Kernel/System/Ticket/TicketSearch/Database',
        Filter    => "*.pm",
        Recursive => 1,
    );

    # load configs from registered custom packages
    my @CustomPackages = $Kernel::OM->Get('Kernel::System::KIXUtils')->GetRegisteredCustomPackages(
        Result => 'ARRAY',
    );

    for my $Dir (@CustomPackages) {
        my $ConfDir = $Home.'/'.$Dir.'/Kernel/System/Ticket/TicketSearch/Database';
        $ConfDir =~ s'\s'\\s'g;
        if ( -e "$ConfDir" ) {
            my @KIXFiles = $MainObject->DirectoryRead(
                Directory => $ConfDir,
                Filter    => "*.pm",
                Recursive => 1,
            );
            push @Files, @KIXFiles;
        }
    }

    foreach my $File ( sort @Files ) {
        my $Module = 'Kernel::System::Ticket::TicketSearch::Database::'.($File =~ s/(.*?)\.pm/$1/g);
        
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
    my %SQLDef;

    # check required params
    if ( !$Param{UserID} && !$Param{UserType} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID and UserType params for permission check!',
        );
        return;
    }

    # create basic SQL
    my $SQL;
    if ( $Result eq 'COUNT' ) {
        $SQL = 'SELECT COUNT(DISTINCT(st.id))';
    }
    else {
        $SQL = 'SELECT DISTINCT st.id, st.tn';
    }
    $SQLDef{SQLFrom}  = 'FROM ticket st INNER JOIN queue sq ON sq.id = st.queue_id';
    $SQLDef{SQLWhere} = '1=1';

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

        # get customer groups
        %GroupList = $Kernel::OM->Get('Kernel::System::CustomerGroup')->GroupMemberList(
            UserID => $Param{UserID},
            Type   => $Param{Permission} || 'ro',
            Result => 'HASH',
        );

        # return if we have no permissions
        return if !%GroupList;

        # get all customer ids
        $SQLDef{SQLWhere} .= ' AND (';
        my @CustomerIDs = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerIDs(
            User => $Param{UserID},
        );

        if (@CustomerIDs) {

            my $Lower = '';
            if ( $DBObject->GetDatabaseFunction('CaseSensitive') ) {
                $Lower = 'LOWER';
            }

            $SQLExt .= "$Lower(st.customer_id) IN (";
            my $Exists = 0;

            for (@CustomerIDs) {

                if ($Exists) {
                    $SQLExt .= ', ';
                }
                else {
                    $Exists = 1;
                }
                $SQLExt .= "$Lower('" . $DBObject->Quote($_) . "')";
            }
            $SQLExt .= ') OR ';
        }

        # get all own tickets
        my $UserIDQuoted = $DBObject->Quote( $Param{UserID} );
        $SQLExt .= "st.customer_user_id = '$UserIDQuoted') ";
    }
    elsif ( $Param{UserID} && $Param{UserID} == 1 && $Param{UserType} eq 'Agent' ) {
        # no permission check needed
    }
    else {
        # this is not supported
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'No user information for permission check!',
        );
    }

    # add group ids to sql string
    if (%GroupList) {
        $SQLDef{SQLWhere} .= ' AND sq.group_id IN ('.(join(',', sort keys %GroupList)).')';
    }

    # generate SQL from attribute modules
    foreach my $Filter ( $Param{Filter}->{Ticket} ) {
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

        foreach my $Part ( qw(SQLAttrs SQLFrom SQLJoin SQLWhere SQLOrderBy) ) {
            next if !IsArrayRefWithData($Result->{$Part});

            # add each entry to the corresponding SQL part
            foreach my $Entry ( @{$Result->{$Part}} ) {
                $SQLDef{$Part} .= ' '.$Entry;
            }
        }
    }






















    my $Result  = $Param{Result}  || 'HASH';
    my $OrderBy = $Param{OrderBy} || 'Down';
    my $SortBy  = $Param{SortBy}  || 'Age';
    my $Limit   = $Param{Limit}   || 10000;

    if ( !$Param{ContentSearch} ) {
        $Param{ContentSearch} = 'AND';
    }

    my %SortOptions = (
        Owner                  => 'st.user_id',
        Responsible            => 'st.responsible_user_id',
        CustomerID             => 'st.customer_id',
        State                  => 'st.ticket_state_id',
        Lock                   => 'st.ticket_lock_id',
        Ticket                 => 'st.tn',
        TicketNumber           => 'st.tn',
        Title                  => 'st.title',
        Queue                  => 'sq.name',
        Type                   => 'st.type_id',
        Priority               => 'st.ticket_priority_id',
        Age                    => 'st.create_time_unix',
        Created                => 'st.create_time',
        Changed                => 'st.change_time',
        Service                => 'st.service_id',
        SLA                    => 'st.sla_id',
        PendingTime            => 'st.until_time',
        TicketEscalation       => 'st.escalation_time',
        EscalationTime         => 'st.escalation_time',
        EscalationUpdateTime   => 'st.escalation_update_time',
        EscalationResponseTime => 'st.escalation_response_time',
        EscalationSolutionTime => 'st.escalation_solution_time',
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my $TicketDynamicFields  = [];
    my $ArticleDynamicFields = [];
    my %ValidDynamicFieldParams;
    my %TicketDynamicFieldName2Config;
    my %ArticleDynamicFieldName2Config;

    # Only fetch DynamicField data if a field was requested for searching or sorting
    my $ParamCheckString = ( join '', keys %Param ) || '';

    if ( ref $Param{SortBy} eq 'ARRAY' ) {
        $ParamCheckString .= ( join '', @{ $Param{SortBy} } );
    }
    elsif ( ref $Param{SortBy} ne 'HASH' ) {
        $ParamCheckString .= $Param{SortBy} || '';
    }

    # check sort/order by options
    my @SortByArray;
    my @OrderByArray;
    if ( ref $SortBy eq 'ARRAY' ) {
        @SortByArray  = @{$SortBy};
        @OrderByArray = @{$OrderBy};
    }
    else {
        @SortByArray  = ($SortBy);
        @OrderByArray = ($OrderBy);
    }
    for my $Count ( 0 .. $#SortByArray ) {
        if (
            !$SortOptions{ $SortByArray[$Count] }
            && !$ValidDynamicFieldParams{ $SortByArray[$Count] }
            )
        {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Need valid SortBy (' . $SortByArray[$Count] . ')!',
            );
            return;
        }
        if ( $OrderByArray[$Count] ne 'Down' && $OrderByArray[$Count] ne 'Up' ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Need valid OrderBy (' . $OrderByArray[$Count] . ')!',
            );
            return;
        }
    }

    # Remember already joined tables for sorting.
    my %DynamicFieldJoinTables;
    my $DynamicFieldJoinCounter = 1;

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    DYNAMIC_FIELD:
    for my $DynamicField ( @{$TicketDynamicFields}, @{$ArticleDynamicFields} ) {
        my $SearchParam = $Param{ "DynamicField_" . $DynamicField->{Name} };

        next DYNAMIC_FIELD if ( !$SearchParam );
        next DYNAMIC_FIELD if ( ref $SearchParam ne 'HASH' );

        my $NeedJoin;

        for my $Operator ( sort keys %{$SearchParam} ) {

            my @SearchParams = ( ref $SearchParam->{$Operator} eq 'ARRAY' )
                ? @{ $SearchParam->{$Operator} }
                : ( $SearchParam->{$Operator} );

            my $SQLExtSub = ' AND (';
            my $Counter   = 0;
            TEXT:
            for my $Text (@SearchParams) {
                next TEXT if ( !defined $Text || $Text eq '' );

                $Text =~ s/\*/%/gi;

                # check search attribute, we do not need to search for *
                next TEXT if $Text =~ /^\%{1,3}$/;

                # validate data type
                my $ValidateSuccess = $DynamicFieldBackendObject->ValueValidate(
                    DynamicFieldConfig => $DynamicField,
                    Value              => $Text,
                    UserID             => $Param{UserID} || 1,
                );
                if ( !$ValidateSuccess ) {
                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                        Priority => 'error',
                        Message =>
                            "Search not executed due to invalid value '"
                            . $Text
                            . "' on field '"
                            . $DynamicField->{Name}
                            . "'!",
                    );
                    return;
                }

                if ($Counter) {
                    $SQLExtSub .= ' OR ';
                }
                $SQLExtSub .= $DynamicFieldBackendObject->SearchSQLGet(
                    DynamicFieldConfig => $DynamicField,
                    TableAlias         => "dfv$DynamicFieldJoinCounter",
                    Operator           => $Operator,
                    SearchTerm         => $Text,
                );

                $Counter++;
            }
            $SQLExtSub .= ')';
            if ($Counter) {
                $SQLExt .= $SQLExtSub;
                $NeedJoin = 1;
            }
        }

        if ($NeedJoin) {

            if ( $DynamicField->{ObjectType} eq 'Ticket' ) {

                # Join the table for this dynamic field
                $SQLFrom .= "INNER JOIN dynamic_field_value dfv$DynamicFieldJoinCounter
                    ON (st.id = dfv$DynamicFieldJoinCounter.object_id
                        AND dfv$DynamicFieldJoinCounter.field_id = " .
                    $DBObject->Quote( $DynamicField->{ID}, 'Integer' ) . ") ";
            }
            elsif ( $DynamicField->{ObjectType} eq 'Article' ) {
                if ( !$ArticleJoinSQL ) {
                    $ArticleJoinSQL = ' INNER JOIN article art ON st.id = art.ticket_id ';
                    $SQLFrom .= $ArticleJoinSQL;
                }

                $SQLFrom .= "INNER JOIN dynamic_field_value dfv$DynamicFieldJoinCounter
                    ON (art.id = dfv$DynamicFieldJoinCounter.object_id
                        AND dfv$DynamicFieldJoinCounter.field_id = " .
                    $DBObject->Quote( $DynamicField->{ID}, 'Integer' ) . ") ";

            }

            $DynamicFieldJoinTables{ $DynamicField->{Name} } = "dfv$DynamicFieldJoinCounter";

            $DynamicFieldJoinCounter++;
        }
    }

    # # get time object
    # my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

    # # remember current time to prevent searches for future timestamps
    # my $CurrentSystemTime = $TimeObject->SystemTime();

    # # get articles created older/newer than x minutes or older/newer than a date
    # my %ArticleTime = (
    #     ArticleCreateTime => 'art.incoming_time',
    # );
    # for my $Key ( sort keys %ArticleTime ) {

    #     # get articles created older than x minutes
    #     if ( defined $Param{ $Key . 'OlderMinutes' } ) {

    #         $Param{ $Key . 'OlderMinutes' } ||= 0;

    #         my $Time = $TimeObject->SystemTime()
    #             - ( $Param{ $Key . 'OlderMinutes' } * 60 );

    #         $SQLExt .= " AND $ArticleTime{$Key} <= '$Time'";
    #     }

    #     # get articles created newer than x minutes
    #     if ( defined $Param{ $Key . 'NewerMinutes' } ) {

    #         $Param{ $Key . 'NewerMinutes' } ||= 0;

    #         my $Time = $TimeObject->SystemTime()
    #             - ( $Param{ $Key . 'NewerMinutes' } * 60 );

    #         $SQLExt .= " AND $ArticleTime{$Key} >= '$Time'";
    #     }

    #     # get articles created older than xxxx-xx-xx xx:xx date
    #     my $CompareOlderNewerDate;
    #     if ( $Param{ $Key . 'OlderDate' } ) {
    #         if (
    #             $Param{ $Key . 'OlderDate' }
    #             !~ /(\d\d\d\d)-(\d\d|\d)-(\d\d|\d) (\d\d|\d):(\d\d|\d):(\d\d|\d)/
    #             )
    #         {
    #             $Kernel::OM->Get('Kernel::System::Log')->Log(
    #                 Priority => 'error',
    #                 Message  => "Invalid time format '" . $Param{ $Key . 'OlderDate' } . "'!",
    #             );
    #             return;
    #         }

    #         # convert param date to system time
    #         my $SystemTime = $TimeObject->Date2SystemTime(
    #             Year   => $1,
    #             Month  => $2,
    #             Day    => $3,
    #             Hour   => $4,
    #             Minute => $5,
    #             Second => $6,
    #         );
    #         if ( !$SystemTime ) {
    #             $Kernel::OM->Get('Kernel::System::Log')->Log(
    #                 Priority => 'error',
    #                 Message =>
    #                     "Search not executed due to invalid time '"
    #                     . $Param{ $Key . 'OlderDate' } . "'!",
    #             );
    #             return;
    #         }
    #         $CompareOlderNewerDate = $SystemTime;

    #         $SQLExt .= " AND $ArticleTime{$Key} <= '" . $SystemTime . "'";

    #     }

    #     # get articles created newer than xxxx-xx-xx xx:xx date
    #     if ( $Param{ $Key . 'NewerDate' } ) {
    #         if (
    #             $Param{ $Key . 'NewerDate' }
    #             !~ /(\d\d\d\d)-(\d\d|\d)-(\d\d|\d) (\d\d|\d):(\d\d|\d):(\d\d|\d)/
    #             )
    #         {
    #             $Kernel::OM->Get('Kernel::System::Log')->Log(
    #                 Priority => 'error',
    #                 Message  => "Invalid time format '" . $Param{ $Key . 'NewerDate' } . "'!",
    #             );
    #             return;
    #         }

    #         # convert param date to system time
    #         my $SystemTime = $TimeObject->Date2SystemTime(
    #             Year   => $1,
    #             Month  => $2,
    #             Day    => $3,
    #             Hour   => $4,
    #             Minute => $5,
    #             Second => $6,
    #         );
    #         if ( !$SystemTime ) {
    #             $Kernel::OM->Get('Kernel::System::Log')->Log(
    #                 Priority => 'error',
    #                 Message =>
    #                     "Search not executed due to invalid time '"
    #                     . $Param{ $Key . 'NewerDate' } . "'!",
    #             );
    #             return;
    #         }

    #         # don't execute queries if newer date is after current date
    #         return if $SystemTime > $CurrentSystemTime;

    #         # don't execute queries if older/newer date restriction show now valid timeframe
    #         return if $CompareOlderNewerDate && $SystemTime > $CompareOlderNewerDate;

    #         $SQLExt .= " AND $ArticleTime{$Key} >= '" . $SystemTime . "'";
    #     }
    # }

    # database query for sort/order by option
    if ( $Result ne 'COUNT' ) {
        $SQLExt .= ' ORDER BY';
        for my $Count ( 0 .. $#SortByArray ) {
            if ( $Count > 0 ) {
                $SQLExt .= ',';
            }

            # sort by dynamic field
            if ( $ValidDynamicFieldParams{ $SortByArray[$Count] } ) {
                my ($DynamicFieldName) = $SortByArray[$Count] =~ m/^DynamicField_(.*)$/smx;

                my $DynamicField = $TicketDynamicFieldName2Config{$DynamicFieldName} ||
                    $ArticleDynamicFieldName2Config{$DynamicFieldName};

                # If the table was already joined for searching, we reuse it.
                if ( !$DynamicFieldJoinTables{$DynamicFieldName} ) {

                    if ( $TicketDynamicFieldName2Config{$DynamicFieldName} ) {

                        # Join the table for this dynamic field; use a left outer join in this case.
                        # With an INNER JOIN we'd limit the result set to tickets which have an entry
                        #   for the DF which is used for sorting.
                        $SQLFrom
                            .= " LEFT OUTER JOIN dynamic_field_value dfv$DynamicFieldJoinCounter
                            ON (st.id = dfv$DynamicFieldJoinCounter.object_id
                                AND dfv$DynamicFieldJoinCounter.field_id = " .
                            $DBObject->Quote( $DynamicField->{ID}, 'Integer' ) . ") ";
                    }
                    elsif ( $ArticleDynamicFieldName2Config{$DynamicFieldName} ) {
                        if ( !$ArticleJoinSQL ) {
                            $ArticleJoinSQL = ' INNER JOIN article art ON st.id = art.ticket_id ';
                            $SQLFrom .= $ArticleJoinSQL;
                        }

                        $SQLFrom
                            .= " LEFT OUTER JOIN dynamic_field_value dfv$DynamicFieldJoinCounter
                            ON (art.id = dfv$DynamicFieldJoinCounter.object_id
                                AND dfv$DynamicFieldJoinCounter.field_id = " .
                            $DBObject->Quote( $DynamicField->{ID}, 'Integer' ) . ") ";
                    }

                    $DynamicFieldJoinTables{ $DynamicField->{Name} } = "dfv$DynamicFieldJoinCounter";

                    $DynamicFieldJoinCounter++;
                }

                my $SQLOrderField = $DynamicFieldBackendObject->SearchSQLOrderFieldGet(
                    DynamicFieldConfig => $DynamicField,
                    TableAlias         => $DynamicFieldJoinTables{$DynamicFieldName},
                );

                $SQLSelect .= ", $SQLOrderField ";
                $SQLExt    .= " $SQLOrderField ";
            }
            elsif (
                $SortByArray[$Count] eq 'Owner'
                || $SortByArray[$Count] eq 'Responsible'
                )
            {
                # include first and last name in select
                $SQLSelect
                    .= ', ' . $SortOptions{ $SortByArray[$Count] }
                    . ", u.first_name, u.last_name ";

                # join the users table on user's id
                $SQLFrom
                    .= ' JOIN users u '
                    . ' ON ' . $SortOptions{ $SortByArray[$Count] } . ' = u.id ';

                # sort by first and last name
                my $OrderBySuffix = $OrderByArray[$Count] eq 'Up' ? 'ASC' : 'DESC';
                $SQLExt .= " u.first_name $OrderBySuffix, u.last_name ";
            }
            else {

                # regular sort
                $SQLSelect .= ', ' . $SortOptions{ $SortByArray[$Count] };
                $SQLExt    .= ' ' . $SortOptions{ $SortByArray[$Count] };
            }

            if ( $OrderByArray[$Count] eq 'Up' ) {
                $SQLExt .= ' ASC';
            }
            else {
                $SQLExt .= ' DESC';
            }
        }
    }

    # check cache
    my $CacheObject;
    if ( ( $ArticleIndexSQLExt && $Param{FullTextIndex} ) || $Param{CacheTTL} ) {
        $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');
        my $CacheData = $CacheObject->Get(
            Type => 'TicketSearch',
            Key  => $SQLSelect . $SQLFrom . $SQLExt . $Result . $Limit,
        );

        if ( defined $CacheData ) {
            if ( ref $CacheData eq 'HASH' ) {
                return %{$CacheData};
            }
            elsif ( ref $CacheData eq 'ARRAY' ) {
                return @{$CacheData};
            }
            elsif ( ref $CacheData eq '' ) {
                return $CacheData;
            }
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Invalid ref ' . ref($CacheData) . '!'
            );
            return;
        }
    }

    # database query
    my %Tickets;
    my @TicketIDs;
    my $Count;
    return
        if !$DBObject->Prepare(
        SQL   => $SQLSelect . $SQLFrom . $SQLExt,
        Limit => $Limit
        );
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Count = $Row[0];
        $Tickets{ $Row[0] } = $Row[1];
        push @TicketIDs, $Row[0];
    }

    # return COUNT
    if ( $Result eq 'COUNT' ) {
        if ($CacheObject) {
            $CacheObject->Set(
                Type  => 'TicketSearch',
                Key   => $SQLSelect . $SQLFrom . $SQLExt . $Result . $Limit,
                Value => $Count,
                TTL   => $Param{CacheTTL} || 60 * 4,
            );
        }
        return $Count;
    }

    # return HASH
    elsif ( $Result eq 'HASH' ) {
        if ($CacheObject) {
            $CacheObject->Set(
                Type  => 'TicketSearch',
                Key   => $SQLSelect . $SQLFrom . $SQLExt . $Result . $Limit,
                Value => \%Tickets,
                TTL   => $Param{CacheTTL} || 60 * 4,
            );
        }
        return %Tickets;
    }

    # return ARRAY
    else {
        if ($CacheObject) {
            $CacheObject->Set(
                Type  => 'TicketSearch',
                Key   => $SQLSelect . $SQLFrom . $SQLExt . $Result . $Limit,
                Value => \@TicketIDs,
                TTL   => $Param{CacheTTL} || 60 * 4,
            );
        }
        return @TicketIDs;
    }
}

=item SearchStringStopWordsFind()

Find stop words within given search string.

    my $StopWords = $TicketObject->SearchStringStopWordsFind(
        SearchStrings => {
            'Fulltext' => '(this AND is) OR test',
            'From'     => 'myself',
        },
    );

    Returns Hashref with found stop words.

=cut

sub SearchStringStopWordsFind {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Key (qw(SearchStrings)) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!",
            );
            return;
        }
    }

    my $StopWordRaw = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::SearchIndex::StopWords') || {};
    if ( !$StopWordRaw || ref $StopWordRaw ne 'HASH' ) {

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Invalid config option Ticket::SearchIndex::StopWords! "
                . "Please reset the search index options to reactivate the factory defaults.",
        );

        return;
    }

    my %StopWord;
    LANGUAGE:
    for my $Language ( sort keys %{$StopWordRaw} ) {

        if ( !$Language || !$StopWordRaw->{$Language} || ref $StopWordRaw->{$Language} ne 'ARRAY' ) {

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Invalid config option Ticket::SearchIndex::StopWords###$Language! "
                    . "Please reset this option to reactivate the factory defaults.",
            );

            next LANGUAGE;
        }

        WORD:
        for my $Word ( @{ $StopWordRaw->{$Language} } ) {

            next WORD if !defined $Word || !length $Word;

            $Word = lc $Word;

            $StopWord{$Word} = 1;
        }
    }

    my $SearchIndexAttributes = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::SearchIndex::Attribute');
    my $WordLengthMin         = $SearchIndexAttributes->{WordLengthMin} || 3;
    my $WordLengthMax         = $SearchIndexAttributes->{WordLengthMax} || 30;

    my %StopWordsFound;
    SEARCHSTRING:
    for my $Key ( sort keys %{ $Param{SearchStrings} } ) {
        my $SearchString = $Param{SearchStrings}->{$Key};
        my %Result       = $Kernel::OM->Get('Kernel::System::DB')->QueryCondition(
            'Key'      => '.',             # resulting SQL is irrelevant
            'Value'    => $SearchString,
            'BindMode' => 1,
        );

        next SEARCHSTRING if !%Result || ref $Result{Values} ne 'ARRAY' || !@{ $Result{Values} };

        my %Words;
        for my $Value ( @{ $Result{Values} } ) {
            my @Words = split '\s+', $$Value;
            for my $Word (@Words) {
                $Words{ lc $Word } = 1;
            }
        }

        @{ $StopWordsFound{$Key} }
            = grep { $StopWord{$_} || length $_ < $WordLengthMin || length $_ > $WordLengthMax } sort keys %Words;
    }

    return \%StopWordsFound;
}

=item SearchStringStopWordsUsageWarningActive()

Checks if warnings for stop words in search strings are active or not.

    my $WarningActive = $TicketObject->SearchStringStopWordsUsageWarningActive();

=cut

sub SearchStringStopWordsUsageWarningActive {
    my ( $Self, %Param ) = @_;

    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $SearchIndexModule   = $ConfigObject->Get('Ticket::SearchIndexModule');
    my $WarnOnStopWordUsage = $ConfigObject->Get('Ticket::SearchIndex::WarnOnStopWordUsage') || 0;
    if (
        $SearchIndexModule eq 'Kernel::System::Ticket::ArticleSearchIndex::StaticDB'
        && $WarnOnStopWordUsage
        )
    {
        return 1;
    }

    return 0;
}

=begin Internal:

=cut

=item _InConditionGet()

internal function to create an

    AND table.column IN (values)

condition string from an array.

    my $SQLPart = $TicketObject->_InConditionGet(
        TableColumn => 'table.column',
        IDRef       => $ArrayRef,
    );

=cut

sub _InConditionGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Key (qw(TableColumn IDRef)) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!",
            );
            return;
        }
    }

    # sort ids to cache the SQL query
    my @SortedIDs = sort { $a <=> $b } @{ $Param{IDRef} };

    # quote values
    SORTEDID:
    for my $Value (@SortedIDs) {
        next SORTEDID if !defined $Kernel::OM->Get('Kernel::System::DB')->Quote( $Value, 'Integer' );
    }

    # split IN statement with more than 900 elements in more statements combined with OR
    # because Oracle doesn't support more than 1000 elements for one IN statement.
    my @SQLStrings;
    while ( scalar @SortedIDs ) {

        # remove section in the array
        my @SortedIDsPart = splice @SortedIDs, 0, 900;

        # link together IDs
        my $IDString = join ', ', @SortedIDsPart;

        # add new statement
        push @SQLStrings, " $Param{TableColumn} IN ($IDString) ";
    }

    my $SQL = '';
    if (@SQLStrings) {

        # combine statements
        $SQL = join ' OR ', @SQLStrings;

        # encapsulate conditions
        $SQL = ' AND ( ' . $SQL . ' ) ';
    }
    return $SQL;
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
