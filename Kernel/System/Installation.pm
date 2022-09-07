# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation;

use strict;
use warnings;

use File::Basename;

use Kernel::Language qw(Translatable);
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::AsynchronousExecutor
    Kernel::System::Installation::Migration
);

our @ObjectDependencies = ();

=head1 NAME

Kernel::System::Installation - handling of current installation

=head1 SYNOPSIS

All installation related functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $InstallationObject = $Kernel::OM->Get('Installation');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item GetAPIWebServiceDefinition()

generate the YAML for the REST API webservice

    my $YAML = $InstallationObject->GetAPIWebServiceDefinition(
        Version => 'v1'     # API version
    );

=cut

sub GetAPIWebServiceDefinition {
    my ( $Self, %Param ) = @_;

    # check needed parameters
    if ( !$Param{Version} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Version!"
        );
    }

    my $Home = $ENV{KIX_HOME};
    if ( !$Home ) {
        use FindBin qw($Bin);
        $Home = $Bin.'/..';
        if ( $Bin =~ /^(.*?\/plugins).*?$/ ) {
            $Home = $1.'/..';
        }
        $ENV{KIX_HOME} = $Home;
    }

    # get all plugins in the order of initialization
    my @Plugins = $Self->PluginList(
        Valid     => 1,
        InitOrder => 1
    );

    # add framework itself as the first element
    unshift @Plugins, { Directory => $Home };

    my @Definition;

    # get API definition of each plugin
    foreach my $Plugin ( @Plugins ) {
        my $Content = $Kernel::OM->Get('Main')->FileRead(
            Directory       => $Plugin->{Directory},
            Filename        => 'API.'.$Param{Version},
            Result          => 'ARRAY',
            DisableWarnings => 1,
        );
        if ( IsArrayRefWithData($Content) ) {
            push @Definition, @{$Content};
        }
    }

    # transform definition to YAML
    my $YAML = $Self->_GenerateWebServiceYAML(
        Definition => \@Definition
    );

    return $YAML;
}

=item PluginList()

get the list of available plugins

    my @PluginList = $InstallationObject->PluginList(
        Valid     => 0|1        # optional, 1 means only get active plugins
        InitOrder => 1          # optional, sort the result by the order of initialization
    );

=cut

sub PluginList {
    my ( $Self, %Param ) = @_;
    my @Plugins;
    my @DirectoryList;

    my $Home = $ENV{KIX_HOME};
    if ( !$Home ) {
        use FindBin qw($Bin);
        $Home = $Bin.'/..';
        if ( $Bin =~ /^(.*?\/plugins).*?$/ ) {
            $Home = $1.'/..';
        }
        $ENV{KIX_HOME} = $Home;
    }
    my $PluginDirectory = $Home.'/plugins';

    # get all directories in the plugins folder
    # don't do that using the Main object, since we are called by the OM constructor
    opendir(HANDLE, $PluginDirectory) || die "Can't open $PluginDirectory: $!";
    while (readdir HANDLE) {
        next if $_ =~ /^\./;
        next if !-d $PluginDirectory.'/'.$_;    # only directories

        push @DirectoryList, $PluginDirectory.'/'.$_;
    }
    closedir(HANDLE);

    # get RELEASE information of each plugin
    DIRECTORY:
    foreach my $Directory ( sort @DirectoryList ) {
        my %Plugin = $Self->_ReadReleaseFile(
            Directory => $Directory
        );
        $Plugin{Directory} = $Directory;
        $Plugin{Exports} = {};

        # read EXPORTS file
        if ( open(HANDLE, '<', $Directory.'/EXPORTS') ) {
            while (<HANDLE>) {
                # ignore comments and empty lines
                next if $_ =~ /^#/;
                next if $_ =~ /^\s*$/;

                chomp;
                $_ =~ s/^\s*(.*?)\s*$/$1/g;

                my ($Object, $Module) = split(/\s+=\s+/, $_);

                next if !$Object && !$Module;

                $Plugin{Exports}->{$Object} = $Module;
            }
            close(HANDLE);
        }

        # add to list of plugins
        push @Plugins, \%Plugin;
    }

    if ( IsArrayRefWithData(\@Plugins) ) {
        my %PluginList = map { $_->{Product} => $_ } @Plugins;

        # get order of initialization
        foreach my $Plugin ( @Plugins ) {
            $Plugin->{InitOrder} = $Self->_GetPluginDependencyCount(
                Plugin     => $Plugin->{Product},
                PluginList => \%PluginList,
            ) || 0;
        }

        if ( $Param{InitOrder} ) {
            @Plugins = sort { $a->{InitOrder} <=> $b->{InitOrder} } @Plugins;
        }
    }

    return @Plugins;
}

=item PluginAvailable()

check if the given plugin is available

    my $Result = $InstallationObject->PluginAvailable(
        Plugin => 'KIXPro',
    );

=cut

sub PluginAvailable {
    my ( $Self, %Param ) = @_;

    # check needed parameters
    if ( !$Param{Plugin} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Plugin!"
        );
    }

    my %Plugins = map {$_->{Product} => 1 } $Self->PluginList(Valid => 1);

    return $Plugins{$Param{Plugin}};
}

=item GetPluginExports()

get the list of plugin exports (object map) in order of initialization

    my @PluginExports = $InstallationObject->GetPluginExports()

=cut

sub GetPluginExports {
    my ( $Self, %Param ) = @_;
    my %Exports;

    # get all plugins in the order of initialization
    my @Plugins = $Self->PluginList(
        Valid     => 1,
        InitOrder => 1
    );

    foreach my $Plugin ( @Plugins ) {
        %Exports = (
            %Exports,
            %{$Plugin->{Exports}},
        );
    }

    return %Exports;
}

=item Update()

update the current installation to a new build number

    my $Result = $InstallationObject->Update(
        SourceBuild => 1234         # optional, if not given, the installed build number will be used
        TargetBuild => 2345         # optional, if not given, the build number from the plugin directory will be used
        Plugin      => 'KIXPro'     # optional, if not given the framework itself will be updated
    );

=cut

sub Update {
    my ( $Self, %Param ) = @_;

    my $Home = $ENV{KIX_HOME} || $Kernel::OM->Get('Config')->Get('Home');

    my @Plugins = $Self->PluginList(
        InitOrder => 1
    );
    my %PluginList = map { $_->{Product} => $_ } @Plugins;

    my @UpdateItems;
    if ( !$Param{Plugin} ) {
        # add framework
        push @UpdateItems, { Name => 'framework', Directory => $Home };
    }
    elsif ( $Param{Plugin} && $Param{Plugin} ne 'ALL' ) {
        my $Directory = $PluginList{$Param{Plugin}}->{Directory};

        if ( ! -d $Directory ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Plugin $Param{Plugin} doesn't exist!"
            );
            return;
        }
        # add plugin
        push @UpdateItems, { Name => $Param{Plugin}, Directory => $Directory };
    }
    elsif ( $Param{Plugin} && $Param{Plugin} eq 'ALL' ) {
        foreach my $Plugin ( @Plugins ) {
            if ( ! -d $Plugin->{Directory} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Plugin $Plugin->{Product} doesn't exist!"
                );
                return;
            }
            # add plugin
            push @UpdateItems, { Name => $Plugin->{Product}, Directory => $Plugin->{Directory} };
        }
    }

    DIRECTORY:
    foreach my $UpdateItem ( @UpdateItems ) {
        # get all relevant versions between source and target
        my @FileList = $Kernel::OM->Get('Main')->DirectoryRead(
            Directory => $UpdateItem->{Directory}.'/update',
            Filter    => 'build-*',
            Silent    => 1,
        );

        my %BuildList;
        foreach my $File (sort @FileList) {
            my ($Filename, $Dirs, $Suffix) = fileparse($File, qr/\.[^.]*/);
            if ($Filename =~ /^build-(\d+).*?$/g) {
                my $NummericBuild = "$1";
                $BuildList{$NummericBuild} = "build-$1";
            }
        }

        # determine source and target builds
        my $SourceBuild = $Param{SourceBuild};
        if ( !defined $SourceBuild ) {
            # get current build number
            my $Content = $Kernel::OM->Get('Main')->FileRead(
                Directory => $Home.'/config/installation',
                Filename  => $UpdateItem->{Name},
                DisableWarnings => 1,
            );

            $SourceBuild = 0;
            if ( $Content ) {
                $SourceBuild = $$Content;
            }
        }

        my $TargetBuild = $Param{TargetBuild};
        if ( !defined $TargetBuild ) {
            $TargetBuild = $PluginList{$UpdateItem->{Name}}->{BuildNumber};
        }

        my $Failed = 0;
        my $LastBuild = 0;
        TYPE:
        foreach my $Type ( ('pre', '', 'post') ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => "info",
                Message  => "executing ".($Type ? $Type.' ' : $Type)."update scripts for $UpdateItem->{Name}...",
            );
            BUILDNUMBER:
            foreach my $NumericBuild (sort { $a <=> $b } keys %BuildList) {

                next if $NumericBuild <= $SourceBuild;
                last if $NumericBuild > $TargetBuild;

                my $Result = $Self->_DoUpdate(
                    Name      => $UpdateItem->{Name},
                    Directory => $UpdateItem->{Directory},
                    Build     => $BuildList{$NumericBuild},
                    Type      => $Type,
                );

                if ( !$Result ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Error while updating $UpdateItem->{Name}. Ignoring further updates for $UpdateItem->{Name}."
                    );
                    $Failed = 1;
                    last TYPE;
                }

                $LastBuild = $NumericBuild;
            }
        }

        if ( !$Failed ) {
            # store current build number
            my $Result = $Kernel::OM->Get('Main')->FileWrite(
                Directory => $Home.'/config/installation',
                Filename  => $UpdateItem->{Name},
                Content   => \($UpdateItem->{Name} eq 'framework' ? $TargetBuild : $PluginList{$UpdateItem->{Name}}->{BuildNumber}),
            );
        }
    }

    return 1;
}

sub _DoUpdate {
    my ($Self, %Param) = @_;

    $Kernel::OM->Get('Log')->Log(
        Priority => 'info',
        Message  => "updating $Param{Name} to $Param{Build}!"
    );

    if ( $Param{Type} && $Param{Type} eq 'pre' ) {
        if ( !$Self->_ExecUpdateScript(%Param, Type => $Param{Type}) ) {
            return;
        }
        if ( !$Self->_ExecUpdateSQL(%Param, Type => $Param{Type}) ) {
            return;
        }
    }
    else {
        if ( !$Self->_ExecUpdateSQL(%Param, Type => $Param{Type}) ) {
            return;
        }
        if ( !$Self->_ExecUpdateScript(%Param, Type => $Param{Type}) ) {
            return;
        }
    }

    return 1;
}

sub _ExecUpdateScript {
    my ($Self, %Param) = @_;

    my $Type    = $Param{Type} || '';
    my $OrgType = $Param{Type} || '';

    if ( $Type ) {
        $Type = '_'.$Type;
    }

    my $ScriptFile = $Param{Directory}.'/update/'.$Param{Build}.$Type.'.pl';

    if ( ! -f $ScriptFile ) {
        return 1;
    }

    my $ExitCode = system($ScriptFile);
    if ($ExitCode) {
        $Kernel::OM->Get('Log')->Log(
            Priority => "error",
            Message  => "Unable to execute $OrgType update script!",
        );
        return;
    }

    return 1;
}

sub _ExecUpdateSQL {
    my ($Self, %Param) = @_;

    my $Type    = $Param{Type} || '';
    my $OrgType = $Param{Type} || '';
    if ( $Type ) {
        $Type = '_'.$Type;
    }

    # check if xml file exists, if not, exit gracefully
    my $XMLFile = $Param{Directory}.'/update/'.$Param{Build}.$Type.'.xml';

    if ( ! -f "$XMLFile" ) {
        return 1;
    }

    my $XML = $Kernel::OM->Get('Main')->FileRead(
        Location => $XMLFile,
    );
    if (!$XML) {
        $Kernel::OM->Get('Log')->Log(
            Priority => "error",
            Message  => "Unable to read file \"$XMLFile\"!",
        );
        return;
    }

    my @XMLArray = $Kernel::OM->Get('XML')->XMLParse(
        String => $XML,
    );
    if (!@XMLArray) {
        $Kernel::OM->Get('Log')->Log(
            Priority => "error",
            Message  => "Unable to parse file \"$XMLFile\"!",
        );
        return;
    }

    my @SQL = $Kernel::OM->Get('DB')->SQLProcessor(
        Database => \@XMLArray,
    );
    if (!@SQL) {
        $Kernel::OM->Get('Log')->Log(
            Priority => "error",
            Message  => "Unable to generate SQL from file \"$XMLFile\"!",
        );
        return;
    }

    for my $SQL (@SQL) {
        my $Result = $Kernel::OM->Get('DB')->Do(
            SQL => $SQL
        );
        if (!$Result) {
            $Kernel::OM->Get('Log')->Log(
                Priority => "error",
                Message  => "Unable to execute SQL from file \"$XMLFile\"!",
            );
        }
    }

    # execute post SQL statements (indexes, constraints)
    my @SQLPost = $Kernel::OM->Get('DB')->SQLProcessorPost();
    for my $SQL (@SQLPost) {
        my $Result = $Kernel::OM->Get('DB')->Do(
            SQL => $SQL
        );
        if (!$Result) {
            $Kernel::OM->Get('Log')->Log(
                Priority => "error",
                Message  => "Unable to execute POST SQL from file \"$XMLFile\"!",
            );
        }
    }

    # delete whole cache to make sure any new data is available in the following scripts
    $Kernel::OM->Get('Cache')->CleanUp();

    return 1;
}

sub _ReadReleaseFile {
    my ($Self, %Param) = @_;
    my %Release;

    # check needed stuff
    for (qw(Directory)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    open(HANDLE, '<', $Param{Directory}.'/RELEASE') || return;
    while (<HANDLE>) {
        chomp;
        my $Line = $_;

        # ignore comment lines
        next if ( $Line =~ /^#/ );

        foreach my $Key ( qw(Product Version Description BuildDate BuildHost BuildNumber PatchNumber Requires) ) {
            my $Var = uc($Key);

            if ( $Line =~ /^$Var\s{0,2}=\s{0,2}(.*)\s{0,2}$/i ) {
                $Release{$Key} = $1;
            }
        }
    }
    close(HANDLE);

    if ( $Release{Requires} ) {
        my @RequiresList = split(/\s*,\s*/, $Release{Requires});
        $Release{RequiresList} = \@RequiresList;
    }

    return %Release;
}

sub _GetPluginDependencyCount {
    my ( $Self, %Param ) = @_;
    my %Result;

    return if !$Param{Plugin};

    my $DepCount = 0;

    # get dependencies of plugin
    my $Deps = $Param{PluginList}->{$Param{Plugin}}->{RequiresList};
    if ( IsArrayRefWithData($Deps) ) {
        # check each dependency in depth
        foreach my $Dep ( @{$Deps} ) {
            $DepCount++;
            my $SubCount = $Self->_GetPluginDependencyCount(
                Plugin     => $Dep,
                PluginList => $Param{PluginList},
            );
            $DepCount += $SubCount;
        }
    }

    return $DepCount;
}

sub _GenerateWebServiceYAML {
    my ( $Self, %Param ) = @_;

    # check needed parameters
    if ( !$Param{Definition} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Definition!"
        );
    }

    my $Template = "---
Description: KIX Core API
FrameworkVersion: __VERSION__
Provider:
  Operation:
__OPERATIONS__
  Transport:
    Config:
      KeepAlive: ''
      MaxLength: '52428800'
      RouteOperationMapping:
__ROUTES__
";

    my $Operations = '';
    my $Routes = '';
    foreach my $Line ( @{$Param{Definition}} ) {
        chomp($Line);

        # ignore comments or empty lines
        next if ($Line =~ /^\s*#/ || $Line =~ /^\s*$/g);

        my ($Route, $Method, $Operation, $Additions) = split(/\s*\|\s*/, $Line);
        my @AdditionList = $Additions ? split(/,/, $Additions) : ();

    $Operations .= "    $Operation:
        Description: ''
        MappingInbound:
            Type: Simple
        MappingOutbound:
            Type: Simple
        Type: $Operation\n";

        if ($Additions) {
            foreach my $Addition (@AdditionList) {
                $Operations .= "        $Addition\n";
            }
        }

        $Routes .= "        $Operation:
          RequestMethod:
          - $Method
          Route: $Route\n";
    }

    $Template =~ s/__OPERATIONS__/$Operations/g;
    $Template =~ s/__ROUTES__/$Routes/g;

    return $Template;
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
