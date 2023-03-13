# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Auth::Sync::LDAP;

use strict;
use warnings;

use Net::LDAP;
use Net::LDAP::Util qw(escape_filter_value);
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Encode',
    'Log',
    'User',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # Debug 0=off 1=on
    $Self->{Debug}                        = $Param{Config}->{Debug} || 0;
    $Self->{Die}                          = $Param{Config}->{Die} || 1;
    $Self->{Host}                         = $Param{Config}->{Host} || '';
    $Self->{BaseDN}                       = $Param{Config}->{BaseDN} || '';
    $Self->{UID}                          = $Param{Config}->{UID} || 'uid';
    $Self->{SearchUserDN}                 = $Param{Config}->{SearchUserDN} || '';
    $Self->{SearchUserPw}                 = $Param{Config}->{SearchUserPw} || '';
    $Self->{GroupDN}                      = $Param{Config}->{GroupDN} || '';
    $Self->{AccessAttr}                   = $Param{Config}->{AccessAttr} || 'memberUid';
    $Self->{UserAttr}                     = $Param{Config}->{UserAttr} || 'DN';
    $Self->{DestCharset}                  = $Param{Config}->{Charset} || 'utf-8';
    $Self->{AlwaysFilter}                 = $Param{Config}->{AlwaysFilter} || '';
    $Self->{Params}                       = $Param{Config}->{Params} || {};
    $Self->{Config}                       = $Param{Config}->{Config} || {};
    $Self->{ContactUserSync}              = $Param{Config}->{ContactUserSync} || {};
    $Self->{GroupDNBasedUsageContextSync} = $Param{Config}->{GroupDNBasedUsageContextSync} || {};
    $Self->{GroupDNBasedRoleSync}         = $Param{Config}->{GroupDNBasedRoleSync} || {};
    $Self->{AttributeBasedRoleSync}       = $Param{Config}->{AttributeBasedRoleSync} || {};
    $Self->{UnknownOrgIDFallback}         = $Param{Config}->{UnknownOrgIDFallback} || "1";

    $Self->{EmailUniqueCheck}             = $Kernel::OM->Get('Config')->Get('ContactEmailUniqueCheck');

    return $Self;
}

sub Sync {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{User} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need User!'
        );
        return;
    }
    $Param{User} = $Self->_ConvertTo( $Param{User}, 'utf-8' );

    my $RemoteAddr = $ENV{REMOTE_ADDR} || 'Got no REMOTE_ADDR env!';

    # remove leading and trailing spaces
    $Param{User} =~ s{ \A \s* ( [^\s]+ ) \s* \z }{$1}xms;

    # just in case for debug!
    if ( $Self->{Debug} > 0 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "User: \"$Param{User}\" tried to sync (REMOTE_ADDR: $RemoteAddr)",
        );
    }

    # ldap connect and bind (maybe with SearchUserDN and SearchUserPw)
    my $LDAP = Net::LDAP->new( $Self->{Host}, %{ $Self->{Params} } );
    if ( !$LDAP ) {
        if ( $Self->{Die} ) {
            die "Can't connect to $Self->{Host}: $@";
        }

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't connect to $Self->{Host}: $@",
        );
        return;
    }
    my $Result;
    if ( $Self->{SearchUserDN} && $Self->{SearchUserPw} ) {
        $Result = $LDAP->bind(
            dn       => $Self->{SearchUserDN},
            password => $Self->{SearchUserPw}
        );
    }
    else {
        $Result = $LDAP->bind();
    }
    if ( $Result->code() ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'First bind failed! ' . $Result->error(),
        );
        return;
    }

    # user quote
    my $Filter = "($Self->{UID}=" . escape_filter_value($Param{User}) . ')';

    # prepare filter
    if ( $Self->{AlwaysFilter} ) {
        $Filter = "(&$Filter$Self->{AlwaysFilter})";
    }

    # perform user search
    $Result = $LDAP->search(
        base   => $Self->{BaseDN},
        filter => $Filter,
    );
    if ( $Result->code() ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Search failed! ($Self->{BaseDN}) filter='$Filter' " . $Result->error(),
        );
        return;
    }

    # get whole user dn
    my $UserDN;
    for my $Entry ( $Result->all_entries() ) {
        $UserDN = $Entry->dn();
    }

    # log if there is no LDAP user entry
    if ( !$UserDN ) {

        # failed login note
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "User: \"$Param{User}\" sync failed, no LDAP entry found!"
                . "BaseDN='$Self->{BaseDN}', Filter='$Filter', (REMOTE_ADDR: $RemoteAddr).",
        );

        # take down session
        $LDAP->unbind();
        return;
    }

    # get needed objects
    my $UserObject = $Kernel::OM->Get('User');
    my $ConfigObject = $Kernel::OM->Get('Config');
    my $ContactObject = $Kernel::OM->Get('Contact');
    my $OrganisationObject = $Kernel::OM->Get('Organisation');

    my $ContactID;

    # get current user id
    my $UserID = $UserObject->UserLookup(
        UserLogin => $Param{User},
        Silent    => 1,
    );

    if ( !$UserID ) {
        # create user
        $UserID = $UserObject->UserAdd(
            UserLogin    => $Param{User},
            ValidID      => 1,
            ChangeUserID => 1,
        );
        if ( !$UserID ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't create user \"$Param{User}\" ($UserDN) in RDBMS!",
            );

            # take down session
            $LDAP->unbind();
            return;
        }

        $Kernel::OM->Get('Log')->Log(
            LogPrefix => 'Kernel::System::Auth::Sync::LDAP',
            Priority  => 'notice',
            Message   => "Local user for ldap user \"$Param{User}\" ($UserDN) created in RDBMS.",
        );
    }

    # variable to store role permissions from ldap
    my %RolesFromLDAP;

    # get RoleObject
    my $RoleObject = $Kernel::OM->Get('Role');

    # get system roles and create lookup
    my %SystemRoles = $RoleObject->RoleList(Valid => 1);
    my %SystemRolesByName = reverse %SystemRoles;

    my %UserContextFromLDAP;

    # sync contact from ldap
    my %SyncContact;
    if ( IsHashRefWithData($Self->{ContactUserSync}) ) {

        # NOTE: the following can be found in KIXPro::Kernel::System::Automation::MacroAction::Synchronisation::LDAP2Contact
        # please check any modifications done here, there as well until refactored
        for my $Entry ( $Result->all_entries() ) {

            ATTRIBUTE_KEY:
            for my $Key ( sort keys %{$Self->{ContactUserSync}} ) {

                my @ValueArr = qw{};
                my $Value = "";
                my $AttributeNames = $Self->{ContactUserSync}->{$Key};
                if ( ref $AttributeNames ne 'ARRAY' ) {
                    $AttributeNames = [$AttributeNames];
                }


              ATTRIBUTE_NAME:
                for my $AttributeName ( @{$AttributeNames} ) {
                    # set a fixed value...
                    if ( $AttributeName =~ /^SET:/i ) {
                        $Value = substr( $AttributeName, 4 );
                        $Value =~ s/^\s+|\s+$//g;
                    }
                    # set a value concatenation of multiple attributes
                    # LDAP attributes are marked with curly brackets
                    elsif ( $AttributeName =~ /^CONCAT\:(.+)$/i ) {
                        $Value = $1;
                        $Value =~ s/^\s+|\s+$//g;
                        while ( $Value =~ /\{(.+?)\}/) {
                            $AttributeName = $1;
                            my $ValuePart = $Entry->get_value($AttributeName) || '';
                            $ValuePart =~ s/^\s+|\s+$//g;
                            $Value =~s/\{(.+?)\}/$ValuePart/;
                        }
                    }
                    # just set the attribute...
                    elsif ( $Entry->get_value($AttributeName) ) {
                        $Value = $Entry->get_value($AttributeName);
                        $Value =~ s/^\s+|\s+$//g;
                    }
                    # set empty if no value can be retrieved or the attribute is not available..
                    else {
                        $Value = "";
                    }

                    # ensure proper encoding, i.e. utf-8
                    $Value = $Self->_ConvertFrom( $Value, 'utf-8', );

                    # "special treatment"
                    # do we have to look up organisation id?
                    if ( $Key eq "PrimaryOrganisationID" || $Key eq "OrganisationIDs" ) {
                        my $FoundOrgID = "";
                        if ( $AttributeName !~ /^SET:/ ) {
                            $FoundOrgID = $OrganisationObject->OrganisationLookup(
                                Number => $Value,
                                Silent => 1,
                            );
                            if ( $FoundOrgID ) {
                                $Value = $FoundOrgID;
                            }
                        }
                        if ( !$FoundOrgID ) {
                            $FoundOrgID = $OrganisationObject->OrganisationLookup(
                                ID     => $Value,
                                Silent => 1,
                            );
                            if ( !$FoundOrgID ) {
                                $Value = $Self->{UnknownOrgIDFallback};
                            }
                        }
                    }

                    # accept multiple attributes only for OrganisationIDs and
                    # enforce array structure for attribute OrganisationIDs...
                    # (NOTE: that might work for array DFs one day)
                    if ( $Key eq "OrganisationIDs" ) {
                        push(@ValueArr, $Value);
                        last ATTRIBUTE_NAME if ( ref($Self->{ContactUserSync}->{$Key}) ne 'ARRAY' );
                    }
                    else {
                        $SyncContact{$Key} = $Value;
                        last ATTRIBUTE_NAME;
                    }
                }

                # NOTE this is already OR because it might work for array DFs one day
                if ( $Key eq "OrganisationIDs" || ref($Self->{ContactUserSync}->{$Key}) eq 'ARRAY' ) {
                    $SyncContact{$Key} = \@ValueArr;
                }

            }
        }

        # sync contact
        if ( IsHashRefWithData(\%SyncContact) ) {
            # set fallback org id if necessary
            $SyncContact{PrimaryOrganisationID} = $SyncContact{PrimaryOrganisationID} || $Self->{UnknownOrgIDFallback} || 1;
            my %ContactData;
            # lookup the contact

            if ( $SyncContact{Email} && $Self->{EmailUniqueCheck} ) {
                $ContactID = $ContactObject->ContactLookup(
                    Email  => $SyncContact{Email},
                    Silent => 1,
                );
            }
            if ( !$ContactID && $SyncContact{UserLogin} ) {
                $ContactID = $ContactObject->ContactLookup(
                    UserLogin => $SyncContact{UserLogin},
                    Silent    => 1,
                );
            }

            %ContactData = $ContactObject->ContactGet(
                ID => $ContactID,
            );

            # check if the contact is assigned to another user
            if ( $ContactData{AssignedUserID} && $ContactData{AssignedUserID} != $UserID ) {
                $Kernel::OM->Get('Log')->Log(
                    LogPrefix => 'Kernel::System::Auth::Sync::LDAP',
                    Priority  => 'error',
                    Message   => "Can't assign user \"$Param{User}\" ($UserDN) to contact ($ContactData{ID}) in RDBMS! Contact is already assigned to user with ID ($ContactData{AssignedUserID}).",
                );

                # take down session
                $LDAP->unbind();
                return;
            }

            if ( !%ContactData ) {
                # create new contact
                $ContactID = $ContactObject->ContactAdd(
                    %SyncContact,
                    AssignedUserID => $UserID,
                    ValidID        => 1,
                    UserID         => 1,
                );
                if ( !$ContactID ) {
                    $Kernel::OM->Get('Log')->Log(
                        LogPrefix => 'Kernel::System::Auth::Sync::LDAP',
                        Priority  => 'error',
                        Message   => "Unable to create contact for user \"$Param{User}\" ($UserDN)!",
                    );
                }
                else {
                    $Kernel::OM->Get('Log')->Log(
                        LogPrefix => 'Kernel::System::Auth::Sync::LDAP',
                        Priority  => 'notice',
                        Message   => "Contact for user \"$Param{User}\" ($UserDN) created in RDBMS.",
                    );
                }
            }
            else {
                # update existing contact

                # get user data
                %ContactData = $ContactObject->ContactGet(
                    UserID => $UserID,
                );
                $ContactID = $ContactData{ID};

                # check for changes on contact
                my $AttributeChange = 0;
                ATTRIBUTE:
                for my $Attribute ( sort keys %SyncContact ) {
                    next ATTRIBUTE if ( $SyncContact{$Attribute} && $ContactData{$Attribute} && $SyncContact{$Attribute} eq $ContactData{$Attribute} );
                    $AttributeChange = 1;
                    last ATTRIBUTE;
                }
                $SyncContact{Email} = ( !$SyncContact{Email} && $ContactData{Email} ) ? $ContactData{Email} : $SyncContact{Email};

                if ( $AttributeChange ) {
                    my $Result = $ContactObject->ContactUpdate(
                        %ContactData,
                        %SyncContact,
                        UserID         => 1,
                        AssignedUserID => $UserID,
                    );
                    if ( !$Result ) {
                        $Kernel::OM->Get('Log')->Log(
                            LogPrefix => 'Kernel::System::Auth::Sync::LDAP',
                            Priority  => 'error',
                            Message   => "Unable to update contact for user \"$Param{User}\" ($UserDN)!",
                        );
                    }
                    else {
                        $Kernel::OM->Get('Log')->Log(
                            LogPrefix => 'Kernel::System::Auth::Sync::LDAP',
                            Priority  => 'notice',
                            Message   => "Updated contact for user \"$Param{User}\" ($UserDN) in RDBMS.",
                        );
                    }
                }
            }
            if ( $ContactID ) {
                # get dynamic field list
                my $DynamicFieldList = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
                    Valid      => 1,
                    ObjectType => ['Contact'],
                );
                my %DynamicFieldConfig = map { $_->{Name} => $_ } @{$DynamicFieldList};

                # set Dynamic Fields
                ATTRIBUTE:
                foreach my $Attribute ( sort keys %SyncContact ) {
                    next ATTRIBUTE if $Attribute !~ /^DynamicField_(.*?)$/g;
                    my $DynamicFieldName = $1;

                    next ATTRIBUTE if !IsHashRefWithData($DynamicFieldConfig{$DynamicFieldName});
                    next ATTRIBUTE if $DynamicFieldConfig{$DynamicFieldName}->{InternalField};

                    # set value
                    my $Success = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
                        DynamicFieldConfig => $DynamicFieldConfig{$DynamicFieldName},
                        ObjectID           => $ContactID,
                        Value              => $SyncContact{$Attribute},
                        UserID             => 1,
                    );

                    if ( !$Success ) {
                        $Kernel::OM->Get('Log')->Log(
                            LogPrefix => 'Kernel::System::Auth::Sync::LDAP',
                            Priority  => 'error',
                            Message   => "Unable to update value for dynamic field \"$DynamicFieldName\" (contact $ContactID).",
                        );
                    }
                }
            }

        }
    }

    # GroupDN based role sync...
    if ( IsHashRefWithData($Self->{GroupDNBasedRoleSync}) ) {

        # read and remember roles from ldap
        GROUPDN:
        for my $GroupDN ( sort keys %{$Self->{GroupDNBasedRoleSync}} ) {

            # search if we're allowed to
            my $Filter;
            if ( $Self->{UserAttr} eq 'DN' ) {
                $Filter = "($Self->{AccessAttr}=" . escape_filter_value($UserDN) . ')';
            }
            else {
                $Filter = "($Self->{AccessAttr}=" . escape_filter_value($Param{User}) . ')';
            }
            my $Result = $LDAP->search(
                base   => $GroupDN,
                filter => $Filter,
            );
            if ( $Result->code() ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Search failed! ($GroupDN) filter='$Filter' " . $Result->error(),
                );
                next GROUPDN;
            }

            # extract it
            my $Valid;
            for my $Entry ( $Result->all_entries() ) {
                $Valid = $Entry->dn();
            }

            # log if there is no LDAP entry
            if ( !$Valid ) {

                # failed login note
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'notice',
                    Message  => "User: $Param{User} not in "
                        . "GroupDN='$GroupDN', Filter='$Filter'! (REMOTE_ADDR: $RemoteAddr).",
                );
                next GROUPDN;
            }

            # remember role permissions
            my %SyncRoles = %{$Self->{GroupDNBasedRoleSync}->{$GroupDN}};
            SYNCROLE:
            for my $SyncRole ( sort keys %SyncRoles ) {

                # only for valid roles
                if ( !$SystemRolesByName{$SyncRole} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'notice',
                        Message  => "Invalid role \"$SyncRole\" in GroupDNBasedRoleSync!"
                    );
                    next SYNCROLE;
                }

                # set/overwrite remembered permissions
                $RolesFromLDAP{ $SystemRolesByName{$SyncRole} } =
                    $SyncRoles{$SyncRole};
            }
        }
    }

    # attribute based role sync...
    if ( IsHashRefWithData($Self->{AttributeBasedRoleSync}) ) {

        # build filter
        my $Filter = "($Self->{UID}=" . escape_filter_value($Param{User}) . ')';

        # perform search
        $Result = $LDAP->search(
            base   => $Self->{BaseDN},
            filter => $Filter,
        );
        if ( $Result->code() ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Search failed! ($Self->{BaseDN}) filter='$Filter' " . $Result->error(),
            );
        }
        else {
            my %SyncConfig = %{$Self->{AttributeBasedRoleSync}};
            for my $Attribute ( sort keys %SyncConfig ) {

                my %AttributeValues = %{$SyncConfig{$Attribute}};
                ATTRIBUTEVALUE:
                for my $AttributeValue ( sort keys %AttributeValues ) {

                    for my $Entry ( $Result->all_entries() ) {

                        # Check if configured value exists in values of role attribute
                        # If yes, add sync roles to the user
                        my $GotValue;
                        my @Values = $Entry->get_value($Attribute);
                        VALUE:
                        for my $Value ( @Values ) {
                            next VALUE if $Value !~ m{ \A \Q$AttributeValue\E \z }xmsi;
                            $GotValue = 1;
                            last VALUE;
                        }
                        next ATTRIBUTEVALUE if !$GotValue;

                        # remember role permissions
                        my %SyncRoles = %{$AttributeValues{$AttributeValue}};
                        SYNCROLE:
                        for my $SyncRole ( sort keys %SyncRoles ) {

                            # only for valid roles
                            if ( !$SystemRolesByName{$SyncRole} ) {
                                $Kernel::OM->Get('Log')->Log(
                                    Priority => 'notice',
                                    Message  =>
                                        "Invalid role \"$SyncRole\" in AttributeBasedRoleSync!",
                                );
                                next SYNCROLE;
                            }

                            # set/overwrite remembered permissions
                            $RolesFromLDAP{ $SystemRolesByName{$SyncRole} } =
                                $SyncRoles{$SyncRole};
                        }
                    }
                }
            }
        }
    }


    # GroupDN based usage context sync...
    if ( IsHashRefWithData($Self->{GroupDNBasedUsageContextSync}) ) {

        # read and remember roles from ldap
        GROUPDN:
        for my $GroupDN ( sort keys %{$Self->{GroupDNBasedUsageContextSync}} ) {

            # search if we're allowed to
            my $Filter;
            if ( $Self->{UserAttr} eq 'DN' ) {
                $Filter = "($Self->{AccessAttr}=" . escape_filter_value($UserDN) . ')';
            }
            else {
                $Filter = "($Self->{AccessAttr}=" . escape_filter_value($Param{User}) . ')';
            }
            my $Result = $LDAP->search(
                base   => $GroupDN,
                filter => $Filter,
            );
            if ( $Result->code() ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Search failed! ($GroupDN) filter='$Filter' " . $Result->error(),
                );
                next GROUPDN;
            }

            # extract it
            my $Valid;
            for my $Entry ( $Result->all_entries() ) {
                $Valid = $Entry->dn();
            }

            # log if there is no LDAP entry
            if ( !$Valid ) {

                # failed login note
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'notice',
                    Message  => "User: $Param{User} not in "
                        . "GroupDN='$GroupDN', Filter='$Filter'! (REMOTE_ADDR: $RemoteAddr).",
                );
                next GROUPDN;
            }

            my %SyncContexts = %{$Self->{GroupDNBasedUsageContextSync}->{$GroupDN}};
            SYNCCONTEXT:
            for my $SyncContext ( sort keys %SyncContexts ) {

                # only for valid contexts
                if ( $SyncContext !~ /^Is(Agent|Customer)$/g ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'notice',
                        Message  => "Invalid context \"$SyncContext\" in GroupDNBasedUsageContextSync!"
                    );
                    next SYNCCONTEXT;
                }

                # ignore any positive result if we already have a negative
                next SYNCCONTEXT if exists $UserContextFromLDAP{ $SyncContext } && $UserContextFromLDAP{ $SyncContext } == 0;

                $UserContextFromLDAP{ $SyncContext } = $SyncContexts{$SyncContext};
            }
        }

        # if no GroupDN matches remove possibly assigned usage context
        for my $CurrUC ( qw(IsAgent IsCustomer) ) {
            if ( !exists($UserContextFromLDAP{ $CurrUC }) ) {
                $UserContextFromLDAP{ $CurrUC } = "0";
            }
        }
    }

    # if no GroupDN based context assignment is given, retrieve usage contexts
    # from assigned roles - remember: this is just the sync. the auth-backend
    # may be limited to a certain usage context though!
    elsif ( scalar(keys(%RolesFromLDAP)) ) {
        for my $CurrRID ( keys(%RolesFromLDAP) ) {
            my %RoleData = $RoleObject->RoleGet(ID => $CurrRID);
            if ( %RoleData && $RoleData{UsageContextList} && ref($RoleData{UsageContextList}) eq 'ARRAY' ) {
                for my $CurrContext ( @{$RoleData{UsageContextList}} ) {
                    $UserContextFromLDAP{ "Is" . $CurrContext } = "1";
                }
            }
        }
    }

    # set user context in DB
    my %User = $UserObject->GetUserData(
        UserID => $UserID
    );

    # IsCustomer/IsAgent in UserSyncMap always overwrites all other context modifications
    $UserContextFromLDAP{IsCustomer} = $SyncContact{IsCustomer} if ( exists($SyncContact{IsCustomer}) );
    $UserContextFromLDAP{IsAgent} = $SyncContact{IsAgent} if ( exists($SyncContact{IsAgent}) );

    if ( %User ) {

    # remove UserPw to avoid overwrite
    $User{UserPw} = undef if defined $User{UserPw};

        my $Success = $UserObject->UserUpdate(
            %User,
            %UserContextFromLDAP,
            ValidID      => ( $UserContextFromLDAP{IsCustomer} || $UserContextFromLDAP{IsAgent} ) ? 1 : 2,
            ChangeUserID => 1,
        );

        if ( !$Success ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to update usage context of user \"$Param{User}\" (UserID: $UserID)!",
            );
        }
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such user \"$Param{User}\"!",
        );
    }

    # compare role permissions from ldap with current user role permissions and update if necessary
    if ( %RolesFromLDAP ) {

        # cleanup all user roles
        my $Success = $RoleObject->RoleUserDelete(
            UserID             => $UserID,
            IgnoreContextRoles => 1,
        );
        if ( !$Success ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to cleanup role assignments of user \"$Param{User}\" (UserID: $UserID)!",
            );
        }

        ROLEID:
        foreach my $RoleID ( sort keys %RolesFromLDAP ) {
            next ROLEID if !$RolesFromLDAP{$RoleID};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "User: \"$Param{User}\" assigning role \"$SystemRoles{$RoleID}\"!",
            );

            # assign role
            my $Result = $RoleObject->RoleUserAdd(
                AssignUserID => $UserID,
                RoleID       => $RoleID,
                UserID       => 1,
            );
            if ( !$Result ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to assign role \"$SystemRoles{$RoleID}\" to user \"$Param{User}\" (UserID: $UserID)!",
                );
            }
        }
    }

    # take down session
    $LDAP->unbind();

    return $Param{User};
}

sub _ConvertTo {
    my ( $Self, $Text, $Charset ) = @_;

    return if !defined $Text;

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    if ( !$Charset || !$Self->{DestCharset} ) {
        $EncodeObject->EncodeInput(\$Text);
        return $Text;
    }

    # convert from input charset ($Charset) to directory charset ($Self->{DestCharset})
    return $EncodeObject->Convert(
        Text => $Text,
        From => $Charset,
        To   => $Self->{DestCharset},
    );
}

sub _ConvertFrom {
    my ( $Self, $Text, $Charset ) = @_;

    return if !defined $Text;

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    if ( !$Charset || !$Self->{DestCharset} ) {
        $EncodeObject->EncodeInput( \$Text );
        return $Text;
    }

    # convert from directory charset ($Self->{DestCharset}) to input charset ($Charset)
    return $EncodeObject->Convert(
        Text => $Text,
        From => $Self->{DestCharset},
        To   => $Charset,
    );
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
