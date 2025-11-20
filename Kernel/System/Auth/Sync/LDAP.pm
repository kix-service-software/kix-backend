# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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
    'Contact',
    'LDAPUtils',
    'Log',
    'Organisation',
    'Role',
    'User',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # Debug 0=off 1=on
    $Self->{Debug}                        = $Param{Config}->{Debug} || 0;
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
    $Param{User} = $Kernel::OM->Get('LDAPUtils')->Convert(
        Text => $Param{User},
        From => 'utf-8',
        To   => $Self->{DestCharset},
    );

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
    my $Filter = "($Self->{UID}=" . escape_filter_value( $Param{User} ) . ')';

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
        $LDAP->disconnect();
        return;
    }

    # get system roles and create lookup
    my %SystemRoles       = $Kernel::OM->Get('Role')->RoleList(Valid => 1);
    my %SystemRolesByName = reverse %SystemRoles;

    my $UserID = $Kernel::OM->Get('User')->UserLookup(
        UserLogin => $Param{User},
        Silent    => 1,
    );

    my $ContactID;

    # sync contact from ldap
    my $SyncContactRef;
    if ( IsHashRefWithData( $Self->{ContactUserSync} ) ) {

        $SyncContactRef = $Kernel::OM->Get('LDAPUtils')->ApplyContactMappingToLDAPResult(
            LDAPSearch           => $Result,
            Mapping              => $Self->{ContactUserSync},
            LDAPCharset          => $Self->{DestCharset},
            FallbackUnknownOrgID => $Self->{UnknownOrgIDFallback},
        );

        # sync contact
        if ( IsHashRefWithData( $SyncContactRef ) ) {
            # set fallback org id if necessary
            $SyncContactRef->{PrimaryOrganisationID} = $SyncContactRef->{PrimaryOrganisationID} || $Self->{UnknownOrgIDFallback} || 1;

            # lookup the contact
            if ( $SyncContactRef->{Email} && $Self->{EmailUniqueCheck} ) {
                $ContactID = $Kernel::OM->Get('Contact')->ContactLookup(
                    Email  => $SyncContactRef->{Email},
                    Silent => 1,
                );
            }
            if ( !$ContactID && $SyncContactRef->{UserLogin} ) {
                $ContactID = $Kernel::OM->Get('Contact')->ContactLookup(
                    UserLogin => $SyncContactRef->{UserLogin},
                    Silent    => 1,
                );
            }

            my %ContactData;
            if ( $ContactID ) {
                %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
                    ID => $ContactID,
                );
            }

            # if the UserLogin was changed, we cannot find the user by UserLogin. We had to look the user up by email.
            # this only works with enabled EmailUniqueCheck!
            $UserID = $SyncContactRef->{UserLogin} && !$UserID && $ContactData{AssignedUserID} ? $ContactData{AssignedUserID} : $UserID;

            if (
                $ContactData{AssignedUserID}
                && $UserID
                && $ContactData{AssignedUserID} != $UserID
            ) {
                $Kernel::OM->Get('Log')->Log(
                    LogPrefix => 'Kernel::System::Auth::Sync::LDAP',
                    Priority  => 'error',
                    Message   => "Can't assign user \"$Param{User}\" ($UserDN) to contact ($ContactData{ID}) in RDBMS! Contact is already assigned to user with ID ($ContactData{AssignedUserID}).",
                );

                # take down session
                $LDAP->unbind();
                $LDAP->disconnect();

                return;
            }

            # create new contact
            if ( !%ContactData ) {
                $ContactID = $Kernel::OM->Get('Contact')->ContactAdd(
                    %{ $SyncContactRef },
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
            # update existing contact
            else {
                $ContactID = $ContactData{ID};

                # synced contacts are always valid
                $SyncContactRef->{ValidID} = 1;

                # check for changes on contact
                my $AttributeChange = 0;
                ATTRIBUTE:
                for my $Attribute ( keys( %{ $SyncContactRef } ) ) {
                    next ATTRIBUTE if (
                        $SyncContactRef->{ $Attribute }
                        && $ContactData{ $Attribute }
                        && $SyncContactRef->{ $Attribute } eq $ContactData{ $Attribute }
                    );

                    $AttributeChange = 1;

                    last ATTRIBUTE;
                }
                $SyncContactRef->{Email} = ( !$SyncContactRef->{Email} && $ContactData{Email} ) ? $ContactData{Email} : $SyncContactRef->{Email};

                if ( $AttributeChange ) {
                    my $Result = $Kernel::OM->Get('Contact')->ContactUpdate(
                        %ContactData,
                        %{ $SyncContactRef },
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

                if ( $SyncContactRef->{ImgThumbNail} ) {
                    # detect MIME type of thumbnail-content
                    my $DetectedContentType = $Kernel::OM->Get('LDAPUtils')->DetectMIMETypeFromBase64(
                        Content => $SyncContactRef->{ImgThumbNail},
                    );

                    if ( !$DetectedContentType ) {
                        $Kernel::OM->Get('Log')->Log(
                            LogPrefix => 'Kernel::System::Auth::Sync::LDAP',
                            Priority  => 'error',
                            Message   => "Unable to detect MIME type for object icon (contact $ContactID).",
                        );
                    }
                    else {
                        # check for current ObjectIcon...
                        my $ObjIDs = $Kernel::OM->Get('ObjectIcon')->ObjectIconList(
                            Object   => 'Contact',
                            ObjectID => $ContactID,
                        );
                        my $ObjectIconID = 0;
                        if( $ObjIDs && IsArrayRefWithData($ObjIDs) ) {
                            $ObjectIconID = $ObjIDs->[0] || '';
                        }

                        # IF NOT EXISTING - add new ObjectIcon...
                        my $ObjIconResult = 0;
                        if( $ObjectIconID ) {
                            $ObjIconResult = $Kernel::OM->Get('ObjectIcon')->ObjectIconUpdate(
                                ID              => $ObjectIconID,
                                Object          => 'Contact',
                                ObjectID        => $ContactID,
                                ContentType     => $DetectedContentType,
                                Content         => $SyncContactRef->{ImgThumbNail},
                                UserID          => 1,
                            );
                        }
                        # IF EXISTING - update ObjectIcon...
                        else {
                            $ObjIconResult = $Kernel::OM->Get('ObjectIcon')->ObjectIconAdd(
                                Object          => 'Contact',
                                ObjectID        => $ContactID,
                                ContentType     => $DetectedContentType,
                                Content         => $SyncContactRef->{ImgThumbNail},
                                UserID          => 1,
                            );
                        }
                        if (!$ObjIconResult) {
                            $Kernel::OM->Get('Log')->Log(
                                LogPrefix => 'Kernel::System::Auth::Sync::LDAP',
                                Priority  => 'error',
                                Message   => "Unable to add/update object icon (contact $ContactID).",
                            );
                        }
                    }
                }

                # get dynamic field list
                my $DynamicFieldList = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
                    Valid      => 1,
                    ObjectType => ['Contact'],
                );
                my %DynamicFieldConfig = map { $_->{Name} => $_ } @{ $DynamicFieldList };

                # set Dynamic Fields
                ATTRIBUTE:
                foreach my $Attribute ( sort( keys( %{ $SyncContactRef } ) ) ) {
                    next ATTRIBUTE if ( $Attribute !~ /^DynamicField_(.*)$/ );

                    my $DynamicFieldName = $1;

                    next ATTRIBUTE if ( !IsHashRefWithData( $DynamicFieldConfig{ $DynamicFieldName } ) );
                    next ATTRIBUTE if ( $DynamicFieldConfig{ $DynamicFieldName }->{InternalField} );

                    # set value
                    my $Success = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
                        DynamicFieldConfig => $DynamicFieldConfig{ $DynamicFieldName },
                        ObjectID           => $ContactID,
                        Value              => $SyncContactRef->{ $Attribute },
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
    my %RolesFromLDAP;
    if ( IsHashRefWithData( $Self->{GroupDNBasedRoleSync} ) ) {
        # read and remember roles from ldap
        GROUPDN:
        for my $GroupDN ( sort( keys( %{ $Self->{GroupDNBasedRoleSync} } ) ) ) {
            # search if we're allowed to
            my $Filter;
            if ( $Self->{UserAttr} eq 'DN' ) {
                $Filter = "($Self->{AccessAttr}=" . escape_filter_value( $UserDN ) . ')';
            }
            else {
                $Filter = "($Self->{AccessAttr}=" . escape_filter_value( $Param{User} ) . ')';
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
            my %SyncRoles = %{ $Self->{GroupDNBasedRoleSync}->{ $GroupDN } };
            SYNCROLE:
            for my $SyncRole ( sort( keys( %SyncRoles ) ) ) {

                # only for valid roles
                if ( !$SystemRolesByName{ $SyncRole } ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'notice',
                        Message  => "Invalid role \"$SyncRole\" in GroupDNBasedRoleSync!"
                    );

                    next SYNCROLE;
                }

                # set/overwrite remembered permissions
                $RolesFromLDAP{ $SystemRolesByName{ $SyncRole } } = $SyncRoles{ $SyncRole };
            }
        }
    }

    # attribute based role sync...
    if ( IsHashRefWithData( $Self->{AttributeBasedRoleSync} ) ) {

        # build filter
        my $Filter = "($Self->{UID}=" . escape_filter_value( $Param{User} ) . ')';

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
            my %SyncConfig = %{ $Self->{AttributeBasedRoleSync} };
            for my $Attribute ( sort( keys( %SyncConfig ) ) ) {

                my %AttributeValues = %{ $SyncConfig{ $Attribute } };
                ATTRIBUTEVALUE:
                for my $AttributeValue ( sort( keys( %AttributeValues ) ) ) {

                    for my $Entry ( $Result->all_entries() ) {

                        # Check if configured value exists in values of role attribute
                        # If yes, add sync roles to the user
                        my $GotValue;
                        my @Values = $Entry->get_value( $Attribute );
                        VALUE:
                        for my $Value ( @Values ) {
                            next VALUE if ( $Value !~ m{ \A \Q$AttributeValue\E \z }xmsi );

                            $GotValue = 1;

                            last VALUE;
                        }
                        next ATTRIBUTEVALUE if ( !$GotValue );

                        # remember role permissions
                        my %SyncRoles = %{ $AttributeValues{ $AttributeValue } };
                        SYNCROLE:
                        for my $SyncRole ( sort( keys( %SyncRoles ) ) ) {

                            # only for valid roles
                            if ( !$SystemRolesByName{ $SyncRole } ) {
                                $Kernel::OM->Get('Log')->Log(
                                    Priority => 'notice',
                                    Message  =>
                                        "Invalid role \"$SyncRole\" in AttributeBasedRoleSync!",
                                );
                                next SYNCROLE;
                            }

                            # set/overwrite remembered permissions
                            $RolesFromLDAP{ $SystemRolesByName{ $SyncRole } } = $SyncRoles{ $SyncRole };
                        }
                    }
                }
            }
        }
    }

    my %UserContextFromLDAP;
    # GroupDN based usage context sync...
    if ( IsHashRefWithData( $Self->{GroupDNBasedUsageContextSync} ) ) {

        # read and remember roles from ldap
        GROUPDN:
        for my $GroupDN ( sort( keys( %{ $Self->{GroupDNBasedUsageContextSync} } ) ) ) {

            # search if we're allowed to
            my $Filter;
            if ( $Self->{UserAttr} eq 'DN' ) {
                $Filter = "($Self->{AccessAttr}=" . escape_filter_value( $UserDN ) . ')';
            }
            else {
                $Filter = "($Self->{AccessAttr}=" . escape_filter_value( $Param{User} ) . ')';
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

            my %SyncContexts = %{ $Self->{GroupDNBasedUsageContextSync}->{ $GroupDN } };
            SYNCCONTEXT:
            for my $SyncContext ( sort( keys( %SyncContexts ) ) ) {
                # only for valid contexts
                if ( $SyncContext !~ /^Is(Agent|Customer)$/g ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'notice',
                        Message  => "Invalid context \"$SyncContext\" in GroupDNBasedUsageContextSync!"
                    );

                    next SYNCCONTEXT;
                }

                # ignore any positive result if we already have a negative
                next SYNCCONTEXT if (
                    exists( $UserContextFromLDAP{ $SyncContext } )
                    && $UserContextFromLDAP{ $SyncContext } == 0
                );

                $UserContextFromLDAP{ $SyncContext } = $SyncContexts{ $SyncContext };
            }
        }

        # if no GroupDN matches remove possibly assigned usage context
        for my $CurrUC ( qw(IsAgent IsCustomer) ) {
            if ( !exists( $UserContextFromLDAP{ $CurrUC } ) ) {
                $UserContextFromLDAP{ $CurrUC } = '0';
            }
        }
    }

    # if no GroupDN based context assignment is given, retrieve usage contexts
    # from assigned roles - remember: this is just the sync. the auth-backend
    # may be limited to a certain usage context though!
    elsif ( scalar( keys( %RolesFromLDAP ) ) ) {
        for my $CurrRID ( keys( %RolesFromLDAP ) ) {
            my %RoleData = $Kernel::OM->Get('Role')->RoleGet(
                ID => $CurrRID
            );
            if (
                %RoleData
                && $RoleData{UsageContextList}
                && IsArrayRef( $RoleData{UsageContextList} )
            ) {
                for my $CurrContext ( @{ $RoleData{UsageContextList} } ) {
                    $UserContextFromLDAP{ "Is" . $CurrContext } = '1';
                }
            }
        }
    }

    if ( !$UserID ) {
        # create user
        $UserID = $Kernel::OM->Get('User')->UserAdd(
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
            $LDAP->disconnect();

            return;
        }

        # assign user to contact
        if ( $ContactID ) {
            my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
                ID => $ContactID,
            );
            my $Result = $Kernel::OM->Get('Contact')->ContactUpdate(
                %ContactData,
                ID             => $ContactID,
                AssignedUserID => $UserID,
                UserID         => 1
            );
            if ( !$Result ) {
                $Kernel::OM->Get('Log')->Log(
                    LogPrefix => 'Kernel::System::Auth::Sync::LDAP',
                    Priority  => 'error',
                    Message   => "Unable to assign contact to user \"$Param{User}\" ($UserDN)!",
                );
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    LogPrefix => 'Kernel::System::Auth::Sync::LDAP',
                    Priority  => 'notice',
                    Message   => "Assigned contact to user \"$Param{User}\" ($UserDN) in RDBMS.",
                );
            }
        }

        $Kernel::OM->Get('Log')->Log(
            LogPrefix => 'Kernel::System::Auth::Sync::LDAP',
            Priority  => 'notice',
            Message   => "Local user for ldap user \"$Param{User}\" ($UserDN) created in RDBMS.",
        );
    }

    # IsCustomer/IsAgent in UserSyncMap always overwrites all other context modifications
    $UserContextFromLDAP{IsCustomer} = $SyncContactRef->{IsCustomer} if ( exists( $SyncContactRef->{IsCustomer} ) );
    $UserContextFromLDAP{IsAgent}    = $SyncContactRef->{IsAgent} if ( exists( $SyncContactRef->{IsAgent} ) );

    # set user context in DB
    my %User = $Kernel::OM->Get('User')->GetUserData(
        UserID => $UserID,
        Silent => 1
    );

    if ( %User ) {
        # remove UserPw from update data to keep current password
        delete( $User{UserPw} );

        # set UserLogin from LDAP
        # (at this point, user was either successfully identified by email or newly created )
        if ( $SyncContactRef->{UserLogin} ) {
            $User{UserLogin} = $SyncContactRef->{UserLogin};
        }

        my $Success = $Kernel::OM->Get('User')->UserUpdate(
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
        # get current user roles
        my @ExistingRoleIDs = $Kernel::OM->Get('Role')->UserRoleList(
            UserID             => $UserID,
            IgnoreContextRoles => 1,
        );

        my @RoleIDsToDelete = ();
        for my $RoleID ( @ExistingRoleIDs ) {
            # existing role is not assigned anymore
            if ( !$RolesFromLDAP{ $RoleID } ) {
                push( @RoleIDsToDelete, $RoleID );
            }
            # existing role is unchanged
            else {
                delete( $RolesFromLDAP{ $RoleID } );
            }
        }

        # revoke existing roles not assigned anymore
        if ( @RoleIDsToDelete ) {
            my $Success = $Kernel::OM->Get('Role')->RoleUserDelete(
                UserID             => $UserID,
                RoleIDs            => \@RoleIDsToDelete,
                IgnoreContextRoles => 1,
            );
            if ( !$Success ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to revoke role assignments (RoleIDs: " . join( ', ', @RoleIDsToDelete ) . ") of user \"$Param{User}\" (UserID: $UserID)!",
                );
            }
        }

        # apply not existing roles from ldap
        ROLEID:
        for my $RoleID ( sort( keys( %RolesFromLDAP ) ) ) {
            next ROLEID if ( !$RolesFromLDAP{ $RoleID } );

            # ignore context roles
            next ROLEID if (
                $SystemRoles{ $RoleID } eq 'Agent User'
                || $SystemRoles{ $RoleID } eq 'Customer'
            );

            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "User: \"$Param{User}\" assigning role \"$SystemRoles{$RoleID}\"!",
            );

            # assign role
            my $Result = $Kernel::OM->Get('Role')->RoleUserAdd(
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
    $LDAP->disconnect();

    return $Param{User};
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
