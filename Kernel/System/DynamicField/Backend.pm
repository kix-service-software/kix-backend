# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Backend;

use strict;
use warnings;

use Scalar::Util qw(weaken);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Log',
    'Main',
);

=head1 NAME

Kernel::System::DynamicField::Backend

=head1 SYNOPSIS

DynamicFields backend interface

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a DynamicField backend object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $DynamicFieldObject = $Kernel::OM->Get('DynamicField::Backend');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # get the Dynamic Field Backends configuration
    my $DynamicFieldsConfig = $ConfigObject->Get('DynamicFields::Driver');

    # check Configuration format
    if ( !IsHashRefWithData($DynamicFieldsConfig) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Dynamic field configuration is not valid!",
        );
        return;
    }

    # get main object
    my $MainObject = $Kernel::OM->Get('Main');

    # create all registered backend modules
    for my $FieldType ( sort keys %{$DynamicFieldsConfig} ) {

        # check if the registration for each field type is valid
        if ( !$DynamicFieldsConfig->{$FieldType}->{Module} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Registration for field type $FieldType is invalid!",
            );
            return;
        }

        # set the backend file
        my $BackendModule = $DynamicFieldsConfig->{$FieldType}->{Module};

        # check if backend field exists
        if ( !$MainObject->Require($BackendModule) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't load dynamic field backend module for field type $FieldType!",
            );
            return;
        }

        # create a backend object
        my $BackendObject = $BackendModule->new( %{$Self} );

        if ( !$BackendObject ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Couldn't create a backend object for field type $FieldType!",
            );
            return;
        }

        if ( ref $BackendObject ne $BackendModule ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Backend object for field type $FieldType was not created successfuly!",
            );
            return;
        }

        # remember the backend object
        $Self->{ 'DynamicField' . $FieldType . 'Object' } = $BackendObject;
    }

    # get the Dynamic Field Objects configuration
    my $DynamicFieldObjectTypeConfig = $ConfigObject->Get('DynamicFields::ObjectType');

    # check Configuration format
    if ( IsHashRefWithData($DynamicFieldObjectTypeConfig) ) {

        # create all registered ObjectType handler modules
        for my $ObjectType ( sort keys %{$DynamicFieldObjectTypeConfig} ) {

            # check if the registration for each field type is valid
            if ( !$DynamicFieldObjectTypeConfig->{$ObjectType}->{Module} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Registration for object type $ObjectType is invalid!",
                );
                return;
            }

            # set the backend file
            my $ObjectHandlerModule = $DynamicFieldObjectTypeConfig->{$ObjectType}->{Module};

            # check if backend field exists
            if ( !$MainObject->Require($ObjectHandlerModule) ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message =>
                        "Can't load dynamic field object handler module for object type $ObjectType!",
                );
                return;
            }

            # create a backend object
            my $ObjectHandlerObject = $ObjectHandlerModule->new(
                %{$Self},
                %Param,    # pass %Param too, for optional arguments like TicketObject
            );

            if ( !$ObjectHandlerObject ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Couldn't create a handler object for object type $ObjectType!",
                );
                return;
            }

            if ( ref $ObjectHandlerObject ne $ObjectHandlerModule ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message =>
                        "Handler object for object type $ObjectType was not created successfuly!",
                );
                return;
            }

            # remember the backend object
            $Self->{ 'DynamicField' . $ObjectType . 'HandlerObject' } = $ObjectHandlerObject;
        }
    }

    # get the Dynamic Field Backend custmom extensions
    my $DynamicFieldBackendExtensions = $ConfigObject->Get('DynamicFields::Extension::Backend');

    EXTENSION:
    for my $ExtensionKey ( sort keys %{$DynamicFieldBackendExtensions} ) {

        # skip invalid extensions
        next EXTENSION if !IsHashRefWithData( $DynamicFieldBackendExtensions->{$ExtensionKey} );

        # create a extension config shortcut
        my $Extension = $DynamicFieldBackendExtensions->{$ExtensionKey};

        # skip if extension does not contain a backend module
        next EXTENSION if !$Extension->{Module};

        # check if module can be loaded
        if ( !$MainObject->RequireBaseClass( $Extension->{Module} ) ) {
            die "Can't load dynamic fields backend module $Extension->{Backend}! $@";
        }
    }

    return $Self;
}

=item GetCacheDependencies()

returns a list of cache dependencies.

    my $Dependencies = $BackendObject->GetCacheDependencies(
        DynamicFieldConfig => $DynamicFieldConfig      # complete config of the DynamicField
    );

    Returns

    $Dependencies = [
        CacheTypeA,
        CacheTypeB
    ]

=cut

sub GetCacheDependencies {
    my ( $Self, %Param ) = @_;

    return if !$Self->_CheckParams(%Param);

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # call GetCacheDependencies on the specific backend
    return $Self->{$DynamicFieldBackend}->GetCacheDependencies(%Param);
}

=item DisplayValueRender()

creates value and title strings to be used in display masks. Supports HTML output
and will transform dates to the current user's timezone.

    my $ValueStrg = $BackendObject->DisplayValueRender(
        DynamicFieldConfig => $DynamicFieldConfig,      # complete config of the DynamicField
        Value              => 'Any value',              # Optional
        HTMLOutput         => 1,                        # or 0, default 1, to return HTML ready
                                                        #    values
        ValueMaxChars      => 20,                       # Optional (for HTMLOutput only)
        TitleMaxChars      => 20,                       # Optional (for HTMLOutput only)
        LayoutObject       => $LayoutObject,
    );

    Returns

    $ValueStrg = {
        Title       => $Title,
        Value       => $Value,
        Link        => $Link,
        LinkPreview => $LinkPreview,
    }

=cut

sub DisplayValueRender {
    my ( $Self, %Param ) = @_;

    return if !$Self->_CheckParams(%Param);

    $Param{LayoutObject} //= $Kernel::OM->Get('Output::HTML::Layout');

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # call DisplayValueRender on the specific backend
    my $ValueStrg = $Self->{$DynamicFieldBackend}->DisplayValueRender(%Param);

    return $ValueStrg;
}

=item HTMLDisplayValueRender()

creates value and title strings to be used in display masks. Supports HTML output
and will transform dates to the current user's timezone.

    my $ValueStrg = $BackendObject->DisplayValueRender(
        DynamicFieldConfig => $DynamicFieldConfig,      # complete config of the DynamicField
        Value              => 'Any value'               # Optional
    );

    Returns

    $ValueStrg = {
        Title       => $Title,
        Value       => $Value
    }

=cut

sub HTMLDisplayValueRender {
    my ( $Self, %Param ) = @_;

    return if !$Self->_CheckParams(%Param);

    $Param{LayoutObject} //= $Kernel::OM->Get('Output::HTML::Layout');

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # call DisplayValueRender on the specific backend
    my $ValueStrg = $Self->{$DynamicFieldBackend}->HTMLDisplayValueRender(%Param);

    return $ValueStrg;
}

=item ShortDisplayValueRender()

creates short value and title strings to be used in display masks. Supports HTML output
and will transform dates to the current user's timezone.

    my $ValueStrg = $BackendObject->DisplayValueRender(
        DynamicFieldConfig => $DynamicFieldConfig,      # complete config of the DynamicField
        Value              => 'Any value'               # Optional
    );

    Returns

    $ValueStrg = {
        Title       => $Title,
        Value       => $ShortValue
    }

=cut

sub ShortDisplayValueRender {
    my ( $Self, %Param ) = @_;

    return if !$Self->_CheckParams(%Param);

    $Param{LayoutObject} //= $Kernel::OM->Get('Output::HTML::Layout');

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # call DisplayValueRender on the specific backend
    my $ValueStrg = $Self->{$DynamicFieldBackend}->ShortDisplayValueRender(%Param);

    return $ValueStrg;
}

=item DisplayKeyRender()

creates key string to be used to be used in display masks.

    my $ValueStrg = $BackendObject->DisplayKeyRender(
        DynamicFieldConfig => $DynamicFieldConfig,      # complete config of the DynamicField
        Value              => 'Any value',              # Optional
    );

    Returns

    $ValueStrg = {
        Title => $Title,
        Value => $Value,
    }

=cut

sub DisplayKeyRender {
    my ( $Self, %Param ) = @_;

    return if !$Self->_CheckParams(%Param);

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    $Param{LayoutObject} //= $Kernel::OM->Get('Output::HTML::Layout');

    # call DisplayValueRender on the specific backend
    my $ValueStrg = $Self->{$DynamicFieldBackend}->DisplayKeyRender(%Param);

    return $ValueStrg;
}

=item ValueSet()

sets a dynamic field value.

    my $Success = $BackendObject->ValueSet(
        DynamicFieldConfig => $DynamicFieldConfig,      # complete config of the DynamicField
        ObjectID           => $ObjectID,                # ID of the current object that the field
                                                        # must be linked to, e. g. TicketID
        Value              => $Value,                   # Value to store, depends on backend type
        UserID             => 123,
    );

=cut

sub ValueSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig ObjectID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!"
            );
            return;
        }
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    my $OldValue = $Self->ValueGet(
        DynamicFieldConfig => $Param{DynamicFieldConfig},
        ObjectID           => $Param{ObjectID},
    );

    my $NewValue = ref $OldValue eq 'ARRAY' && ref $Param{Value} ne 'ARRAY' ? [$Param{Value}] : $Param{Value};

    # do not proceed if there is nothing to update, each dynamic field requires special handling to
    #    determine if two values are different or not, this to prevent false update events,
    #    see bug #9828. Note: (do not send %Param, as $NewValue is a reference and then Value2 could
    #    have strange values).
    if (
        !$Self->ValueIsDifferent(
            DynamicFieldConfig => $Param{DynamicFieldConfig},
            Value1             => $OldValue,
            Value2             => $NewValue,
        )
    ) {
        return 1;
    }

    # call ValueSet on the specific backend
    my $Success = $Self->{$DynamicFieldBackend}->ValueSet(%Param);

    if ( !$Success ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not update field $Param{DynamicFieldConfig}->{Name} for "
                . "$Param{DynamicFieldConfig}->{ObjectType} ID $Param{ObjectID}!",
        );
        return;
    }

    # set the dyanamic field object handler
    my $DynamicFieldObjectHandler =
        'DynamicField' . $Param{DynamicFieldConfig}->{ObjectType} . 'HandlerObject';

    # If an ObjectType handler is registered, use it.
    if ( ref $Self->{$DynamicFieldObjectHandler} ) {
        return $Self->{$DynamicFieldObjectHandler}->PostValueSet(
            OldValue => $OldValue,
            %Param,
        );
    }

    return 1;
}

=item ValueIsDifferent()

compares if two dynamic field values are different.

This function relies on Kernel::System::VariableCheck::DataIsDifferent() but with some exeptions
depending on each field.

    my $Success = $BackendObject->ValueIsDifferent(
        DynamicFieldConfig => $DynamicFieldConfig,      # complete config of the DynamicField
                                                        # must be linked to, e. g. TicketID
        Value1             => $Value1,                  # Dynamic Field Value
        Value2             => $Value2,                  # Dynamic Field Value
    );

=cut

sub ValueIsDifferent {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!"
            );
            return;
        }
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # use Kernel::System::VariableCheck::DataIsDifferent() as a fall back if function is not
    #    defined in the backend
    if ( !$Self->{$DynamicFieldBackend}->can('ValueIsDifferent') ) {
        return DataIsDifferent(
            Data1 => \$Param{Value1},
            Data2 => \$Param{Value2}
        );
    }

    # call ValueIsDifferent on the specific backend
    return $Self->{$DynamicFieldBackend}->ValueIsDifferent(%Param);
}

=item ValueDelete()

deletes a dynamic field value.

    my $Success = $BackendObject->ValueDelete(
        DynamicFieldConfig => $DynamicFieldConfig,      # complete config of the DynamicField
        ObjectID           => $ObjectID,                # ID of the current object that the field
                                                        # must be linked to, e. g. TicketID
        UserID             => 123,
        NoPostHandling     => 1,                        # optional, will be called to suppress the post handling (i.e. when a ticket gets deleted)
    );

=cut

sub ValueDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig ObjectID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!"
            );
            return;
        }
    }

    my $OldValue = $Self->ValueGet(
        DynamicFieldConfig => $Param{DynamicFieldConfig},
        ObjectID           => $Param{ObjectID},
    );

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    my $Success = $Self->{$DynamicFieldBackend}->ValueDelete(%Param);

    if ( !$Success ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not update field $Param{DynamicFieldConfig}->{Name} for "
                . "$Param{DynamicFieldConfig}->{ObjectType} ID $Param{ObjectID}!",
        );
        return;
    }

    if ( !$Param{NoPostHandling} ) {
        # set the dyanamic field object handler
        my $DynamicFieldObjectHandler =
            'DynamicField' . $Param{DynamicFieldConfig}->{ObjectType} . 'HandlerObject';

        # If an ObjectType handler is registered, use it.
        if ( ref $Self->{$DynamicFieldObjectHandler} ) {
            return $Self->{$DynamicFieldObjectHandler}->PostValueSet(
                OldValue => $OldValue,
                %Param,
            );
        }
    }

    return 1;
}

=item AllValuesDelete()

deletes all values of a dynamic field.

    my $Success = $BackendObject->AllValuesDelete(
        DynamicFieldConfig => $DynamicFieldConfig,      # complete config of the DynamicField
        UserID             => 123,
    );

=cut

sub AllValuesDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!"
            );
            return;
        }
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    return $Self->{$DynamicFieldBackend}->AllValuesDelete(%Param);
}

=item ValueValidate()

validates a dynamic field value.

    my $Success = $BackendObject->ValueValidate(
        DynamicFieldConfig => $DynamicFieldConfig,      # complete config of the DynamicField
        Value              => $Value,                   # Value to store, depends on backend type
        UserID             => 123,
    );

=cut

sub ValueValidate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!",
            );
            return;
        }
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # call ValueValidate on the specific backend
    return $Self->{$DynamicFieldBackend}->ValueValidate(%Param);
}

=item ValueGet()

get a dynamic field value.

    my $Value = $BackendObject->ValueGet(
        DynamicFieldConfig => $DynamicFieldConfig,      # complete config of the DynamicField
        ObjectID           => $ObjectID,                # ID of the current object that the field
                                                        # must be linked to, e. g. TicketID
    );

    Return $Value                                       # depends on backend type, i. e.
                                                        # Text, $Value =  'a string'
                                                        # DateTime, $Value = '1977-12-12 12:00:00'
                                                        # Checkbox, $Value = 1

=cut

sub ValueGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig ObjectID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!",
            );
            return;
        }
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend \"$Param{DynamicFieldConfig}->{FieldType}\" is invalid!"
        );
        return;
    }

    # call ValueGet on the specific backend
    return $Self->{$DynamicFieldBackend}->ValueGet(%Param);
}

=item SearchSQLGet()

returns the SQL WHERE part that needs to be used to search in a particular
dynamic field. The table must already be joined.

    my $SQL = $BackendObject->SearchSQLGet(
        DynamicFieldConfig => $DynamicFieldConfig,      # complete config of the DynamicField
        TableAlias         => $TableAlias,              # the alias of the already joined dynamic_field_value table to use
        SearchTerm         => $SearchTerm,              # What to look for. Placeholders in LIKE searches must be passed as %.
        Operator           => $Operator,                # One of [Equals, Like, GreaterThan, GreaterThanEquals, SmallerThan, SmallerThanEquals]
                                                        #   The supported operators differ for the different backends.
    );

=cut

sub SearchSQLGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig TableAlias Operator)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # Ignore empty searches
    return if ( !defined $Param{SearchTerm} || $Param{SearchTerm} eq '' );

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!",
            );
            return;
        }
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    return $Self->{$DynamicFieldBackend}->SearchSQLGet(%Param);
}

=item SearchSQLOrderFieldGet()

returns the SQL field needed for ordering based on a dynamic field.

    my $SQL = $BackendObject->SearchSQLOrderFieldGet(
        DynamicFieldConfig => $DynamicFieldConfig,      # complete config of the DynamicField
        TableAlias         => $TableAlias,              # the alias of the already joined dynamic_field_value table to use
    );

=cut

sub SearchSQLOrderFieldGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig TableAlias)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!",
            );
            return;
        }
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    return $Self->{$DynamicFieldBackend}->SearchSQLOrderFieldGet(%Param);
}

=item EditFieldValueGet()

extracts the value of a dynamic field from the param object.

    my $Value = $BackendObject->EditFieldValueGet(
        DynamicFieldConfig   => $DynamicFieldConfig,    # complete config of the DynamicField
        ParamObject          => $ParamObject,           # the current request data
        LayoutObject         => $LayoutObject,          # used to transform dates to user time zone
        TransformDates       => 1                       # 1 || 0, default 1, to transform the dynamic fields that
                                                        #   use dates to the user time zone (i.e. Date, DateTime
                                                        #   dynamic fields)
        Template             => $Template,
        ReturnValueStructure => 0,                      # 0 || 1, default 0
                                                        #   Returns special structure
                                                        #   (only for backend internal use).
        ReturnTemplateStructure => 0,                   # 0 || 1, default 0
                                                        #   Returns the structured values as got from the http request
    );

    Returns $Value;                                     # depending on each field type e.g.
                                                        #   $Value = 'a text';
                                                        #   $Value = '1977-12-12 12:00:00';
                                                        #   $Value = 1;

    my $Value = $BackendObject->EditFieldValueGet(
        DynamicFieldConfig      => $DynamicFieldConfig, # complete config of the DynamicField
        ParamObject             => $ParamObject,        # the current request data
        TransformDates          => 0                    # 1 || 0, default 1, to transform the dynamic fields that
                                                        #   use dates to the user time zone (i.e. Date, DateTime
                                                        #   dynamic fields)

        Template                => $Template            # stored values from DB like Search profile or Generic Agent job
        ReturnTemplateStructure => 1,                   # 0 || 1, default 0
                                                        #   Returns the structured values as got from the http request
                                                        #   (only for backend internal use).
    );

    Returns $Value;                                     # depending on each field type e.g.
                                                        #   $Value = 'a text';
                                                        #   $Value = {
                                                                Used   => 1,
                                                                Year   => '1977',
                                                                Month  => '12',
                                                                Day    => '12',
                                                                Hour   => '12',
                                                                Minute => '00'
                                                            },
                                                        #   $Value = 1;

=cut

sub EditFieldValueGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check for the data source
    if ( !$Param{ParamObject} && !$Param{Template} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ParamObject or Template!"
        );
        return;
    }

    # define transform dates parameter
    if ( !defined $Param{TransformDates} ) {
        $Param{TransformDates} = 1;
    }

    # check needed objects for transform dates
    if ( $Param{TransformDates} && !$Param{LayoutObject} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need LayoutObject to transform dates!"
        );
        return;
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType Name)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!"
            );
            return;
        }
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # return value from the specific backend
    return $Self->{$DynamicFieldBackend}->EditFieldValueGet(%Param);
}

=item EditFieldValueValidate()

validate the current value for the dynamic field

    my $Result = $BackendObject->EditFieldValueValidate(
        DynamicFieldConfig   => $DynamicFieldConfig,      # complete config of the DynamicField
        PossibleValuesFilter => {                         # Optional. Some backends may support this.
            'Key1' => 'Value1',                           #     This may be needed to realize ACL support for ticket masks,
            'Key2' => 'Value2',                           #     where the possible values can be limited with and ACL.
        },
        ParamObject          => $Self->{ParamObject}      # To get the values directly from the web request
        Mandatory            => 1,                        # 0 or 1,
    );

    Returns

    $Result = {
        ServerError        => 1,                          # 0 or 1,
        ErrorMessage       => $ErrorMessage,              # Optional or a default will be used in error case
    }

=cut

sub EditFieldValueValidate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{DynamicFieldConfig} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need DynamicFieldConfig!"
        );
        return;
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType Config Name)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!"
            );
            return;
        }
    }

    # check PossibleValuesFilter (general)
    if (
        defined $Param{PossibleValuesFilter}
        && ref $Param{PossibleValuesFilter} ne 'HASH'
        )
    {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The possible values filter is invalid",
        );
        return;
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # return validation structure from the specific backend
    return $Self->{$DynamicFieldBackend}->EditFieldValueValidate(%Param);

}

=item ReadableValueRender()

creates value and title strings to be used for storage (e. g. TicketHistory).
Produces text output and does not transform time zones of dates.

    my $ValueStrg = $BackendObject->ReadableValueRender(
        DynamicFieldConfig => $DynamicFieldConfig,      # complete config of the DynamicField
        Value              => 'Any value',              # Optional
        ValueMaxChars      => 20,                       # Optional
        TitleMaxChars      => 20,                       # Optional
    );

    Returns

    $ValueStrg = {
        Title => $Title,
        Value => $Value,
    }

=cut

sub ReadableValueRender {
    my ( $Self, %Param ) = @_;

    return if !$Self->_CheckParams(%Param);

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # call DisplayValueRender on the specific backend
    my $ValueStrg = $Self->{$DynamicFieldBackend}->ReadableValueRender(%Param);

    return $ValueStrg;
}

=item RandomValueSet()

sets a dynamic field random value.

    my $Result = $BackendObject->RandomValueSet(
        DynamicFieldConfig => $DynamicFieldConfig,      # complete config of the DynamicField
        ObjectID           => $ObjectID,                # ID of the current object that the field
                                                        # must be linked to, e. g. TicketID
        UserID             => 123,
    );

    returns:

    $Result {
        Success => 1                # or undef
        Value   => $RandomValue     # or undef
    }

=cut

sub RandomValueSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig ObjectID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!"
            );
            return;
        }
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # call RandomValueSet on the specific backend
    my $Result = $Self->{$DynamicFieldBackend}->RandomValueSet(%Param);

    if ( !$Result->{Success} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not update field $Param{DynamicFieldConfig}->{Name} for "
                . "$Param{DynamicFieldConfig}->{ObjectType} ID $Param{ObjectID}!",
        );
        return;
    }

    # set the dyanamic field object handler
    my $DynamicFieldObjectHandler =
        'DynamicField' . $Param{DynamicFieldConfig}->{ObjectType} . 'HandlerObject';

    # If an ObjectType handler is registered, use it.
    if ( ref $Self->{$DynamicFieldObjectHandler} ) {
        my $PostSuccess = $Self->{$DynamicFieldObjectHandler}->PostValueSet(
            %Param,
            Value => $Result->{Value},
        );
    }

    return $Result
}

=item HistoricalValuesGet()

returns the list of database values for a defined dynamic field. This function is used to calculate
ACLs in Search Dialog

    my $HistorialValues = $BackendObject->HistoricalValuesGet(
        DynamicFieldConfig => $DynamicFieldConfig,       # complete config of the DynamicField
    );

    Returns:

    $HistoricalValues = {
        '1'     => '1',
        'Item1' => 'Item1',
        'Item2' => 'Item2',
    }

=cut

sub HistoricalValuesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!"
            );
            return;
        }
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # call HistorialValuesGet on the specific backend
    return $Self->{$DynamicFieldBackend}->HistoricalValuesGet(%Param);
}

=item ValueLookup()

returns the display value for a value key for a defined Dynamic Field. This function is meaningfull
for those Dynamic Fields that stores a value different than the value that is shown ( e.g. a
Dropdown field could store Key = 1 and Display Value = One ) other fields return the same value
as the value key

    my $Value = $BackendObject->ValueLookup(
        DynamicFieldConfig => $DynamicFieldConfig,       # complete config of the DynamicField
        Key                => 'sorted value',            # could also be an array ref for MultipleSelect fields
    );

    Returns:

    $Value = 'value to display';

=cut

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    return if !$Self->_CheckParams(%Param);

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # call ValueLookup on the specific backend
    return $Self->{$DynamicFieldBackend}->ValueLookup(%Param);
}

=item HasBehavior()

checks if the dynamic field as an specified behavior

    my $Success = $BackendObject->HasBehavior(
        DynamicFieldConfig => $DynamicFieldConfig,       # complete config of the DynamicField
        Behavior           => 'Some Behavior',           # 'IsNotificationEventCondition' to be used
                                                         #     in the notification events as a
                                                         #     ticket condition
                                                         # 'IsSortable' to sort by this field in
                                                         #     "Small" overviews
                                                         # 'IsStatsCondition' to be used in
                                                         #     Statistics as a condition
                                                         # 'IsCustomerInterfaceCapable' to make
                                                         #     the field usable in the customer
                                                         #     interface
    );

    Returns:

    $Success = 1;                # or undefined (if the dynamic field does not have that behavior)

=cut

sub HasBehavior {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig Behavior)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!"
            );
            return;
        }
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # verify if function is available
    return if !$Self->{$DynamicFieldBackend}->can('HasBehavior');

    # call HasBehavior on the specific backend
    return $Self->{$DynamicFieldBackend}->HasBehavior(%Param);
}

=head2 Functions For IsNotificationEventCondition Behavior

The following functions should be only used if the dynamic field has IsNotificationEventCondition
behavior

=over 4

=cut

sub ExportConfigPrepare {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig Config)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!"
            );
            return;
        }
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # call ExportConfigPrepare on the specific backend
    return $Self->{$DynamicFieldBackend}->ExportConfigPrepare(%Param);
}


sub ImportConfigPrepare {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig Config)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(FieldType ObjectType)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!"
            );
            return;
        }
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # call ImportConfigPrepare on the specific backend
    return $Self->{$DynamicFieldBackend}->ImportConfigPrepare(%Param);
}

sub _CheckParams {
    my ( $Self, %Param ) = @_;


    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType Config Name)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!"
            );
            return;
        }
    }

    return 1;
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
