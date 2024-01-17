# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::PostMaster;

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

$Helper->UseTmpArticleDir();

my @DynamicfieldIDs;
my @DynamicFieldUpdate;
my %NeededDynamicfields = (
    TicketFreeKey1  => 1,
    TicketFreeText1 => 1,
    TicketFreeKey2  => 1,
    TicketFreeText2 => 1,
    TicketFreeKey3  => 1,
    TicketFreeText3 => 1,
    TicketFreeKey4  => 1,
    TicketFreeText4 => 1,
    TicketFreeKey5  => 1,
    TicketFreeText5 => 1,
    TicketFreeKey5  => 1,
    TicketFreeText5 => 1,
    TicketFreeKey6  => 1,
    TicketFreeText6 => 1,
    TicketFreeTime1 => 1,
    TicketFreeTime2 => 1,
    TicketFreeTime3 => 1,
    TicketFreeTime4 => 1,
    TicketFreeTime5 => 1,
    TicketFreeTime6 => 1,
);

# list available dynamic fields
my $DynamicFields = $Kernel::OM->Get('DynamicField')->DynamicFieldList(
    Valid      => 0,
    ResultType => 'HASH',
);
$DynamicFields = ( ref $DynamicFields eq 'HASH' ? $DynamicFields : {} );
$DynamicFields = { reverse %{$DynamicFields} };

for my $FieldName ( sort keys %NeededDynamicfields ) {
    if ( !$DynamicFields->{$FieldName} ) {

        # create a dynamic field
        my $FieldID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
            Name       => $FieldName,
            Label      => $FieldName . "_test",
            FieldOrder => 9991,
            FieldType  => 'Text',
            ObjectType => 'Ticket',
            Config     => {
                DefaultValue => 'a value',
            },
            ValidID => 1,
            UserID  => 1,
        );

        # verify dynamic field creation
        $Self->True(
            $FieldID,
            "DynamicFieldAdd() successful for Field $FieldName",
        );

        push @DynamicfieldIDs, $FieldID;
    }
    else {
        my $DynamicField
            = $Kernel::OM->Get('DynamicField')->DynamicFieldGet( ID => $DynamicFields->{$FieldName} );

        if ( $DynamicField->{ValidID} > 1 ) {
            push @DynamicFieldUpdate, $DynamicField;
            $DynamicField->{ValidID} = 1;
            my $SuccessUpdate = $Kernel::OM->Get('DynamicField')->DynamicFieldUpdate(
                %{$DynamicField},
                Reorder => 0,
                UserID  => 1,
                ValidID => 1,
            );

            # verify dynamic field creation
            $Self->True(
                $SuccessUpdate,
                "DynamicFieldUpdate() successful update for Field $DynamicField->{Name}",
            );
        }
    }
}

my %NeededXHeaders = (
    'X-KIX-DynamicField-TicketFreeKey1'  => 1,
    'X-KIX-DynamicField-TicketFreeText1' => 1,
    'X-KIX-DynamicField-TicketFreeKey2'  => 1,
    'X-KIX-DynamicField-TicketFreeText2' => 1,
    'X-KIX-DynamicField-TicketFreeKey3'  => 1,
    'X-KIX-DynamicField-TicketFreeText3' => 1,
    'X-KIX-DynamicField-TicketFreeTime1' => 1,
    'X-KIX-DynamicField-TicketFreeTime2' => 1,
    'X-KIX-DynamicField-TicketFreeTime3' => 1,
    'X-KIX-DynamicField-TicketFreeTime4' => 1,
    'X-KIX-DynamicField-TicketFreeTime5' => 1,
    'X-KIX-DynamicField-TicketFreeTime6' => 1,
    'X-KIX-TicketKey1'                   => 1,
    'X-KIX-TicketValue1'                 => 1,
    'X-KIX-TicketKey2'                   => 1,
    'X-KIX-TicketValue2'                 => 1,
    'X-KIX-TicketKey3'                   => 1,
    'X-KIX-TicketValue3'                 => 1,
    'X-KIX-TicketTime1'                  => 1,
    'X-KIX-TicketTime2'                  => 1,
    'X-KIX-TicketTime3'                  => 1,
    'X-KIX-TicketTime4'                  => 1,
    'X-KIX-TicketTime5'                  => 1,
    'X-KIX-TicketTime6'                  => 1,
    'X-KIX-Owner'                        => 1,
    'X-KIX-OwnerID'                      => 1,
    'X-KIX-Responsible'                  => 1,
    'X-KIX-ResponsibleID'                => 1,
);

my $XHeaders          = $Kernel::OM->Get('Config')->Get('PostmasterX-Header');
my @PostmasterXHeader = @{$XHeaders};
HEADER:
for my $Header ( sort keys %NeededXHeaders ) {
    next HEADER if ( grep $_ eq $Header, @PostmasterXHeader );
    push @PostmasterXHeader, $Header;
}
$Kernel::OM->Get('Config')->Set(
    Key   => 'PostmasterX-Header',
    Value => \@PostmasterXHeader
);

# disable not needed event module
$Kernel::OM->Get('Config')->Set(
    Key => 'Ticket::EventModulePost###TicketDynamicFieldDefault',
);

# use different subject format
for my $TicketSubjectConfig ( 'Right', 'Left' ) {
    $Kernel::OM->Get('Config')->Set(
        Key   => 'Ticket::SubjectFormat',
        Value => $TicketSubjectConfig,
    );

    # use different ticket number generators
    for my $NumberModule (qw(AutoIncrement DateChecksum Date Random)) {

        $Kernel::OM->ObjectsDiscard( Objects => ['PostMaster::Filter'] );
        my $PostMasterFilter = $Kernel::OM->Get('PostMaster::Filter');

        $Kernel::OM->Get('Config')->Set(
            Key   => 'Ticket::NumberGenerator',
            Value => "Kernel::System::Ticket::Number::$NumberModule",
        );

        # use different storage backends
        for my $StorageModule (qw(ArticleStorageDB ArticleStorageFS)) {
            $Kernel::OM->Get('Config')->Set(
                Key   => 'Ticket::StorageModule',
                Value => "Kernel::System::Ticket::$StorageModule",
            );

            # Recreate Ticket object for every loop.
            $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

            # add rand postmaster filter
            my $FilterRand1 = 'filter' . $Helper->GetRandomID();
            my $FilterRand2 = 'filter' . $Helper->GetRandomID();
            my $FilterRand3 = 'filter' . $Helper->GetRandomID();
            my $FilterRand4 = 'filter' . $Helper->GetRandomID();
            $PostMasterFilter->FilterAdd(
                Name           => $FilterRand1,
                StopAfterMatch => 0,
                ValidID        => 1,
                UserID         => 1,
                Match          => {
                    Subject => 'test',
                    To      => 'EMAILADDRESS:darthvader@test.org',
                },
                Set => {
                    'X-KIX-Queue'        => 'Service Desk',
                    'X-KIX-TicketKey1'   => 'Key1',
                    'X-KIX-TicketValue1' => 'Text1',
                },
            );
            $PostMasterFilter->FilterAdd(
                Name           => $FilterRand2,
                StopAfterMatch => 0,
                ValidID        => 1,
                UserID         => 1,
                Match          => {
                    Subject => 'test',
                    To      => 'EMAILADDRESS:darthvader2@test.org',
                },
                Set => {
                    'X-KIX-TicketKey2'   => 'Key2',
                    'X-KIX-TicketValue2' => 'Text2',
                },
            );
            $PostMasterFilter->FilterAdd(
                Name           => $FilterRand3,
                StopAfterMatch => 0,
                ValidID        => 1,
                UserID         => 1,
                Match          => {
                    Subject => 'test 1',
                    To      => 'test.org',
                },
                Set => {
                    'X-KIX-TicketKey3'   => 'Key3',
                    'X-KIX-TicketValue3' => 'Text3',
                },
            );
            $PostMasterFilter->FilterAdd(
                Name           => $FilterRand4,
                StopAfterMatch => 0,
                ValidID        => 1,
                UserID         => 1,
                Match          => {
                    Subject => 'NOT REGEX',
                    To      => 'darthvader@test.org',
                },
                Not => {
                    To => 1,
                },
                Set => {
                    'X-KIX-Ignore' => 'yes',
                },
            );

            # get rand sender address
            my $UserRand1 = 'example-user' . $Helper->GetRandomID() . '@example.com';

            FILE:
            for my $File (qw(1 2 3 5 6 11 17 18 21 22 23)) {

                my $NamePrefix = "#$NumberModule $StorageModule $TicketSubjectConfig $File ";

                # new ticket check
                my $Location = $Kernel::OM->Get('Config')->Get('Home')
                    . "/scripts/test/system/sample/PostMaster/PostMaster-Test$File.box";
                my $ContentRef = $Kernel::OM->Get('Main')->FileRead(
                    Location => $Location,
                    Mode     => 'binmode',
                    Result   => 'ARRAY',
                );
                my @Content;
                for my $Line ( @{$ContentRef} ) {
                    if ( $Line =~ /^From:/ ) {
                        $Line = "From: \"Some Realname\" <$UserRand1>\n";
                    }
                    push @Content, $Line;
                }

                # follow up check
                my @ContentNew = ();
                for my $Line (@Content) {
                    push @ContentNew, $Line;
                }
                my @Return;

                $Kernel::OM->Get('Config')->Set(
                    Key   => 'PostmasterDefaultState',
                    Value => 'new'
                );
                {
                    my $PostMasterObject = Kernel::System::PostMaster->new(
                        Email => \@Content,
                    );

                    @Return = $PostMasterObject->Run();
                    @Return = @{ $Return[0] || [] };
                }

                if ( $File != 22 ) {
                    $Self->Is(
                        $Return[0] || 0,
                        1,
                        $NamePrefix . ' Run() - NewTicket',
                    );

                    $Self->True(
                        $Return[1] || 0,
                        $NamePrefix . ' Run() - NewTicket/TicketID',
                    );
                }
                else {
                    $Self->Is(
                        $Return[0] || 0,
                        5,
                        $NamePrefix . ' Run() - NewTicket',
                    );

                    $Self->False(
                        $Return[1],
                        $NamePrefix . ' Run() - NewTicket/TicketID',
                    );

                    next FILE;
                }

                # new/clear ticket object
                $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

                my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                    TicketID      => $Return[1],
                    DynamicFields => 1,
                );
                my @ArticleIDs = $Kernel::OM->Get('Ticket')->ArticleIndex(
                    TicketID => $Return[1],
                );

                if ( $File == 1 ) {
                    my @Tests = (
                        {
                            Key    => 'Queue',
                            Result => 'Service Desk',
                        },
                        {
                            Key    => 'DynamicField_TicketFreeKey1',
                            Result => [ 'Key1' ],
                        },
                        {
                            Key    => 'DynamicField_TicketFreeText1',
                            Result => [ 'Text1' ],
                        },
                        {
                            Key    => 'DynamicField_TicketFreeKey2',
                            Result => undef,
                        },
                        {
                            Key    => 'DynamicField_TicketFreeText2',
                            Result => undef,
                        },
                        {
                            Key    => 'DynamicField_TicketFreeKey3',
                            Result => [ 'Key3' ],
                        },
                        {
                            Key    => 'DynamicField_TicketFreeText3',
                            Result => [ 'Text3' ],
                        },
                    );
                    for my $Test (@Tests) {
                        if ( $Test->{Key} =~ /^DynamicField_/ && $Test->{Result} ) {
                            $Self->IsDeeply(
                                $Ticket{ $Test->{Key} },
                                $Test->{Result},
                                $NamePrefix . " $Test->{Key} check",
                            );
                        }
                        else {
                            $Self->Is(
                                $Ticket{ $Test->{Key} },
                                $Test->{Result},
                                $NamePrefix . " $Test->{Key} check",
                            );
                        }
                    }
                }

                if ( $File == 3 ) {

                    # check body
                    my %Article = $Kernel::OM->Get('Ticket')->ArticleGet(
                        ArticleID     => $ArticleIDs[0],
                        DynamicFields => 1,
                    );
                    my $MD5 = $Kernel::OM->Get('Main')->MD5sum( String => $Article{Body} ) || '';
                    $Self->Is(
                        $MD5,
                        'd89998aae29c79cdadd4666c294028f1',
                        $NamePrefix . ' md5 body check',
                    );

                    # check attachments
                    my %Index = $Kernel::OM->Get('Ticket')->ArticleAttachmentIndex(
                        ArticleID => $ArticleIDs[0],
                        UserID    => 1,
                    );
                    my %Attachment = $Kernel::OM->Get('Ticket')->ArticleAttachment(
                        ArticleID => $ArticleIDs[0],
                        FileID    => 2,
                        UserID    => 1,
                    );
                    $MD5 = $Kernel::OM->Get('Main')->MD5sum( String => $Attachment{Content} ) || '';
                    $Self->Is(
                        $MD5,
                        '4e78ae6bffb120669f50bca56965f552',
                        $NamePrefix . ' md5 attachment check',
                    );

                }

                if ( $File == 5 ) {

                    # check body
                    my %Article = $Kernel::OM->Get('Ticket')->ArticleGet(
                        ArticleID     => $ArticleIDs[0],
                        DynamicFields => 1,
                    );
                    my @Tests = (
                        {
                            Key    => 'DynamicField_TicketFreeKey1',
                            Result => [ 'Test' ],
                        },
                        {
                            Key    => 'DynamicField_TicketFreeText1',
                            Result => [ 'ABC' ],
                        },
                        {
                            Key    => 'DynamicField_TicketFreeKey2',
                            Result => [ 'Test2' ],
                        },
                        {
                            Key    => 'DynamicField_TicketFreeText2',
                            Result => [ 'ABC2' ],
                        },
                        {
                            Key    => 'DynamicField_TicketFreeTime1',
                            Result => [ '2008-01-12 13:14:15' ],
                        },
                        {
                            Key    => 'DynamicField_TicketFreeTime2',
                            Result => [ '2008-01-12 13:15:16' ],
                        },
                        {
                            Key    => 'DynamicField_TicketFreeTime3',
                            Result => [ '2008-01-12 13:16:17' ],
                        },
                        {
                            Key    => 'DynamicField_TicketFreeTime4',
                            Result => [ '2008-01-12 13:17:18' ],
                        },
                        {
                            Key    => 'DynamicField_TicketFreeTime5',
                            Result => [ '2008-01-12 13:18:19' ],
                        },
                        {
                            Key    => 'DynamicField_TicketFreeTime6',
                            Result => [ '2008-01-12 13:19:20' ],
                        },
                    );
                    for my $Test (@Tests) {
                        if ( $Test->{Key} =~ /^DynamicField_/ && $Test->{Result} ) {
                            $Self->IsDeeply(
                                $Ticket{ $Test->{Key} },
                                $Test->{Result},
                                $NamePrefix . " $Test->{Key} check",
                            );
                        }
                        else {
                            $Self->Is(
                                $Ticket{ $Test->{Key} },
                                $Test->{Result},
                                $NamePrefix . " $Test->{Key} check",
                            );
                        }
                    }
                }

                if ( $File == 6 ) {

                    # check body
                    my %Article = $Kernel::OM->Get('Ticket')->ArticleGet(
                        ArticleID     => $ArticleIDs[0],
                        DynamicFields => 1,
                    );
                    my $MD5 = $Kernel::OM->Get('Main')->MD5sum( String => $Article{Body} ) || '';
                    $Self->Is(
                        $MD5,
                        'b527ca4a8b9d69df321a04ab429b206d',
                        $NamePrefix . ' md5 body check',
                    );

                    # check attachments
                    my %Index = $Kernel::OM->Get('Ticket')->ArticleAttachmentIndex(
                        ArticleID => $ArticleIDs[0],
                        UserID    => 1,
                    );
                    my %Attachment = $Kernel::OM->Get('Ticket')->ArticleAttachment(
                        ArticleID => $ArticleIDs[0],
                        FileID    => 2,
                        UserID    => 1,
                    );
                    $MD5 = $Kernel::OM->Get('Main')->MD5sum( String => $Attachment{Content} ) || '';
                    $Self->Is(
                        $MD5,
                        '0596f2939525c6bd50fc2b649e40fbb6',
                        $NamePrefix . ' md5 attachment check',
                    );

                }
                if ( $File == 11 ) {

                    # check body
                    my %Article = $Kernel::OM->Get('Ticket')->ArticleGet(
                        ArticleID     => $ArticleIDs[0],
                        DynamicFields => 1,
                    );
                    my $MD5 = $Kernel::OM->Get('Main')->MD5sum( String => $Article{Body} ) || '';

                    $Self->Is(
                        $MD5,
                        'aba34ca02b07ab3042817188b6a840e4',
                        $NamePrefix . ' md5 body check',
                    );
                }

                # send follow up #1
                @Content = ();
                for my $Line (@ContentNew) {
                    if ( $Line =~ /^Subject:/ ) {
                        $Line = 'Subject: ' . $Kernel::OM->Get('Ticket')->TicketSubjectBuild(
                            TicketNumber => $Ticket{TicketNumber},
                            Subject      => $Line,
                        );
                    }
                    if ( $Line =~ /^(Message-ID:)/i ) {
                        my $Time   = $Kernel::OM->Get('Time')->SystemTime();
                        my $Random = rand 999999;
                        my $FQDN   = $Kernel::OM->Get('Config')->Get('FQDN');
                        if (IsHashRefWithData($FQDN)) {
                            $FQDN = $FQDN->{Backend}
                        }
                        $Line = "$1 <$Time.$Random\@$FQDN>";
                    }
                    push @Content, $Line;
                }
                $Kernel::OM->Get('Config')->Set(
                    Key   => 'PostmasterFollowUpState',
                    Value => 'new'
                );
                {
                    my $PostMasterObject = Kernel::System::PostMaster->new(
                        Email => \@Content,
                    );

                    @Return = $PostMasterObject->Run();
                    @Return = @{ $Return[0] || [] };
                }

                $Self->Is(
                    $Return[0] || 0,
                    2,
                    $NamePrefix . ' Run() - FollowUp',
                );
                $Self->True(
                    $Return[1] || 0,
                    $NamePrefix . ' Run() - FollowUp/TicketID',
                );

                # new/clear ticket object
                $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

                %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                    TicketID      => $Return[1],
                    DynamicFields => 1,
                );
                $Self->Is(
                    $Ticket{State} || 0,
                    'new',
                    $NamePrefix . ' Run() - FollowUp/State check',
                );
                my $StateSet = $Kernel::OM->Get('Ticket')->TicketStateSet(
                    State    => 'pending reminder',
                    TicketID => $Return[1],
                    UserID   => 1,
                );
                $Self->True(
                    $StateSet || 0,
                    $NamePrefix . ' StateSet() - pending reminder',
                );

                # send follow up #2
                @Content = ();
                for my $Line (@ContentNew) {
                    if ( $Line =~ /^Subject:/ ) {
                        $Line = 'Subject: ' . $Kernel::OM->Get('Ticket')->TicketSubjectBuild(
                            TicketNumber => $Ticket{TicketNumber},
                            Subject      => $Line,
                        );
                    }
                    if ( $Line =~ /^(Message-ID:)/i ) {
                        my $Time   = $Kernel::OM->Get('Time')->SystemTime();
                        my $Random = rand 999999;
                        my $FQDN   = $Kernel::OM->Get('Config')->Get('FQDN');
                        if (IsHashRefWithData($FQDN)) {
                            $FQDN = $FQDN->{Backend}
                        }
                        $Line = "$1 <$Time.$Random\@$FQDN>";
                    }
                    push @Content, $Line;
                }
                {
                    my $PostMasterObject = Kernel::System::PostMaster->new(
                        Email => \@Content,
                    );

                    @Return = $PostMasterObject->Run();
                    @Return = @{ $Return[0] || [] };
                }

                $Self->Is(
                    $Return[0] || 0,
                    2,
                    $NamePrefix . ' Run() - FollowUp',
                );
                $Self->True(
                    $Return[1] || 0,
                    $NamePrefix . ' Run() - FollowUp/TicketID',
                );

                # send follow up #3
                @Content = ();
                for my $Line (@ContentNew) {
                    if ( $Line =~ /^Subject:/ ) {
                        $Line = 'Subject: '
                            . $Kernel::OM->Get('Config')->Get('Ticket::Hook')
                            . ": $Ticket{TicketNumber}";
                    }
                    if ( $Line =~ /^(Message-ID:)/i ) {
                        my $Time   = $Kernel::OM->Get('Time')->SystemTime();
                        my $Random = rand 999999;
                        my $FQDN   = $Kernel::OM->Get('Config')->Get('FQDN');
                        if (IsHashRefWithData($FQDN)) {
                            $FQDN = $FQDN->{Backend}
                        }
                        $Line = "$1 <$Time.$Random\@$FQDN>";
                    }
                    push @Content, $Line;
                }
                {
                    my $PostMasterObject = Kernel::System::PostMaster->new(
                        Email => \@Content,
                    );

                    @Return = $PostMasterObject->Run();
                    @Return = @{ $Return[0] || [] };
                }

                $Self->Is(
                    $Return[0] || 0,
                    2,
                    $NamePrefix . ' Run() - FollowUp (Ticket::Hook#: xxxxxxxxxx)',
                );
                $Self->True(
                    $Return[1] || 0,
                    $NamePrefix . ' Run() - FollowUp/TicketID',
                );

                # send follow up #4
                @Content = ();
                for my $Line (@ContentNew) {
                    if ( $Line =~ /^Subject:/ ) {
                        $Line = 'Subject: '
                            . $Kernel::OM->Get('Config')->Get('Ticket::Hook')
                            . ":$Ticket{TicketNumber}";
                    }
                    if ( $Line =~ /^(Message-ID:)/i ) {
                        my $Time   = $Kernel::OM->Get('Time')->SystemTime();
                        my $Random = rand 999999;
                        my $FQDN   = $Kernel::OM->Get('Config')->Get('FQDN');
                        if (IsHashRefWithData($FQDN)) {
                            $FQDN = $FQDN->{Backend}
                        }
                        $Line = "$1 <$Time.$Random\@$FQDN>";
                    }
                    push @Content, $Line;
                }
                {
                    my $PostMasterObject = Kernel::System::PostMaster->new(
                        Email => \@Content,
                    );

                    @Return = $PostMasterObject->Run();
                    @Return = @{ $Return[0] || [] };
                }

                $Self->Is(
                    $Return[0] || 0,
                    2,
                    $NamePrefix . ' Run() - FollowUp (Ticket::Hook#:xxxxxxxxxx)',
                );
                $Self->True(
                    $Return[1] || 0,
                    $NamePrefix . ' Run() - FollowUp/TicketID',
                );

                $Kernel::OM->Get('Config')->Set(
                    Key   => 'PostmasterFollowUpState',
                    Value => 'open'
                );

                # send follow up #5
                @Content = ();
                for my $Line (@ContentNew) {
                    if ( $Line =~ /^Subject:/ ) {
                        $Line = 'Subject: '
                            . $Kernel::OM->Get('Config')->Get('Ticket::Hook')
                            . $Ticket{TicketNumber};
                    }
                    if ( $Line =~ /^(Message-ID:)/i ) {
                        my $Time   = $Kernel::OM->Get('Time')->SystemTime();
                        my $Random = rand 999999;
                        my $FQDN   = $Kernel::OM->Get('Config')->Get('FQDN');
                        if (IsHashRefWithData($FQDN)) {
                            $FQDN = $FQDN->{Backend}
                        }
                        $Line = "$1 <$Time.$Random\@$FQDN>";
                    }
                    push @Content, $Line;
                }
                {
                    my $PostMasterObject = Kernel::System::PostMaster->new(
                        Email => \@Content,
                    );

                    @Return = $PostMasterObject->Run();
                    @Return = @{ $Return[0] || [] };
                }

                $Self->Is(
                    $Return[0] || 0,
                    2,
                    $NamePrefix . ' Run() - FollowUp (Ticket::Hook#xxxxxxxxxx)',
                );
                $Self->True(
                    $Return[1] || 0,
                    $NamePrefix . ' Run() - FollowUp/TicketID',
                );

                # new/clear ticket object
                $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

                %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                    TicketID      => $Return[1],
                    DynamicFields => 1,
                );
                $Self->Is(
                    $Ticket{State} || 0,
                    'open',
                    $NamePrefix . ' Run() - FollowUp/PostmasterFollowUpState check',
                );
                $StateSet = $Kernel::OM->Get('Ticket')->TicketStateSet(
                    State    => 'closed',
                    TicketID => $Return[1],
                    UserID   => 1,
                );
                $Self->True(
                    $StateSet || 0,
                    $NamePrefix . ' StateSet() - closed',
                );

                # send follow up #3
                @Content = ();
                for my $Line (@ContentNew) {
                    if ( $Line =~ /^Subject:/ ) {
                        $Line = 'Subject: ' . $Kernel::OM->Get('Ticket')->TicketSubjectBuild(
                            TicketNumber => $Ticket{TicketNumber},
                            Subject      => $Line,
                        );
                    }
                    if ( $Line =~ /^(Message-ID:)/i ) {
                        my $Time   = $Kernel::OM->Get('Time')->SystemTime();
                        my $Random = rand 999999;
                        my $FQDN   = $Kernel::OM->Get('Config')->Get('FQDN');
                        if (IsHashRefWithData($FQDN)) {
                            $FQDN = $FQDN->{Backend}
                        }
                        $Line = "$1 <$Time.$Random\@$FQDN>";
                    }
                    push @Content, $Line;
                }
                {
                    my $PostMasterObject = Kernel::System::PostMaster->new(
                        Email => \@Content,
                    );

                    @Return = $PostMasterObject->Run();
                    @Return = @{ $Return[0] || [] };
                }

                $Self->Is(
                    $Return[0] || 0,
                    2,
                    $NamePrefix . ' Run() - FollowUp',
                );
                $Self->True(
                    $Return[1] || 0,
                    $NamePrefix . ' Run() - FollowUp/TicketID',
                );

                # new/clear ticket object
                $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

                %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                    TicketID      => $Return[1],
                    DynamicFields => 1,
                );
                $Self->Is(
                    $Ticket{State} || 0,
                    'open',
                    $NamePrefix . ' Run() - FollowUp/PostmasterFollowUpStateClosed check',
                );

                # delete ticket
                my $Delete = $Kernel::OM->Get('Ticket')->TicketDelete(
                    TicketID => $Return[1],
                    UserID   => 1,
                );
                $Self->True(
                    $Delete || 0,
                    $NamePrefix . ' TicketDelete()',
                );
            }
            $PostMasterFilter->FilterDelete( Name => $FilterRand1 );
            $PostMasterFilter->FilterDelete( Name => $FilterRand2 );
            $PostMasterFilter->FilterDelete( Name => $FilterRand3 );
            $PostMasterFilter->FilterDelete( Name => $FilterRand4 );
        }
    }
}

# filter test
my @Tests = (
    {
        Name  => '#1 - From Test',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
            'X-KIX-Queue'        => 'Service Desk',
            'X-KIX-TicketKey1'   => 'Key1',
            'X-KIX-TicketValue1' => 'Text1',
            'X-KIX-TicketKey3'   => 'Key3',
            'X-KIX-TicketValue3' => 'Text3',
        },
        Check => {
            Queue                        => 'Service Desk',
            DynamicField_TicketFreeKey3  => [ 'Key3' ],
            DynamicField_TicketFreeText3 => [ 'Text3' ],
        },
    },
    {
        Name  => '#2 - From Test',
        Match => {
            From => 'EMAILADDRESS:sender@example.com',
        },
        Set => {
            'X-KIX-Queue'        => 'Service Desk',
            'X-KIX-TicketKey1'   => 'Key1#2',
            'X-KIX-TicketValue1' => 'Text1#2',
            'X-KIX-TicketKey4'   => 'Key4#2',
            'X-KIX-TicketValue4' => 'Text4#2',
        },
        Check => {
            Queue                        => 'Service Desk',
            DynamicField_TicketFreeKey1  => [ 'Key1#2' ],
            DynamicField_TicketFreeText1 => [ 'Text1#2' ],
        },
    },
    {
        Name  => '#3 - From Test',
        Match => {
            From => 'EMAILADDRESS:not_this_sender@example.com',
        },
        Set => {
            'X-KIX-Queue'        => 'Service Desk',
            'X-KIX-TicketKey1'   => 'Key1#3',
            'X-KIX-TicketValue1' => 'Text1#3',
            'X-KIX-TicketKey3'   => 'Key3#3',
            'X-KIX-TicketValue3' => 'Text3#3',
        },
    },
    {
        Name  => '#4 - Regular Expressions - match',
        Match => {
            From => '(\w+)@example.com',
        },
        Set => {
            'X-KIX-TicketKey4' => '[***]',
        },
        Check => {
            DynamicField_TicketFreeKey4 => [ 'sender' ],
        },
    },
    {
        Name  => '#5 - Regular Expressions - match but no optional match result',
        Match => {
            From => 'sender([f][o][o])?@example.com',
        },
        Set => {
            'X-KIX-TicketKey5' => '[***]',
        },
        Check => {
            DynamicField_TicketFreeKey5 => undef,
        },
    },
);

$Kernel::OM->ObjectsDiscard( Objects => ['PostMaster::Filter'] );
my $PostMasterFilter = $Kernel::OM->Get('PostMaster::Filter');

for my $Type (qw(Config DB)) {
    for my $Test (@Tests) {
        if ( $Type eq 'DB' ) {
            $PostMasterFilter->FilterAdd(
                Name           => $Test->{Name},
                StopAfterMatch => 0,
                ValidID        => 1,
                UserID         => 1,
                %{$Test},
            );
        }
        else {
            $Kernel::OM->Get('Config')->Set(
                Key   => 'PostMaster::PreFilterModule###' . $Test->{Name},
                Value => {
                    %{$Test},
                    Module => 'Kernel::System::PostMaster::Filter::Match',
                },
            );
        }
    }

    my $Email = 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
Subject: some subject

Some Content in Body
';

    my @Return;
    {
        my $PostMasterObject = Kernel::System::PostMaster->new(
            Email => \$Email,
        );

        @Return = $PostMasterObject->Run();
        @Return = @{ $Return[0] || [] };
    }

    $Self->Is(
        $Return[0] || 0,
        1,
        "#Filter $Type Run() - NewTicket",
    );
    $Self->True(
        $Return[1] || 0,
        "#Filter $Type Run() - NewTicket/TicketID",
    );

    # new/clear ticket object
    $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID      => $Return[1],
        DynamicFields => 1,
    );

    TEST:
    for my $Test (@Tests) {
        next TEST if !$Test->{Check};
        for my $Key ( sort keys %{ $Test->{Check} } ) {
            if ( $Key =~ /^DynamicField_/ && $Test->{Check}->{$Key} ) {
                $Self->IsDeeply(
                    $Ticket{$Key},
                    $Test->{Check}->{$Key},
                    "#Filter $Type Run('$Test->{Name}') - $Key",
                );
            }
            else {
                $Self->Is(
                    $Ticket{$Key},
                    $Test->{Check}->{$Key},
                    "#Filter $Type Run('$Test->{Name}') - $Key",
                );
            }
        }
    }

    # delete ticket
    my $Delete = $Kernel::OM->Get('Ticket')->TicketDelete(
        TicketID => $Return[1],
        UserID   => 1,
    );
    $Self->True(
        $Delete || 0,
        "#Filter $Type TicketDelete()",
    );

    # remove filter
    for my $Test (@Tests) {
        if ( $Type eq 'DB' ) {
            $PostMasterFilter->FilterDelete( Name => $Test->{Name} );
        }
        else {
            $Kernel::OM->Get('Config')->Set(
                Key   => 'PostMaster::PreFilterModule###' . $Test->{Name},
                Value => undef,
            );
        }
    }
}

# filter test Envelope-To and X-Envelope-To
@Tests = (
    {
        Name  => '#1 - Envelope-To Test',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
Envelope-To: Some EnvelopeTo Name <envelopeto@example.com>
Subject: some subject

Some Content in Body
',
        Match => {
            'Envelope-To' => 'envelopeto@example.com',
        },
        Set => {
            'X-KIX-Queue'        => 'Junk',
            'X-KIX-TicketKey5'   => 'Key5#1',
            'X-KIX-TicketValue5' => 'Text5#1',
        },
        Check => {
            Queue                        => 'Junk',
            DynamicField_TicketFreeKey5  => [ 'Key5#1' ],
            DynamicField_TicketFreeText5 => [ 'Text5#1' ],
        },
    },
    {
        Name  => '#2 - X-Envelope-To Test',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
X-Envelope-To: Some XEnvelopeTo Name <xenvelopeto@example.com>
Subject: some subject

Some Content in Body
',
        Match => {
            'X-Envelope-To' => 'xenvelopeto@example.com',
        },
        Set => {
            'X-KIX-Queue'        => 'Service Desk',
            'X-KIX-TicketKey6'   => 'Key6#1',
            'X-KIX-TicketValue6' => 'Text6#1',
        },
        Check => {
            Queue                        => 'Service Desk',
            DynamicField_TicketFreeKey6  => [ 'Key6#1' ],
            DynamicField_TicketFreeText6 => [ 'Text6#1' ],
        },
    },
);

$Kernel::OM->ObjectsDiscard( Objects => ['PostMaster::Filter'] );
$PostMasterFilter = $Kernel::OM->Get('PostMaster::Filter');

for my $Test (@Tests) {
    for my $Type (qw(Config DB)) {

        if ( $Type eq 'DB' ) {
            $PostMasterFilter->FilterAdd(
                Name           => $Test->{Name},
                StopAfterMatch => 0,
                ValidID        => 1,
                UserID         => 1,
                %{$Test},
            );
        }
        else {
            $Kernel::OM->Get('Config')->Set(
                Key   => 'PostMaster::PreFilterModule###' . $Test->{Name},
                Value => {
                    %{$Test},
                    Module => 'Kernel::System::PostMaster::Filter::Match',
                },
            );
        }

        my @Return;
        {
            my $PostMasterObject = Kernel::System::PostMaster->new(
                Email => \$Test->{Email},
            );

            @Return = $PostMasterObject->Run();
            @Return = @{ $Return[0] || [] };
        }

        $Self->Is(
            $Return[0] || 0,
            1,
            "#Filter $Type Run() - NewTicket",
        );
        $Self->True(
            $Return[1] || 0,
            "#Filter $Type Run() - NewTicket/TicketID",
        );

        # new/clear ticket object
        $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

        my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
            TicketID      => $Return[1],
            DynamicFields => 1,
        );

        TEST:
        for my $TestCheck ($Test) {
            next TEST if !$TestCheck->{Check};
            for my $Key ( sort keys %{ $TestCheck->{Check} } ) {
                if ( $Key =~ /^DynamicField_/ && $Test->{Check}->{$Key} ) {
                    $Self->IsDeeply(
                        $Ticket{$Key},
                        $TestCheck->{Check}->{$Key},
                        "#Filter $Type Run('$TestCheck->{Name}') - $Key",
                    );
                }
                else {
                    $Self->Is(
                        $Ticket{$Key},
                        $TestCheck->{Check}->{$Key},
                        "#Filter $Type Run('$TestCheck->{Name}') - $Key",
                    );
                }
            }
        }

        # delete ticket
        my $Delete = $Kernel::OM->Get('Ticket')->TicketDelete(
            TicketID => $Return[1],
            UserID   => 1,
        );
        $Self->True(
            $Delete || 0,
            "#Filter $Type TicketDelete()",
        );

        # remove filter
        for my $Test (@Tests) {
            if ( $Type eq 'DB' ) {
                $PostMasterFilter->FilterDelete( Name => $Test->{Name} );
            }
            else {
                $Kernel::OM->Get('Config')->Set(
                    Key   => 'PostMaster::PreFilterModule###' . $Test->{Name},
                    Value => undef,
                );
            }
        }
    }
}

# revert changes to dynamic fields
for my $DynamicField (@DynamicFieldUpdate) {
    my $SuccessUpdate = $Kernel::OM->Get('DynamicField')->DynamicFieldUpdate(
        Reorder => 0,
        UserID  => 1,
        %{$DynamicField},
    );
    $Self->True(
        $SuccessUpdate,
        "Reverted changes on ValidID for $DynamicField->{Name} field.",
    );
}

for my $DynamicFieldID (@DynamicfieldIDs) {

    # delete the dynamic field
    my $FieldDelete = $Kernel::OM->Get('DynamicField')->DynamicFieldDelete(
        ID     => $DynamicFieldID,
        UserID => 1,
    );
    $Self->True(
        $FieldDelete,
        "Deleted dynamic field with id $DynamicFieldID.",
    );
}

# test X-KIX-(Owner|Responsible)
my $Login = $Helper->TestUserCreate(
    Roles => [ 'Ticket Agent' ],
);
my $UserID = $Kernel::OM->Get('User')->UserLookup( UserLogin => $Login );

my %OwnerResponsibleTests = (
    Owner => {
        File  => 'Owner',
        Check => {
            Owner => $Login,
        },
    },
    OwnerID => {
        File  => 'OwnerID',
        Check => {
            OwnerID => $UserID,
        },
    },
    Responsible => {
        File  => 'Responsible',
        Check => {
            Responsible => $Login,
        },
    },
    ResponsibleID => {
        File  => 'ResponsibleID',
        Check => {
            ResponsibleID => $UserID,
        },
    },
);

for my $Test ( sort keys %OwnerResponsibleTests ) {

    my $FileSuffix = $OwnerResponsibleTests{$Test}->{File};
    my $Location   = $Kernel::OM->Get('Config')->Get('Home')
        . "/scripts/test/system/sample/PostMaster/PostMaster-Test-$FileSuffix.box";

    my $ContentRef = $Kernel::OM->Get('Main')->FileRead(
        Location => $Location,
        Mode     => 'binmode',
        Result   => 'ARRAY',
    );

    for my $Line ( @{$ContentRef} ) {
        $Line =~ s{ ^ (X-KIX-(?:Owner|Responsible):) .*? $ }{$1$Login}x;
        $Line =~ s{ ^ (X-KIX-(?:Owner|Responsible)ID:) .*? $ }{$1$UserID}x;
    }

    my $PostMasterObject = Kernel::System::PostMaster->new(
        Email => $ContentRef,
    );

    my @Return = $PostMasterObject->Run();
    @Return = @{ $Return[0] || [] };

    $Self->Is(
        $Return[0] || 0,
        1,
        $Test . ' Run() - NewTicket',
    );

    $Self->True(
        $Return[1],
        $Test . ' Run() - NewTicket/TicketID',
    );

    # new/clear ticket object
    $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID      => $Return[1],
        DynamicFields => 0,
    );

    for my $Field ( sort keys %{ $OwnerResponsibleTests{$Test}->{Check} } ) {
        $Self->Is(
            $Ticket{$Field},
            $OwnerResponsibleTests{$Test}->{Check}->{$Field},
            $Test . ' Check Field - ' . $Field,
        );
    }
}

# rollback transaction on database
$Helper->Rollback();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
