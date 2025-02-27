# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Migration::KIX17::FAQ::Item;

use strict;
use warnings;

use POSIX;
use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Installation::Migration::KIX17::Common
);

our @ObjectDependencies = (
    'Config',
    'DB',
    'Log',
);

=item Describe()

describe what is supported and what is required

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    return {
        Supports => [
            'faq_item'
        ],
        DependsOnType => [
            'customer_user',
        ],
        Depends => {
            'category_id' => 'faq_category',
            'created_by'  => 'users',
            'changed_by'  => 'users',
        }
    }
}

=item Run()

create a new item in the DB

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get source data
    my $SourceData = $Self->GetSourceData(Type => 'faq_item');

    # bail out if we don't have something to todo
    return if !IsArrayRefWithData($SourceData);

    my $LangData      = $Self->GetSourceData(Type => 'faq_language', NoProgress => 1);
    my $StateData     = $Self->GetSourceData(Type => 'faq_state', NoProgress => 1);
    my $StateTypeData = $Self->GetSourceData(Type => 'faq_state_type', NoProgress => 1);

    # map language
    $Self->{Languages} = { map { $_->{id} => $_->{name} } @{$LangData} };

    $Self->{DefaultUsedLanguages} = { map { $_ => 1 } keys %{$Kernel::OM->Get('Config')->Get('DefaultUsedLanguages')} };

    # map state to statetype
    $Self->{StateTypes} =  { map { $_->{id} => $_->{name} } @{$StateTypeData} };
    $Self->{States} = { map { $_->{id} => $Self->{StateTypes}->{$_->{type_id}} } @{$StateData} };

    $Self->InitProgress(Type => $Param{Type}, ItemCount => scalar(@{$SourceData}));

    return $Self->_RunParallel(
        $Self->{WorkerSubRef} || \&_Run,
        Items => $SourceData,
        %Param,
    );
}

sub _Run {
    my ( $Self, %Param ) = @_;
    my $Result;

    my $Item = $Param{Item};

    # prepare language
    $Item->{language} = $Self->{Languages}->{$Item->{f_language_id}};

    # prepare visibility
    $Item->{visibility} = $Self->{States}->{$Item->{state_id}};
    $Item->{visibility} = 'external' if $Item->{visibility} eq 'public';

    # check if this object is already mapped
    my $MappedID = $Self->GetOIDMapping(
        ObjectType     => 'faq_item',
        SourceObjectID => $Item->{id}
    );
    if ( $MappedID ) {
        return 'Ignored';
    }

    # check if this item already exists (i.e. some initial data)
    my $ID = $Self->Lookup(
        Table        => 'faq_item',
        PrimaryKey   => 'id',
        Item         => $Item,
        RelevantAttr => [
            'f_name'
        ]
    );

    if ( !$ID ) {
        # insert row
        $ID = $Self->Insert(
            Table          => 'faq_item',
            PrimaryKey     => 'id',
            Item           => $Item,
            AutoPrimaryKey => 1,
        );
    }

    if ( $ID ) {
        $Self->_MigrateVoting(
            ItemID       => $ID,
            SourceItemID => $Item->{id},
        );
        $Self->_MigrateHistory(
            ItemID       => $ID,
            SourceItemID => $Item->{id},
        );
        $Self->_MigrateAttachments(
            ItemID       => $ID,
            Item         => $Item,
            SourceItemID => $Item->{id},
        );

        # check if the given language exists
        if ( !$Self->{DefaultUsedLanguages}->{$Item->{language}} ) {
            # add language to SysConfig
            my %OptionData = $Kernel::OM->Get('SysConfig')->OptionGet(
                Name => 'DefaultUsedLanguages',
            );

            $OptionData{Default}->{$Item->{language}} = $Item->{language};

            # update option
            my $Success = $Kernel::OM->Get('SysConfig')->OptionUpdate(
                %OptionData,
                UserID  => 1
            );

            if ( !$Success ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Could not update SysConfig option \"DefaultUsedLanguages\" for FAQ item $ID"
                );
            }
        }

        $Result = 'OK';
    }
    else {
        $Result = 'Error';
    }

    return $Result;
}

sub _MigrateVoting {
    my ( $Self, %Param ) = @_;
    my %Result;

    # check needed params
    for my $Needed (qw(ItemID SourceItemID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get source data
    my $SourceData = $Self->GetSourceData(
        Type       => 'faq_voting',
        Where      => "item_id = $Param{SourceItemID}",
        References => {
            'item_id' => 'faq_item',
        },
        NoProgress => 1
    );

    # bail out if we don't have something to todo
    return %Result if !IsArrayRefWithData($SourceData);

    foreach my $Item ( @{$SourceData} ) {

        # check if this object is already mapped
        my $MappedID = $Self->GetOIDMapping(
            ObjectType     => 'faq_voting',
            SourceObjectID => $Item->{id}
        );
        next if $MappedID;

        # prepare create_by by interface
        my $UserID;
        # agent interface
        if ( $Item->{interface} == 1 ) {
            $UserID = $Self->GetOIDMapping(
                ObjectType     => 'users',
                SourceObjectID => $Item->{created_by},
            );
        }
        # customer interface
        elsif ( $Item->{interface} == 2 ) {
            # check for user with the same login
            $UserID = $Kernel::OM->Get('User')->UserLookup(
                UserLogin => $Item->{created_by},
                Silent    => 1
            );
        }
        # ignore other interfaces
        else {
            next;
        }

        if ( !$UserID ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Dependency for \"created_by\" cannot be resolved (users: $Item->{created_by})!"
            );

            $Result{Error}++;

            next;
        }
        # set found user for create_by
        else {
            $Item->{created_by} = $UserID;
        }


        # check if this item already exists (i.e. some initial data)
        my $ID = $Self->Lookup(
            Table        => 'faq_voting',
            PrimaryKey   => 'id',
            Item         => $Item,
            RelevantAttr => [
                'item_id',
                'created_by'
            ]
        );

        if ( !$ID ) {
            # remove irrelevant data
            delete $Item->{interface};
            delete $Item->{ip};

            # normalize rating
            $Item->{rate} = ceil($Item->{rate} * 5 / 100);

            # insert row
            $ID = $Self->Insert(
                Table          => 'faq_voting',
                PrimaryKey     => 'id',
                Item           => $Item,
                AutoPrimaryKey => 1,
            );
        }

        if ( $ID ) {
            $Result{OK}++;
        }
        else {
            $Result{Error}++;
        }
    }

    return %Result;
}

sub _MigrateHistory {
    my ( $Self, %Param ) = @_;
    my %Result;

    # check needed params
    for my $Needed (qw(ItemID SourceItemID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get source data
    my $SourceData = $Self->GetSourceData(
        Type       => 'faq_history',
        Where      => "item_id = $Param{SourceItemID}",
        References => {
            'item_id'    => 'faq_item',
            'created_by' => 'users',
            'changed_by' => 'users'
        },
        NoProgress => 1
    );

    # bail out if we don't have something to todo
    return %Result if !IsArrayRefWithData($SourceData);

    foreach my $Item ( @{$SourceData} ) {
        # insert row
        my $ID = $Self->Insert(
            Table          => 'faq_history',
            PrimaryKey     => 'id',
            Item           => $Item,
            AutoPrimaryKey => 1,
        );
        if ( $ID ) {
            $Result{OK}++;
        }
        else {
            $Result{Error}++;
        }
    }

    return %Result;
}

sub _MigrateAttachments {
    my ( $Self, %Param ) = @_;
    my %Result;

    # check needed params
    for my $Needed (qw(ItemID Item SourceItemID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $FQDN = $Kernel::OM->Get('Config')->Get('FQDN');
    if (IsHashRefWithData($FQDN)) {
        $FQDN = $FQDN->{Backend}
    }

    # extract
    my %FAQItem = %{$Param{Item}};
    my %InlineAttachments;
    foreach my $Field ( qw(f_field1 f_field2 f_field3 f_field4 f_field5 f_field6) ) {
        while ( $FAQItem{$Field} && $FAQItem{$Field} =~ /src="\/(.*?Action=AgentFAQZoom;Subaction=DownloadAttachment;.*?;FileID=(\d+))"/g ) {
            my $CID = $InlineAttachments{$2};
            if ( !$CID ) {
                $CID = 'pasted.' . time() . '.' . int(rand(1000000)) . '@' . $FQDN;
                $InlineAttachments{$2} = $CID;
            }
            $FAQItem{$Field} =~ s/\/\Q$1\E/cid:$CID/gmi;
        }
    }

    # get source data
    my $SourceData = $Self->GetSourceData(
        Type       => 'faq_attachment',
        ObjectID   => $Param{SourceItemID},
        References => {
            'faq_id'     => 'faq_item',
            'created_by' => 'users',
            'changed_by' => 'users'
        },
        NoProgress => 1
    );

    # bail out if we don't have something to todo
    return %Result if !IsArrayRefWithData($SourceData);

    foreach my $Item ( @{$SourceData} ) {
        $Item->{disposition} = 'inline' if $Item->{inlineattachment};
        $Item->{content_id}  = $InlineAttachments{$Item->{id}} ? "<$InlineAttachments{$Item->{id}}>" : '';
        # decode attachment content, when database supports direct blob
        if ( $Kernel::OM->Get('DB')->GetDatabaseFunction('DirectBlob') ) {
            $Item->{content} = MIME::Base64::decode_base64($Item->{content});
        }
        
        if ( $Item->{content_type} =~ /\s+;/ ) {
            $Item->{content_type} = split(/\s+;/, $Item->{content_type}, 1);
        }
        delete $Item->{inlineattachment};

        # insert row
        my $ID = $Self->Insert(
            Table          => 'faq_attachment',
            PrimaryKey     => 'id',
            Item           => $Item,
            AutoPrimaryKey => 1,
        );
        if ( $ID ) {
            # update faq item
            my $Result = $Self->Update(
                Table      => 'faq_item',
                PrimaryKey => 'id',
                Item       => {
                    %FAQItem,
                    id => $Param{ItemID}
                }
            );
            if ( !$Result ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Could not update FAQ item $Param{ItemID}"
                );
            }
            $Result{OK}++;
        }
        else {
            $Result{Error}++;
        }
    }

    return %Result;
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
