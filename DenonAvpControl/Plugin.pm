#	DenonAvpControl
#
#	Author:	Chris Couper <chris(dot)c(dot)couper(at)gmail(dot)com>
#	Credit To: Felix Mueller <felix(dot)mueller(at)gwendesign(dot)com>
#	Credit To: Sam Yahres <syahres(at)gmail(dot)com>
#
#	Copyright (c) 2003-2008 GWENDESIGN, 2008-2025 Chris Couper
#	All rights reserved.
#
#	----------------------------------------------------------------------
#	Function:	Turn Denon AVP Amplifier on and off (works for TP and SB)
#	----------------------------------------------------------------------
#	Technical:	To turn the amplifier on, sends AVP net AVON.
#			To turn the amplifier off, sends AVP net AVOFF.
#			To set the % volume of the amplifier per the % of theSB
#
#	----------------------------------------------------------------------
#	Installation:
#			- Copy the complete directory into the 'Plugins' directory
#			- Restart SlimServer
#			- Enable DenonAvpControl in the Web GUI interface
#			- Set:AvpIP Address, On, Off and Quick Delays, Max Volume, Quickselect
#	----------------------------------------------------------------------
#	History:
#
#	2009/02/14 v1.0	- Initial version
#	2009/02/23 v1.1	- Added zones and synching volume of amp with Squeezebox
#	2009/07/25 v1.2	- Minor changes to discard callbacks from unwanted players
#	2009/09/01 v1.3	- Changed the player registration process
#	2009/09/01 v1.4	- Changed to support SBS 7.4
#	2009/12/01 v1.5 - Added menus to allow the user to change audio settings
#	2010/08/07 v1.6 - Accomodate updates to AVP protocol and to use digital passthrough on iPeng
#	2010/08/15 v1.7 - Update to support .5 db steps in volume
#	2012/01/28 v1.8 - fixed error in maxVol fetch
#	2012/01/30 v1.9 - QuickSelect Issues, removed dead code, strings.txt update
#	2012/01/30 v1.9.1 - Supports multiple plugin instances, better comms handling, reference levels
#   2019/08/21 v1.9.2 - Moved to LMS, new zone 4 support
#	2020/05/14 v2.0 - Added quick selection delay for use during startup.
#   2021/02/24 v2.1 - Retracted.
#   2021/02/24 v2.2 - Bug fixes.
#   2021/02/25 v2.3 - Install fix.
#   2021/03/15 v3.0 - Bug fixes, volume improvements
#   2021/04/03 v4.0	- Quick Select support for all zones, mute feature, new icons, bug fixes, new apps support
#   2021/05/27 v4.1	- Improved support for menu features, choice indicator for Denon AVP, Quick Select on double pause,
#					  Handle incremental volume change after mute to compensate for LMS (mis)behavior,
#					  Allow volume synching in all zones, Support for switching between fixed and variable player output levels
#   2021/06/30 V4.2 - Surround speaker setting, channel level menu (all zones), SW on/off menu, bug fixes, clean up switching between fixed
#					  and variable output, skip powering off Denon if input source changed since power on, support changing the
#					  preamp volume level via the AVx menu when running in variable output mode (all zones).
#   2021/09/14 V4.2.1 - Add sanity range check for channel level volumes and prevent timing problem in Comms when retrieving them
#   2021/10/17 V4.3	- Added new Quick Select function to audio menu and made changes to repopulate the menu each time a
#					  Quick Select is done rather than waiting until the menu is invoked by the user. Add support for
#					  Quick Select 4 and 5 in the plugin menu. Various bug fixes.
#   2021/12/01 V4.3.2 - Minor changes and a bug fix to the Quick Select audio menu function.
#					  Delay playback during power on until the AVR is completely powered on and ready.
#   2021/12/10 V4.3.3 - Fix a Windows-specific bug in DenonAvpComms.pm, introduced in V4.3.2.
#	2022/01/20 V4.4 - Add the ability in the Quick Select menu to save the current AVR audio settings to the Quick Select command
#					  defined for the active player. Add support for a syntax change in the PSRSTR command introduced in
#					  the newer (X-series) AVR's. Prevent the player from setting the absolute volume to 100% when running with
#					  volume fixed at 100% as a workaround for a bug in some implementations of the player firmware/software.
#	2022/02/07 V4.4.1 - Add the ability to specify an alternate port with the IP address in the menu for use with AVR's having
#					  only a serial port and using a network bridge such as ser2net. Added secondary zone support for updating the
#					  Quick Select definition and fixed some bugs in secondary zone initialization logic. Added a pop-up message
#					  to be displayed when the AVR audio settings menu is selected for a player which is either turned off or not
#					  finished initializing.
#	2022/04/02 V4.5 - Added full support for Marantz AVR's by supporting the Smart Select command. For now, this is done by selecting
#					  'Marantz AVR' in the 'AVP/AVR Type' plugin menu option. Added automatic AVR make/model detection via the 'SYMO'
#					  command. Extended the Quick Select audio settings menu to support updating any of the Quick Select definitions
#					  and not just the one being used by the current player. Display the AVR model, IP Address and Zone in the top
#					  level of the audio settings menu. Updated the plugin setup menu to indicate that both Denon and Marantz AVR's are
#					  supported.
#	2022/05/15 V4.5.1 - Change code to refresh the channel level table after each Quick Select, since the channel levels are saved
#					  separately for each AVR input and the input might change with the QS. Extend the recenty added feature that
#					  bypasses powering off the AVR during "player off" if the AVR input is not the one associated with the player so
#					  that it works for secondary zones as well. Add a timeout retry counter and exit command processing after ten (10)
#					  consecutive timeouts in case of the AVR going offline. Display the current Surround Mode at the top of the channel
#					  volume menu and don't show channels that aren't active for that mode, i.e. the center channel for "Stereo" mode.
#					  Use the "refresh" nextWindow attribute for slider menu controls so that the new values are immediately shown
#					  after an update.  Also "refresh" the menu after saving a Quick Select command definition so that the one that
#                     was saved continues to be selected. Various bug fixes and changes.
#	2022/06/01 V4.6 - Add a Source Input Select option to the Audio settings menu. Input sources may be changed on the fly and
#					  the Channel Level table will be updated to reflect the levels associated with that input. Reorder the Audio
#					  settings menu to better group the submenus by function and frequency of use. When a new player registers with
#					  the plugin and is already powered "on", power it off first in order to avoid later confusion as to its status.
#					  Last but by no means least, fix a longstanding bug whereby the newPlayerCheck() callback function was registered
#					  to receive all ['client'] requests instead of only ['client','new'] ones, resulting in some strange behavior.
#					  Also cleaned up a lot of loose ends in the code.
#	2022/07/11 V4.6.1 - Add an AVR Power On/Off control to the Audio settings menu and allow the menu to be used even when the LMS player
#					  is turned off. The AVR Power On button will bypass the Quick Select function and simply turn the AVR on, store the
#					  source input, sync the volume, and repopulate the Audio settings menu variables. Make changes to support Material Skin
#					  as a new menu client, including collaborating on a way to avoid loading the Audio Settings menu for non-plugin players
#					  by inserting an array of player MAC addresses in the menu that the client can use to filter on. Prevent SqueezePlay
#					  players from trying to handle the Audio Settings menu. Customize menu functionality based on client app capability.
#					  For example, don't create slider control menus (Preamp and Channel levels) for Squeeze Ctrl, which can't handle them.
#					  Smooth out the volume control by streamlining the calculations and fine-tuning the buffering of requests.
#					  Restart playback from the beginning of the current song instead of the beginning of the playlist when powering on
#					  via a "Play" command. Various bug fixes.
#	2022/08/22 V4.6.2 - Improve the logic for powering on the AVR automatically during initialization after hitting "play" while the player
#					  is turned off. Fix another Windows blocking socket read problem during startup by reading the entire input table
#					  returned by the "SSFUN ?" request in one socket recv() command (Windows) or read() command (UNIX) using a 1024-byte
#					  input buffer. Finally smooth out the voluminous volume changes (~20 per second) coming from apps such as Squeezer
#					  without sudden jumps by implementing a smart throttling mechanism. Various other optimizations and bug fixes.
#	2022/10/2 V4.6.3 - Filter out callback notifications from players that are synced with ours but not using the plugin. Add the ability to
#					  specify an Input Source instead of a Quick Select in the setup menu for users whose AVR's lack the Quick Select feature
#					  or who just prefer that method. Fix another Windows blocking socket read problem in the plugin by reading the entire
#					  channel volume table returned by the "CV?" or "SIxxxxx" command into one 1024-byte input buffer. Changed all socket read
#					  requests to the AVR from read() to recv() for Windows only to hopefully eliminate any future blocking problems.
#	2022/10/31 V4.7 - Add "Multi-zone" support, which allows for switching between zones via the Audio Settings menu and thereby controlling
#					  and directing the audio signal to all zones of an AVR from one LMS player instance. Clean up some loose ends and
#					  fix some bugs.
#	2022/11/3 V4.7.1 - Fix a longstanding timing window that can cause multiple "power off" commands to be in effect simultaneously,
#					  resulting in a select() i/o error loop that can fill the file system and bring the LMS server down. Also added support
#					  for the Marantz PSMDAX group of commands, which are used in place of PSRSTR for the audio restorer menu items.
#					  fix some bugs.
#	2022/12/8 V4.7.2 - Fix another timing window that can cause multiple "power on" commands to be in effect simultaneously,
#					  resulting in a select() i/o error loop that can fill the file system and bring the LMS server down. Add Audio settings
#					  menu support for the Orange/Open Squeeze clients. Rewrite the logic that pauses and resumes playback during "power on"
#					  processing to make it more reliable and compatible with a wider range of AVR's by using the Quick Start delay value
#					  to determine how long to wait before resuming playback. Also resume (un-pause) playback directly rather than jumping
#					  back to the beginning of the current track in order to maintain compatability with the LMS Audio setting that determines
#					  what action to take on player power on/off. Allow the AVR to still be controlled by the Audio Settings menu after the
#					  player is turned off and the AVR left on due to the input having being changed, extending the functionality of the plugin
#					  menu as an AVR remote control outside of LMS. Clean up a few things in the debug log.
#	2023/3/29 V4.7.3 - Fix a bug in handling 'playerpref' callback events. Minor cosmetic changes.
#	2023/4/12 V4.7.4 - Make timeout value for AVR source changes context dependent (2 secs from audio menu, .25 secs at power on).
#	2023/9/27 V4.7.5 - Prevent a condition when building the Input Source Selection table that could put LMS in a loop during initialization.
#	2024/5/18 V5.0  - First release for Lyrion Music Server. Updating menus and wiki to reflect new naming conventions. Also changed the
#					  player registration logic to populate the $client->modelName field with a plugin signature: "Denon/Marantz AVR" for
#					  tracking purposes in the analytics plugin.
#	2024/7/13 V5.1  - Improve the usefulness and functionality of error, warning and info-level log messaging in the socket write error routine
#					  by adding the IP address of the AVR to warning messages, and the IP address and player name to the error messages that are
#					  logged after 10 consecutive errors. Add basic pattern validation for the IP Address field in the plugin setup menu to
#					  help guard against typos. The pattern requires input of the form "n[nn].n[nn].n[nn].n[nn][:p[pppp]]", which allows for
#					  optionally overriding the default port number of '23'. Also make the "Delay to set the Input Select Option" field numeric and
#					  enforce a range of 0 to 60 seconds.
#	2024/8/10 V5.2  - Add polling-based power and volume synchronization to notify the player when either of these AVR settings have changed
#					  outside the control of the plugin. Separate timer objects are used for power and volume polling. Power polling is
#					  required in order to use volume polling. Both are optional, selected from the plugin settings menu. The polling intervals
#					  for each type are also user configurable from the menu within predefined ranges --- 5-60 secs for power polling and 0-30 secs
#					  for volume polling, with 0 secs indicating that polling is inactive and volume will be synchronized only on track changes.
#					  Socket writes are now effectively made synchronous by not allowing two consecutive writes to the same IP address (AVR) without
#					  an intervening read or timeout, instead queueing the requests using a timer. This last change is a major one, and long overdue.
#					  Re-order the plugin settings menu to be more intuitive. Also add javascript code in the menu to enforce dependencies and ranges.
#					  Various other changes, corrections, tidying up, formatting, etc.
#	2024/8/14 V5.2.1 - Fix problem with power status polling interval default not being set.
#	2024/8/30 V5.3  - Add support for the Marantz MODEL M1 and Denon Home Amp streaming amplifiers. This is not a trivial change as the format of the
#					  Telnet volume control commands has changed with these devices. It remains to be seen if the new format will be present in other
#					  new products from these companies. If so, things could get even more complicated. Fixed timing problems caused by HDMI-CEC
#					  stealing our input during AVR power on, along with many other changes and improvements.
#	2024/11/21 V5.3.1 - Add support for "Tuner" and "HEOS Music" inputs to the "Input Source Select" Audio Settings menu for HEOS AVR's and omit
#					    unused inputs from that menu for all AVR's supporting the "SSSOD ?" telnet command.
#	2024/12/24 V5.3.2 - Work around an issue with new (2024/12/19) WiiM player firmware that won't allow setting the Volume Control to "Fixed at 100%".
#	2025/1/15 V5.3.3  - Add option to delay powering on the AVR until playback starts. Add support for the "DTS Neural:X" and "DTS:Virtual:X"
#						surround modes introduced in recent AVR's and allow for unknown surround modes when populating the Surround Mode menu.
#	2025/2/2 V5.3.4  - Beef up support for synced and grouped players by detecting power toggling in the playerPrefs callback routine.
#					   Only populate the input source table via SSSOD and SSFUN commands if at least one player is using the Audio Settings menus or
#					   has specified an AVR input source rather than a Quick Select command.
#	2025/2/22 V5.4  -  Only use the prefs-based polling interval for polling the AVR's power status when the player is ON. When the player is OFF, poll
#					   every 60 seconds.
#					   Add a way for client apps to determine that player volume commands should still be processed for players using the plugin even
#					   when the player's volume is "Fixed at 100%". This method will allow these client apps to replace their option to always process
#					   volume commands for these players with a way to make the determination on a player by player basis.
#					   Further support for players using the Groups plugin and routine code cleanup.
#	2025/6/12 V5.4.1 - Add support for single-zone Denon and Marantz streaming amplifiers other than the MODEL M1 and Home Amp that have
#					   reverted back to the traditional volume control format used in the past. It is unfortunate that the MODEL M1 and
#					   Home Amp have now become anomalies that must be given special treatment in the plugin. Multi-zone streaming amplifiers
#					   may have to be given yet another AVR type if support is required for them in the future.
#	2025/10/7 V5.4.2 - Fix problems beginning playback to powered off Denon/Marantz AVR UPnP players caused by buggy firmware (finally!).
#					   Always turn AVR off when player is turned off and no Quick Select or AVR input source has been specified for the player.
#					   Re-order the audio settings menu to make better sense.
#					   Limit AVR Input source in menu to 16 characters, as the AVR's do.
#					   Don't turn the AVR off from prefSetCallback() when changes are made for a powered off player.
#					   Add an option to automatically pause the player when the AVR Zone associated with it is switched to another input.
#	2025/11/03 V5.4.3 - Go back to leaving the AVR on when the player is turned off and no QS or Input Source has been specified.
#					   Prevent volume from being set to 100% when the player is turned off, due to WiiM firmware (mis)behavior. 
#	2025/12/16 V5.4.4 - Allow subwoofer level adjustment in Audio Settings for Pure and Pure Direct modes.
#					   Clean up some Audio Settings icons and reduce the size of the main Settings icon to better match others in Lyrion menus.

#	----------------------------------------------------------------------
#
#	This program is free software; you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation; either version 2 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program; if not, write to the Free Software
#	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
#	02111-1307 USA
#
package Plugins::DenonAvpControl::Plugin;
use strict;
use base qw(Slim::Plugin::Base);

use Slim::Utils::Strings qw(string);
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Misc;

use File::Spec::Functions qw(:ALL);
use FindBin qw($Bin);

use Plugins::DenonAvpControl::DenonAvpComms;
use Plugins::DenonAvpControl::Settings;


use Data::Dumper; #used to debug array contents

# ----------------------------------------------------------------------------
# Global variables
# ----------------------------------------------------------------------------
my $getexternalvolumeinfoCoderef; #used to report use of external volume control

#my $gOrigVolCmdFuncRef;		# Original function reference in SC
my $gOrigPlayerPrefCmdFuncRef;  # Original function reference for playerpref command

my %clientTable;  # Table of all clients, indexed by IP Addr, Zone, and QS

my $gPluginClients;  # Number of currently registered clients

# Per-client(player) persistent global variables
my %gIPAddress;
my %iPowerState;	# AVR power status, hashed by client and zone
my %iPowerOnInProgress;
my %iPowerOffInProgress;
my %iPaused; 		# indicates whether playback has been temporarily paused during power on
my %avrQSInput;		# AVR input associated with the player's defined Quick Select
my %outputLevelFixed;  # Used to indicate whether the player is using a fixed (100%) output level
my %gFixedVarToggleInProgress;  # Used in the pref callbacks to distinguish server from client requests
my %iInitialAvpVol; # Used to restore AVR volume to initial QS or amp default volume
my %iInputSyncInProgress; # Used to optionally pause the player when an AVR input change has been detected

# The following global hash variables are for use in the audio menu, hashed by client unless otherwise noted
my @clientIds = (); # Array of MAC addresses used by some client apps to filter players using the menu
my %gClientReg = (); # Hash table of flags indicating whether this MAC is registered
my %gModelInfo;  	# AVR make/model string returned from "SYMO" command, hashed by ipAddress
my %gInputTablePopulated;  # Used to indicate that an AVR input table has been populated, hashed by ipAddress
my %curAvrZone;		# The current AVR zone
my %curAvrSource;	# The current AVR input
my %curVolume; 		# Used to prevent unnecessary volume change commands, indexed by client and zone
my %channels = ();	# Channel Volume table, hashed by client and channel
my %preLevel;		# Denon preamp volume used for non fixed volume players, hashed by client
my %qSelect;		# Denon Quick Select last used for this player, hashed by client
my %inputs = ();	# Internal input name array, hashed by ipAddress and index
my %surroundMode;	# Denon Surround Mode Index
my %roomEq;			# Denon Room Equalizer Index
my %dynamicEq;		# Denon Dynamic Equalizer Index
my %nightMode;		# Denon Night Mode Index
my %restorer;		# Denon Restorer Index
my %refLevel;		# Denon Ref Level Index
my %subwoofer;		# Denon subwoofer active
my %isUPnP;			# Client is using the Lyrion UPnP bridge
my %gAllowQSUpdate;	# Used to block multiple QS updates from one menu instance
my %gMenuUpdate;	# Used to signal that no menu update should occur
my %gMenuPopulated;	# Used to indicate whether the menu should be re-populated
my %gRefreshCVTable;# Used to indicate if the channel volume table should be refreshed
my %gLastVolChange; # Time of the last AVR volume change
my %gDelayedVolChanges; # Number of consecutive delayed vol changes

# ----------------------------------------------------------------------------
# References to other classes
# my $classPlugin = undef;

# ----------------------------------------------------------------------------
my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.denonavpcontrol',
	'defaultLevel' => 'ERROR',
	'description'  => 'PLUGIN_DENONAVPCONTROL_MODULE_NAME',
});

# ----------------------------------------------------------------------------
my $prefs = preferences('plugin.denonavpcontrol');

# ----------------------------------------------------------------------------
sub initPlugin {
	my $classPlugin = shift;

	# Not Calling our parent class prevents adds it to the player UI for the audio options
	 $classPlugin->SUPER::initPlugin();

	# Initialize settings classes
	my $classSettings = Plugins::DenonAvpControl::Settings->new( $classPlugin);

	# Install callback to get client setup
	Slim::Control::Request::subscribe( \&newPlayerCheck, [['client'],['new', 'reconnect']]);

	# init the DenonAvpComms plugin
	Plugins::DenonAvpControl::DenonAvpComms->new( $classPlugin);

	# Display the plugin version in the log file
	my $xmlname = catdir(Slim::Utils::PluginManager->allPlugins->{'DenonAvpControl'}->{'basedir'}, 'install.xml');
	my $xml = new XML::Simple;
	my $data = $xml->XMLin($xmlname);

#	$log->debug( "install.xml\n" . Dumper($data) . "\n");
	$log->debug( "initPlugin: Version " . $data->{version} . "\n");

	# getexternalvolumeinfo
	$getexternalvolumeinfoCoderef = Slim::Control::Request::addDispatch(['getexternalvolumeinfo'],[0, 0, 0, \&getexternalvolumeinfoCLI]);
	$log->debug( "getexternalvolumeinfoCoderef: " . $getexternalvolumeinfoCoderef . "\n");

	# register callback for playerpref changes
	$gOrigPlayerPrefCmdFuncRef = Slim::Control::Request::addDispatch(['playerpref', '_prefname', '_newvalue'], [1, 0, 1, \&playerPrefCommand]);
	$log->debug( "playerPrefCommand callback registered.\n");

	$gPluginClients	= 0;  # init the number of active clients

	# Register dispatch methods for Audio menu options
	$log->debug("Getting the menu requests". "\n");

	#        |requires Client
	#        |  |is a Query
	#        |  |  |has Tags
	#        |  |  |  |Function to call
	#        C  Q  T  F

	Slim::Control::Request::addDispatch(['avpTop'],[1, 1, 0, \&avpTop]);
	Slim::Control::Request::addDispatch(['avpSM'],[1, 1, 0, \&avpSM]);
	Slim::Control::Request::addDispatch(['avpRmEq'],[1, 1, 0, \&avpRmEq]);
	Slim::Control::Request::addDispatch(['avpDynEq'],[1, 1, 0, \&avpDynEq]);
	Slim::Control::Request::addDispatch(['avpNM'],[1, 1, 0, \&avpNM]);
	Slim::Control::Request::addDispatch(['avpRes'],[1, 1, 0, \&avpRes]);
	Slim::Control::Request::addDispatch(['avpRefLvl'],[1, 1, 0, \&avpRefLvl]);
	Slim::Control::Request::addDispatch(['avpSwState'],[1, 1, 0, \&avpSwState]);
	Slim::Control::Request::addDispatch(['avpChannels'],[1, 1, 0, \&avpChannels]);
	Slim::Control::Request::addDispatch(['avpLvl'],[1, 1, 0, \&avpLvl]);
	Slim::Control::Request::addDispatch(['avpQuickSelect'],[1, 1, 0, \&avpQuickSelect]);
	Slim::Control::Request::addDispatch(['avpSourceSelect'],[1, 1, 0, \&avpSourceSelect]);
	Slim::Control::Request::addDispatch(['avpZoneSelect'],[1, 1, 0, \&avpZoneSelect]);
	Slim::Control::Request::addDispatch(['avpSetSM', '_surroundMode', '_oldSurroundMode'],[1, 1, 0, \&avpSetSM]);
	Slim::Control::Request::addDispatch(['avpSetRmEq', '_roomEq', '_oldRoomEq'],[1, 1, 0, \&avpSetRmEq]);
	Slim::Control::Request::addDispatch(['avpSetDynEq', '_dynamicEq', '_oldDynamicEq'],[1, 1, 0, \&avpSetDynEq]);
	Slim::Control::Request::addDispatch(['avpSetNM', '_nightMode', '_oldNightMode'],[1, 1, 0, \&avpSetNM]);
	Slim::Control::Request::addDispatch(['avpSetRes', '_restorer', '_oldRestorer'],[1, 1, 0, \&avpSetRes]);
	Slim::Control::Request::addDispatch(['avpSetRefLvl', '_refLevel', '_oldRefLevel'],[1, 1, 0, \&avpSetRefLvl]);
	Slim::Control::Request::addDispatch(['avpSetSw', '_subwoofer', '_oldSubwoofer'],[1, 1, 0, \&avpSetSw]);
	Slim::Control::Request::addDispatch(['avpSetChannels', '_channel', '_level'],[1, 1, 0, \&avpSetChannels]);
	Slim::Control::Request::addDispatch(['avpSetLvl', '_level'],[1, 1, 0, \&avpSetLvl]);
	Slim::Control::Request::addDispatch(['avpSetQuickSelect', '_quickSelect'],[1, 1, 0, \&avpSetQuickSelect]);
	Slim::Control::Request::addDispatch(['avpSaveQuickSelect', '_quickSelect'],[1, 1, 0, \&avpSaveQuickSelect]);
	Slim::Control::Request::addDispatch(['avpSetSource', '_source'],[1, 1, 0, \&avpSetSource]);
	Slim::Control::Request::addDispatch(['avpSetZone', '_zone'],[1, 1, 0, \&avpSetZone]);
	Slim::Control::Request::addDispatch(['avpPowerToggle', '_onOff', '_menuPopulated'],[1, 1, 0, \&avpPowerToggle]);
}

# ----------------------------------------------------------------------------
sub newPlayerCheck {
	my $request = shift;
	my $client = $request->client();

    if ( !defined($client) ) {
		$log->debug( "NewPlayerCheck entered without a valid client. \n");
#		$log->debug( "request data: " . Dumper($request) . "\n");
		return;
	}

	$log->debug( "".$client->name()." is: " . $client);

	# Do nothing if client is not a Receiver or Squeezebox
	if( !(($client->isa( "Slim::Player::Receiver")) || ($client->isa( "Slim::Player::Squeezebox2")))) {
		$log->debug( "Not a receiver or a squeezebox\n");
		#now clear callback for those clients that are not part of the plugin
		clearCallback();
		return;
	}

	#init the client
	my $cprefs = $prefs->client($client);
	my $pluginEnabled = $cprefs->get('pref_Enabled');

	# Do nothing if plugin is disabled for this client
	if ( !defined( $pluginEnabled) || $pluginEnabled == 0) {
		$log->debug( "Plugin Not Enabled for: ".$client->name()."\n");
		#now clear callback for those clients that are not part of the plugin
		clearCallback();
		return;
	} elsif (!length($cprefs->get('avpAddress')) ) {
		$log->debug( "No IP Address specified for: ".$client->name()."\n");
		#now clear callback for those clients that are not part of the plugin
		clearCallback();
		return;
	}

	if ($request->isCommand([['client'], ['reconnect']])) {
		$log->debug( "Player " . $client->name() . " is reconnecting\n");
		clearCallback();
	}


	my $avpIPAddress = "HTTP://" . $cprefs->get('avpAddress');
	if ( !($avpIPAddress =~ m/:\d+/) ) {  # only add the telnet port if one is not provided
		$avpIPAddress = $avpIPAddress . ":23";
	}

	my $quickSelect = $cprefs->get('quickSelect');
	my $zone = $cprefs->get('zone');
	my $gSpeakers = $cprefs->get('speakers');
	my $audioEnabled = $cprefs->get('pref_AudioMenu');
	my $multiZone = $cprefs->get('pref_MultiZone');
	my $avrType = $cprefs->get('pref_Avp');

	if (!$cprefs->get('pref_PowerSynch') ) {
		$cprefs->set('powerPoll', 60);  # set default polling interval for power polling
	}

	my $clientid = $client->id;

	$log->debug( "Plugin enabled for: " . $client->name() . "\n");
	$log->debug( "Quick Select: " . $quickSelect . "\n");
	$log->debug( "Zone: " . $zone . "\n");
	$log->debug( "Speakers: " . $gSpeakers . "\n");
	$log->debug( "Audio Menu Enabled: " . $audioEnabled . "\n");
	$log->debug( "Multi-zone Enabled: " . $multiZone . "\n");
	$log->debug( "AVR Type: " . $avrType . "\n");
	$log->debug( "IP Address: " . $avpIPAddress . "\n");
	$log->debug( "MAC Address: " . $client->macaddress() . "\n");
	$log->debug( "Client ID: " . $clientid . "\n");

	$avrQSInput{$client} = "";

	if ($client->modelName() eq "WiiM Player" && !$client->hasDigitalOut) {   # workaround until WiiM fixes this
		$log->debug("WiiM player 'hasDigitalOut' is OFF, overrriding to ON\n");
		$client->hasDigitalOut(1);  # allow updates to digitalVolumeControl
		preferences('server')->client($client)->set('digitalVolumeControl', 0);  # changed to fixed volume
	}

	$outputLevelFixed{$client} = !preferences('server')->client($client)->get('digitalVolumeControl');  # initialize fixed output level flag
	if ($outputLevelFixed{$client}) {
		$client->hasDigitalOut(0);  # so that client apps will know to allow volume changes
	}

	my $forv = $outputLevelFixed{$client} ? 'Fixed' : 'Variable';
	$log->debug("hasDigitalOut: " . $client->hasDigitalOut . "\n");
	$log->debug("digitalVolumeControl is: " . preferences('server')->client($client)->get('digitalVolumeControl') . "\n");
	$log->debug("Player output level is: " . $forv . "\n");
	$log->debug("Player model is: " . $client->modelName() . "\n");
	$isUPnP{$client} = $client->modelName() eq "UPnPBridge" && $client->name() =~ m/^Denon|^Marantz/;
	$log->debug("Player type is: " . $client->model() . "\n");
	$client->modelName("Denon/Marantz AVR");

	# initialize per-client global state variables
	$gIPAddress{$client} = $avpIPAddress;
	$gFixedVarToggleInProgress{$client} = 0;
	$curVolume{$client,$zone} = 0;
	$curAvrZone{$client} = $zone;
	$curAvrSource{$client} = "";
	$iPowerOnInProgress{$client} = 0;
	$iPowerOffInProgress{$client} = 0;
	$iPowerState{$client,$zone} = 0;
	$iInputSyncInProgress{$client} = 0;
	$iInitialAvpVol{$client} = calculateAvrVolume($client, 25);

	# Install callbacks to get client state changes
	Slim::Control::Request::subscribe( \&commandCallback, [['power', 'play', 'playlist', 'pause', 'mixer']], $client);
	#		Slim::Control::Request::subscribe( \&commandCallback, [['power', 'play', 'playlist', 'pause', 'mixer', 'stop', 'sync']], $client);
	Slim::Control::Request::subscribe( \&prefSetCallback, [['prefset']], $client);

	#		$log->debug( "client data: " . Dumper($client) . "\n");

	if (!$gClientReg{$clientid} ) {  # if this is a previously unregistered player
		$gClientReg{$clientid} = 1;
		push (@clientIds, $clientid);   # update the clientid array
		$log->debug("Added Client ID to clientid array\n");
		$log->debug("Client ID table is: @clientIds \n");
		$log->debug("Number of registered plugin players = " . ++$gPluginClients . "\n");

	}

	if ($client->power()) {    # turn the player off if currently on, to avoid confusion
		$log->debug("Turning " . $client->name() . " off to sync with plugin\n");
		$iPowerState{$client,$zone} = 0;
		my $request = $client->execute([('power', 0)]);
		# Add a result so we can detect this event and prevent a feedback loop
		$request->addResult('denonavpcontrolInitiated', 1);
	}

	#player menu
	if ($audioEnabled) {
		$log->debug("Calling the plugin menu register". "\n");
		# Create SP menu under audio settings
		my $icon = 'plugins/DenonAvpControl/html/images/denon_control.png';
		my @menu = ({
			stringToken   => $client->string('PLUGIN_DENONAVPCONTROL_MENU_HEADING'),
			id     => 'pluginDenonAvpControl',
			menuIcon => $icon,
			weight => 9,
			actions => {
				go => {
					player => \@clientIds,
					cmd	 => [ 'avpTop' ],
				}
			}
		});
		my @menu2 = ({
			stringToken   => $client->string('PLUGIN_DENONAVPCONTROL_MENU_HEADING'),
			id     => 'pluginDenonAvpControl_a',
			"icon" => $icon,
			weight => 9,
			actions => {
				go => {
					player => \@clientIds,
					cmd	 => [ 'avpTop' ],
				}
			}
		});
		Slim::Control::Jive::registerPluginMenu(\@menu, 'settingsPlayer' , $client);
		Slim::Control::Jive::registerPluginMenu(\@menu2, 'settings' , $client);

		# initialize per-client global menu variables
		$gMenuPopulated{$client} = 0;
		$preLevel{$client} = -1;
		$surroundMode{$client} = -1;
		$roomEq{$client} = -1;
		$dynamicEq{$client}	= -1;
		$nightMode{$client} = -1;
		$restorer{$client} = -1;
		$refLevel{$client} = -1;
		$subwoofer{$client} = -1;
		$qSelect{$client} = $quickSelect;
	}

	# get the model info from the AVR
	if ($avrType == 3) {  # Streaming amp
		$gModelInfo{$avpIPAddress} = "Marantz Model M1 or Denon Home Amp";
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 0.5 ), \&getAvpInputTable);
	} else {
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + (5 * $gPluginClients) + 0.5 ), \&getAvpModelInfo);
	}

	my $qsIndex = $quickSelect ? $quickSelect : $cprefs->get('inputSource');
	if ( !exists $clientTable{$avpIPAddress,$zone,$qsIndex} ) {
		# add the client to the client table
		$clientTable{$avpIPAddress,$zone,$qsIndex} = $client->name();
	}

	# check the initial power status if power syncing is turned on
	Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + (5 * $gPluginClients) + 1.5 ), \&handlePowerStatus);
}

# ----------------------------------------------------------------------------
sub getDisplayName {
	return 'PLUGIN_DENONAVPCONTROL';
}

# ----------------------------------------------------------------------------
sub shutdownPlugin {
	Slim::Control::Request::unsubscribe(\&newPlayerCheck);
	clearCallback();
}

# ----------------------------------------------------------------------------
sub clearCallback {

	$log->debug( "*** DenonAvpControl:Clearing command callback" . "\n");
	Slim::Control::Request::unsubscribe(\&commandCallback);
	Slim::Control::Request::unsubscribe(\&prefSetCallback);

	# Give up rerouting
}

# ----------------------------------------------------------------------------
# Handlers for player based menu integration
# ----------------------------------------------------------------------------

# Generates the top menus as elements of the Player Audio menu
sub avpTop {
	my $request = shift;
	my $client = $request->client();
	my $cprefs = $prefs->client($client);

	my $pluginEnabled = $cprefs->get('pref_Enabled');
	my $audioEnabled = $cprefs->get('pref_AudioMenu');
	my $prefZone = $cprefs->get('zone');
	my $multiZone = $cprefs->get('pref_MultiZone');

	my $clientApp = $client->controllerUA;

	my @menu = ();
	my $avrIcon = 'plugins/DenonAvpControl/html/images/denon_control.png';

	# Display a menu message if the plugin or the settings menu is disabled for this client
	if ( !defined( $pluginEnabled) || $pluginEnabled == 0 || $audioEnabled == 0 || $clientApp =~ m/^SqueezePlay/ ) {
		$log->debug( "Plugin/menu Not Enabled: skipping menu for " . $client->name() . "\n");
		push @menu, {
			text => $client->string('PLUGIN_DENONAVPCONTROL_MENU_NOT_ACTIVE'),
		};

		my $numitems = scalar(@menu);
		$request->addResult("count", $numitems);
		$request->addResult("offset", 0);

		my $cnt = 0;
		for my $eachPreset (@menu[0..$#menu]) {
			$request->setResultLoopHash('item_loop', $cnt, $eachPreset);
			$cnt++;
		}
		$request->setStatusDone();
		return;
	}

	my $avpIPAddress = $gIPAddress{$client};
	my $zone = $curAvrZone{$client};
	my $iPower = $iPowerState{$client,$zone};
	my $avp = $cprefs->get('pref_Avp');
	my $menuText = "";

	$gMenuUpdate{$client} = 0; #suspend updating menus from avp

	$log->debug("Adding the menu elements to the audio menu.\n" );
	$log->debug("Client UA string is: " . $clientApp );
	if ($avp == 1) {
		$log->debug( "Will use AVP menu commands. \n");
	} else {
		$log->debug( "Will use AVR menu commands. \n");
	}

	my $surroundIcon = 'plugins/DenonAvpControl/html/images/surround_modes.png';
	my $roomEqIcon = 'plugins/DenonAvpControl/html/images/room_eq.png';
	my $dynamicEqIcon = 'plugins/DenonAvpControl/html/images/dynamic_sound.png';
	my $dynamicVolIcon = 'plugins/DenonAvpControl/html/images/dynamic_vol.png';
	my $restorerIcon = 'plugins/DenonAvpControl/html/images/restorer.png';
	my $refIcon = 'plugins/DenonAvpControl/html/images/sliders_sm.png';
	my $chnIcon = 'plugins/DenonAvpControl/html/images/channel.png';
	my $swIcon = 'plugins/DenonAvpControl/html/images/subwoofer.png';
	my $volIcon = 'plugins/DenonAvpControl/html/images/volume.png';
	my $qsIcon = 'plugins/DenonAvpControl/html/images/subwoofer.png';
	my $sourceIcon = 'plugins/DenonAvpControl/html/images/select_source.png';
	my $zoneIcon = 'plugins/DenonAvpControl/html/images/zone_select.png';

	my $showSettings = 1;

	if ( ($iPower != 1 || $iPowerOnInProgress{$client} ) && !$gMenuPopulated{$client} ) {
		$showSettings = 0;    # this is for future use if a limited menu is allowed while powered off
	}

	my $PwrOn = 1;
	if ( (!$showSettings || $curAvrSource{$client} eq "") && !$iPowerOnInProgress{$client} ) {
		$PwrOn = 0;
	}

	my $modelInfo = "Model: " . $gModelInfo{$avpIPAddress};  # Display the model name & region

	if ( !($clientApp =~ m/^Squeeze-Control|OpenSqueeze|OrangeSqueeze/) ) {
		$modelInfo .= "\n";
	} else {
		$modelInfo .= " \xA0 ";    # Put everything on one line for Squeeze Ctrl and Orange/Open Squeeze
	}

#	if ( !($client->controllerUA =~ m/^iPeng/) && $avpIPAddress =~ /HTTP:\/\/([\d|.]+):\d+/ ) {
	if ( 0 ) {  	# skip the IP address for now
		$modelInfo .= "IP Address: " . $1;
		if ( ($clientApp =~ m/^Squeezer/ ) ) {
			$modelInfo .= "\n";
		} else {
			$modelInfo .= " \xA0 ";   # two spaces
		}
	}

	$modelInfo .= "Zone: ";

	if ($zone > 0) {
		$modelInfo .= ($zone+1);
	} else {
		$modelInfo .= "Main";
	}

	my $iMenu = 0;
	if ($showSettings && ($curAvrSource{$client} ne "") ) {
		$iMenu = 1;
	}

	$modelInfo .= " \xA0 Power: ";  # the embedded hex char is necessary for HTML (Material)

	if ($PwrOn == 0) {
		$modelInfo .= "OFF";
	} elsif ($iMenu == 0) {
		$modelInfo .= "INIT";
	} else {
		$modelInfo .= "ON";
	}

	if ( ($clientApp =~ m/^iPeng/ ) ) {  # use checkbox control for iPeng only
		push @menu,	{
				text => $modelInfo,
				id      => 'avpInfo',
				"icon" => $avrIcon,
				nextWindow => 'refresh',
				checkbox => $iMenu,
				actions  => {
					on  => {
						player => 0,
						cmd    => [ 'avpPowerToggle', 0, $iMenu ],
					},
					off  => {
						player => 0,
						cmd    => [ 'avpPowerToggle', 1, $iMenu ],
					},
				},
			};
	} else {   # use radio button for other clients
		push @menu,	{
				text => $modelInfo,
				id      => 'avpInfo',
				windowId   => 'avpInfo',
				"icon" => $avrIcon,
				nextWindow => 'refresh',
				radio => $iMenu,
				actions  => {
					do  => {
						player => 0,
						cmd    => [ 'avpPowerToggle', $PwrOn, $iMenu ],
					},
				},
			};
	}

	if ($iMenu && $outputLevelFixed{$client} && $multiZone ) {   # multizone support?
		$menuText = $client->string('PLUGIN_DENONAVPCONTROL_AUDIO11');  # zone select

		push @menu,	{
				text => $menuText,
				id      => 'zoneSelect',
				"icon" => $zoneIcon,
				actions  => {
					go  => {
						player => 0,
						cmd    => [ 'avpZoneSelect' ],
						params	=> {
							menu => 'avpZoneSelect',
						},
					},
				},
			};
	}

	if ($iMenu && ($zone == $prefZone)) {
		$menuText = $client->string('PLUGIN_DENONAVPCONTROL_AUDIO9');  # quick select
		if ($zone > 0) {
			$menuText .= "\nZone: " . ($zone+1);
		}

		push @menu,	{
				text => $menuText,
				id      => 'quickselect',
				"icon" => $swIcon,
				actions  => {
					go  => {
						player => 0,
						cmd    => [ 'avpQuickSelect' ],
						params	=> {
							menu => 'avpQuickSelect',
						},
					},
				},
			};

		$menuText = $client->string('PLUGIN_DENONAVPCONTROL_AUDIO10');  # source select
		if ($zone > 0) {
			$menuText .= "\nZone: " . ($zone+1);
		}

		push @menu,	{
				text => $menuText,
				id      => 'sourceSelect',
				"icon" => $sourceIcon,
				actions  => {
					go  => {
						player => 0,
						cmd    => [ 'avpSourceSelect' ],
						params	=> {
							menu => 'avpSourceSelect',
						},
					},
				},
			};

		if ($zone == 0) {  # only for main zone
			push @menu,	{
					text => $client->string('PLUGIN_DENONAVPCONTROL_AUDIO1'),
					id      => 'surroundmode',
					"icon" => $surroundIcon,
					actions  => {
						go  => {
							player => 0,
							cmd    => [ 'avpSM' ],
							params	=> {
								menu => 'avpSM',
							},
						},
					},
				};
		}

		if ( !($clientApp =~ m/^Squeeze-Control/) ) {   # skip slider controls for Squeeze Ctrl client
			if ($outputLevelFixed{$client} == 0) {
				$menuText = $client->string('PLUGIN_DENONAVPCONTROL_AUDIO0');
				if ($zone > 0) {
					$menuText .= "\nZone: " . ($zone+1);
				}

				push @menu,	{
						text => $menuText,
						id      => 'preLevel',
						"icon" => $volIcon,
						actions  => {
							go  => {
								player => 0,
								cmd    => [ 'avpLvl' ],
								params	=> {
									menu => 'avpLvl',
								},
							},
						},
					};
			}

			$menuText = $client->string('PLUGIN_DENONAVPCONTROL_AUDIO8');  # channel levels
			if ($zone > 0) {
				$menuText .= "\nZone: " . ($zone+1);
			}

			push @menu,	{
					text => $menuText,
					id      => 'channels',
					"icon" => $chnIcon,
					actions  => {
						go  => {
							player => 0,
							cmd    => [ 'avpChannels' ],
							params	=> {
								menu => 'avpChannels',
							},
						},
					},
				};
		}

		if ($zone == 0) {  # only for main zone
			push @menu,	{
					text => $client->string('PLUGIN_DENONAVPCONTROL_AUDIO2'),
					id      => 'roomequalizer',
					"icon" => $roomEqIcon,
					actions  => {
						go  => {
							player => 0,
							cmd    => [ 'avpRmEq' ],
							params	=> {
								menu => 'avpRmEq',
							},
						},
					},
				};

			push @menu,	{
					text => $client->string('PLUGIN_DENONAVPCONTROL_AUDIO3'),
					id      => 'dynamicequalizer',
					"icon" => $dynamicEqIcon ,
					actions  => {
						go  => {
							player => 0,
							cmd    => [ 'avpDynEq' ],
							params	=> {
								menu => 'avpDynEq',
							},
						},
					},
				};

			if ($avp == 1) {   # only for AVP
				push @menu,	{
					text => $client->string('PLUGIN_DENONAVPCONTROL_AUDIO4'),
					id      => 'nightmode',
					"icon" => $dynamicVolIcon,
					actions  => {
						go  => {
							player => 0,
							cmd    => [ 'avpNM' ],
							params	=> {
								menu => 'avpNM',
							},
						},
					},
				};
			}

			push @menu,	{
					text => $client->string('PLUGIN_DENONAVPCONTROL_AUDIO5'),
					id      => 'restorer',
					"icon" => $restorerIcon,
					actions  => {
						go  => {
							player => 0,
							cmd    => [ 'avpRes' ],
							params	=> {
								menu => 'avpRes',
							},
						},
					},
				};

			push @menu,	{
					text => $client->string('PLUGIN_DENONAVPCONTROL_AUDIO6'),
					id      => 'reflevel',
					"icon" => $refIcon,
					actions  => {
						go  => {
							player => 0,
							cmd    => [ 'avpRefLvl' ],
							params	=> {
								menu => 'avpRefLvl',
							},
						},
					},
				};

		}  # main zone

	}  # player is on and initialized

	my $numitems = scalar(@menu);
	$log->debug("Done setting up menu items: numitems=" . $numitems . "\n");

	$request->addResult("count", $numitems);
	$request->addResult("offset", 0);
	$request->addResult("window", { "windowStyle" => "icon_list" });

	my $cnt = 0;
	for my $eachPreset (@menu[0..$#menu]) {
		$request->setResultLoopHash('item_loop', $cnt, $eachPreset);
		$cnt++;
	}

	if (!$PwrOn || !$showSettings || $curAvrSource{$client} eq "") {
		$log->debug( "Player not on or not initialized: skipping full menu for " . $client->name() . "\n");
	} elsif (!$gMenuPopulated{$client} ) {   # only first time through after powered on or subsequent Quick Select
		$log->debug("Done with main menu setup");
		if ($zone == 0) {   # main menu for the main zone only
			# now check with the AVP to set the values of the settings
			Plugins::DenonAvpControl::DenonAvpComms::SendNetGetAvpSettings($client, $avpIPAddress, $gRefreshCVTable{$client});
		} else {   # get channel levels only for other zones
			Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpChannelLevels($client, $avpIPAddress, $zone);
		}
		$gMenuPopulated{$client} = 1;
	}

	$request->setStatusDone();
}


# Generates the Surround Mode menu, which is a list of all surround modes
sub avpSM {
	my $request = shift;
	my $client = $request->client();
	my $cprefs = $prefs->client($client);
	my $avp = $cprefs->get('pref_Avp');
	my $avpIPAddress = $gIPAddress{$client};

	my @menu = ();
	my $i = 0;
	my $check;
	$gMenuUpdate{$client} = 1; # update menus from avp

	$log->debug("The value of surroundMode is:" . $surroundMode{$client} . "\n");
	if ($avp != 1) {  # AVR's only
		while ($i <12) { #set the radio to the first item as default
			if ($i == $surroundMode{$client}) {
				$check = 1;
			} else {
				$check = 0;
			};
			push @menu, {
				text => $client->string('PLUGIN_DENONAVPCONTROL_SURMDR'.($i+1)),
				radio => $check,
				actions  => {
					do  => {
						player => 0,
						cmd    => [ 'avpSetSM', $i , $surroundMode{$client}],
					},
				},
			};

			$i++;
		}
	} else {
		while ($i <15) { #set the radio to the first item as default
			if ($i == $surroundMode{$client}) {
				$check = 1;
			} else {
				$check = 0;
			};
			push @menu, {
				text => $client->string('PLUGIN_DENONAVPCONTROL_SURMD'.($i+1)),
				radio => $check,
				actions  => {
					do  => {
						player => 0,
						cmd    => [ 'avpSetSM', $i , $surroundMode{$client}],
					},
				},
			};

			$i++;
		}
	}
	my $numitems = scalar(@menu);

	$request->addResult("count", $numitems);
	$request->addResult("offset", 0);
	my $cnt = 0;
	for my $eachItem (@menu[0..$#menu]) {
		$request->setResultLoopHash('item_loop', $cnt, $eachItem);
		$cnt++;
	}

	$request->setStatusDone();

	# check if menu not initialized and call AVP to see what mode its in
	if ($surroundMode{$client} == -1) {
		# call the AVP to get mode
		Plugins::DenonAvpControl::DenonAvpComms::SendNetGetAvpSettings($client, $avpIPAddress, "MS?");
	}
}

# Generates the Room equalizer menu
sub avpRmEq {
	my $request = shift;
	my $client = $request->client();
	my $cprefs = $prefs->client($client);
	my $avp = $cprefs->get('pref_Avp');
	my $avpIPAddress = $gIPAddress{$client};

	my @menu = ();
	my $i = 0;
	my $check;
	$gMenuUpdate{$client} = 1; # update menus from avp

	$log->debug("The value of roomEq is:" . $roomEq{$client} . "\n");

	if ($surroundMode{$client} < 2) {
		push @menu, {
			text => $client->string('PLUGIN_DENONAVPCONTROL_DIRECT_MSG')
		}
	} else {
		while ($i < 5) {

			if ($i == $roomEq{$client}) {
				$check = 1;
			} else {
				$check = 0;
			};

			push @menu, {
				text => $client->string('PLUGIN_DENONAVPCONTROL_RMEQ'.($i + 1)),
				radio => $check,
				actions  => {
					do  => {
						player => 0,
						cmd    => [ 'avpSetRmEq', $i, $roomEq{$client} ],
					},
				},
			};

			$i++;
		}
	}

	my $numitems = scalar(@menu);

	$request->addResult("count", $numitems);
	$request->addResult("offset", 0);
	my $cnt = 0;
	for my $eachItem (@menu[0..$#menu]) {
		$request->setResultLoopHash('item_loop', $cnt, $eachItem);
		$cnt++;
	}

	$request->setStatusDone();

	# check if menu not initialized and call AVP to see what mode its in
	if ($roomEq{$client} == -1) {
		if ($avp != 1) {
			# call the AVR to get mode
			Plugins::DenonAvpControl::DenonAvpComms::SendNetGetAvpSettings($client, $avpIPAddress, "PSMULTEQ: ?");
		} else {
			# call the AVP to get mode
			Plugins::DenonAvpControl::DenonAvpComms::SendNetGetAvpSettings($client, $avpIPAddress, "PSROOM EQ: ?");
		}
	}
}

# Generates the Dynamic equalizer menu
sub avpDynEq {
	my $request = shift;
	my $client = $request->client();
	my $cprefs = $prefs->client($client);
	my $avp = $cprefs->get('pref_Avp');
	my $avpIPAddress = $gIPAddress{$client};

	my @menu = ();
	my $i = 0;
	my $check;
	$gMenuUpdate{$client} = 1; # update menus from avp

	$log->debug("The value of dynamicEq is:" . $dynamicEq{$client} . "\n");

	my $stop = 3;
	if ($avp != 1) {$stop = 2};   # for AVR's
	if ($surroundMode{$client} < 2) {
		push @menu, {
			text => $client->string('PLUGIN_DENONAVPCONTROL_DIRECT_MSG')
		}
	} else {
		while ($i <$stop) {

			if ($i == $dynamicEq{$client}) {
				$check = 1;
			} else {
				$check = 0;
			};

			push @menu, {
				text => $client->string('PLUGIN_DENONAVPCONTROL_DYNVOL'.($i + 1)),
				radio => $check,
				actions  => {
					do  => {
						player => 0,
						cmd    => [ 'avpSetDynEq', $i, $dynamicEq{$client} ],
					},
				},
			};

			$i++;
		}
	}

	my $numitems = scalar(@menu);

	$request->addResult("count", $numitems);
	$request->addResult("offset", 0);
	my $cnt = 0;
	for my $eachItem (@menu[0..$#menu]) {
		$request->setResultLoopHash('item_loop', $cnt, $eachItem);
		$cnt++;
	}

	$request->setStatusDone();

	# check if menu not initialized and call AVP to see what mode its in
	if ($dynamicEq{$client} == -1) {
		if ($avp != 1) {
			# call the AVR to get mode
			Plugins::DenonAvpControl::DenonAvpComms::SendNetGetAvpSettings($client, $avpIPAddress, "PSDYNEQ ?");
		} else {
			# call the AVP to get mode
			Plugins::DenonAvpControl::DenonAvpComms::SendNetGetAvpSettings($client, $avpIPAddress, "PSDYN ?");
		}
	}
}

# Generates the Night Mode menu
sub avpNM {
	my $request = shift;
	my $client = $request->client();
	my $cprefs = $prefs->client($client);
	my $avp = $cprefs->get('pref_Avp');
	my $avpIPAddress = $gIPAddress{$client};

	my @menu = ();
	my $i = 0;
	my $check;
	$gMenuUpdate{$client} = 1; # update menus from avp

	$log->debug("The value of nightMode is:" . $nightMode{$client} . "\n");

	if ($surroundMode{$client} < 2) {
		push @menu, {
			text => $client->string('PLUGIN_DENONAVPCONTROL_DIRECT_MSG')
		}
	} else {
		if ($dynamicEq{$client} != 2) {
			push @menu, {
				text => $client->string('PLUGIN_DENONAVPCONTROL_NIGHT_MSG'),
			};
		};
		while ($i < 3) {
			if ($i == $nightMode{$client}) {
				$check = 1;
			} else {
				$check = 0;
			};
			if ($dynamicEq{$client} == 2) {
				push @menu, {
					text => $client->string('PLUGIN_DENONAVPCONTROL_NIGHT'.($i + 1)),
					radio => $check,
					actions  => {
						do  => {
							player => 0,
							cmd    => [ 'avpSetNM', $i, $nightMode{$client} ],
						},
					},
				};
			} else {
				#no actions because no Vol set
				push @menu, {
					text => $client->string('PLUGIN_DENONAVPCONTROL_NIGHT'.($i + 1)),
					radio => $check,
					actions  => {
					},
				};
			}
			$i++;
		}
	}

	my $numitems = scalar(@menu);

	$request->addResult("count", $numitems);
	$request->addResult("offset", 0);
	my $cnt = 0;
	for my $eachItem (@menu[0..$#menu]) {
		$request->setResultLoopHash('item_loop', $cnt, $eachItem);
		$cnt++;
	}

	$request->setStatusDone();

	# check if menu not initialized and call AVP to see what mode its in
	if ($nightMode{$client} == -1) {
		if ($avp == 1) {
			# call the AVP to get mode
			Plugins::DenonAvpControl::DenonAvpComms::SendNetGetAvpSettings($client, $avpIPAddress, "PSDYNSET ?");
		}
	}

}

# Generates the Restorer menu
sub avpRes {
	my $request = shift;
	my $client = $request->client();
	my $avpIPAddress = $gIPAddress{$client};

	my @menu = ();
	my $i = 0;
	my $check;
	$gMenuUpdate{$client} = 1; # update menus from avp

	$log->debug("The value of restorer is:" . $restorer{$client} . "\n");

	if ($surroundMode{$client} < 2) {
		push @menu, {
			text => $client->string('PLUGIN_DENONAVPCONTROL_DIRECT_MSG')
		}
	} else {
		while ($i < 4) {
			if ($i == $restorer{$client}) {
				$check = 1;
			} else {
				$check = 0;
			};
			push @menu, {
				text => $client->string('PLUGIN_DENONAVPCONTROL_REST'.($i + 1)),
				radio => $check,
			 actions  => {
			   do  => {
					player => 0,
					cmd    => [ 'avpSetRes' , $i, $restorer{$client}],
					params => {
					},
				},
			 },
			};

			$i++;
		}
	}

	my $numitems = scalar(@menu);

	$request->addResult("count", $numitems);
	$request->addResult("offset", 0);
	my $cnt = 0;
	for my $eachItem (@menu[0..$#menu]) {
		$request->setResultLoopHash('item_loop', $cnt, $eachItem);
		$cnt++;
	}

	$request->setStatusDone();

	# check if menu not initialized and call AVP to see what mode its in
	if ($restorer{$client} == -1) {
		# call the AVP to get mode
		Plugins::DenonAvpControl::DenonAvpComms::SendNetGetAvpSettings($client, $avpIPAddress, "PSRSTR ?");
	}
}

# Generates the Reference Level menu
sub avpRefLvl {
	my $request = shift;
	my $client = $request->client();
	my $avpIPAddress = $gIPAddress{$client};

	my @menu = ();
	my $i = 0;
	my $check;
	$gMenuUpdate{$client} = 1; # update menus from avp

	$log->debug("The value of refLevel is:" . $refLevel{$client} . "\n");

	if ($surroundMode{$client} < 2) {
		push @menu, {
			text => $client->string('PLUGIN_DENONAVPCONTROL_DIRECT_MSG')
		}
	} else {
		if ($dynamicEq{$client} == 0) { # not active when dynamic eq is off
			push @menu, {
				text => $client->string('PLUGIN_DENONAVPCONTROL_REF_LEVEL_MSG'),
			};
		} else {
			while ($i <4) {
				if ($i == $refLevel{$client}) {
					$check = 1;
				} else {
					$check = 0;
				};
				push @menu, {
					text => $client->string('PLUGIN_DENONAVPCONTROL_REF_LEVEL'.($i * 5)),
					radio => $check,
					actions  => {
						do  => {
							player => 0,
							cmd    => [ 'avpSetRefLvl' , $i, $refLevel{$client}],
							params => {
							},
						},
					},
				};

				$i++;
			}
		}
	}

	my $numitems = scalar(@menu);

	$request->addResult("count", $numitems);
	$request->addResult("offset", 0);
	my $cnt = 0;
	for my $eachItem (@menu[0..$#menu]) {
		$request->setResultLoopHash('item_loop', $cnt, $eachItem);
		$cnt++;
	}

	$request->setStatusDone();

	# check if menu not initialized and call AVP to see what mode its in
	if ($refLevel{$client} == -1) {
		# call the AVP to get mode
		Plugins::DenonAvpControl::DenonAvpComms::SendNetGetAvpSettings($client, $avpIPAddress, "PSREFLEV ?");
	}
}

# Generates the SW State menu
sub avpSwState {
	my $request = shift;
	my $client = $request->client();
	my $avpIPAddress = $gIPAddress{$client};

	my @menu = ();
	my $i = 0;
	my $check;
	$gMenuUpdate{$client} = 1; # update menus from amp

	$log->debug("The value of subwoofer is:" . $subwoofer{$client} . "\n");

	while ($i<2) {
		if ($i == $subwoofer{$client}) {
			$check = 1;
		} else {
			$check = 0;
		};
		push @menu, {
			text => $client->string('PLUGIN_DENONAVPCONTROL_SW'.($i+1)),
			radio => $check,
			actions  => {
				do  => {
					player => 0,
					cmd    => [ 'avpSetSw', $i , $subwoofer{$client}],
				},
			},
		};
		$i++;
	}

	my $numitems = scalar(@menu);

	$request->addResult("count", $numitems);
	$request->addResult("offset", 0);
	my $cnt = 0;
	for my $eachItem (@menu[0..$#menu]) {
		$request->setResultLoopHash('item_loop', $cnt, $eachItem);
		$cnt++;
	}

	$request->setStatusDone();

	# check if menu not initialized and call AVP to see what mode its in
	if ($subwoofer{$client} == -1) {
		# call the AVP to get mode
		Plugins::DenonAvpControl::DenonAvpComms::SendNetGetAvpSettings($client, $avpIPAddress, "PSSWR ?");
	}
}

# Generates the Quick Select menu
sub avpQuickSelect {
	my $request = shift;
	my $client = $request->client();
	my $cprefs = $prefs->client($client);
	my $avp = $cprefs->get('pref_Avp');
	my $avpIPAddress = $gIPAddress{$client};
	my $zone = $curAvrZone{$client};
	$log->debug("Quick Select menu routine entered..." );

	$log->debug("The value of qSelect is:" . $qSelect{$client} . "\n");

#	if ($channels{$client,"POPULATED"} == 0 ) {  # wait until channel table is populated
#		$log->debug("Channel table not populated: exiting");
#		$request->setStatusDone();
#		return;
#	}

	my @menu = ();
	my $i = 1;
	my $check;
	my $sText;
	my $lmt = 6;

	$gMenuUpdate{$client} = 1; # update menus from avp
	$gAllowQSUpdate{$client} = 1;  # allow only one QS update without intervening QS execution

	if ($avp == 1) { # less items for AVP
        $lmt = 4;
    }
	while ($i < $lmt) {
		if ($i == $qSelect{$client}) {
			$check = 1;
		} else {
			$check = 0;
		};

		my $tClient = $clientTable{$avpIPAddress,$zone,$i};  # Check for a QS client in this zone
		$log->debug("The value of tClient for ipAddress: " . $avpIPAddress . ", Zone: " . $zone . ", QS: " . $i . " is:" . $tClient. "\n");
		if ($tClient ne "") {
			$sText = " (" . $tClient . ")" ;   # show the client name in the list
		} else {
			$sText = "";
		}


		push @menu, {
			text => $client->string('PLUGIN_DENONAVPCONTROL_QUICK'.$i) . $sText,
			radio => $check,
			nextWindow => 'refresh',
			actions  => {
				do  => {
					player => 0,
					cmd    => [ 'avpSetQuickSelect', $i ],
				},
			},
		};

		$i++;
	}

	if ( $qSelect{$client}) {   # Allow the user to update the active Quick Select settings, if any
		$sText = $client->string('PLUGIN_DENONAVPCONTROL_QUICK_SAVE1') . "\n   " .
				 $client->string('PLUGIN_DENONAVPCONTROL_QUICK_SAVE2') . " " . $qSelect{$client} ;

		push @menu, {
			text => $sText,
			radio => 0,
			nextWindow => 'refresh',
			actions  => {
				do  => {
					player => 0,
					cmd    => [ 'avpSaveQuickSelect', $qSelect{$client} ],
				},
			},
		};
	}

	my $numitems = scalar(@menu);

	$request->addResult("count", $numitems);
	$request->addResult("offset", 0);
	my $cnt = 0;
	for my $eachItem (@menu[0..$#menu]) {
		$request->setResultLoopHash('item_loop', $cnt, $eachItem);
		$cnt++;
	}

	$request->setStatusDone();
}

# Generates the Zone Select menu
sub avpZoneSelect {
	my $request = shift;
	my $client = $request->client();
	my $zone = $curAvrZone{$client};
	my $cprefs = $prefs->client($client);
	my $prefZone = $cprefs->get('zone');

	$log->debug("Zone Select menu routine entered..." );
#	$log->debug("The current zone is:" . $zone . ":\n");

	my @menu = ();
	my $i = 0;
	my $check;

	$gMenuUpdate{$client} = 1; # update menus from avp
	my $zoneText = "Main";

	while ($i < 4 ) {
		if ($i == $zone) {    # if this is the current zone
			$check = 1;
		} else {
			$check = 0;
		};

		if ($i == $prefZone) {   # indicate the primary zone from prefs
			$zoneText .= " (Primary)";
		}

		push @menu, {
			text => $zoneText,
			radio => $check,
			nextWindow => 'parent',
			actions  => {
				do  => {
					player => 0,
					cmd    => [ 'avpSetZone', $i ],
				},
			},
		};

		$i++;
		$zoneText = "Zone " . ($i + 1);
	}

	my $numitems = scalar(@menu);

	$request->addResult("count", $numitems);
	$request->addResult("offset", 0);
	my $cnt = 0;
	for my $eachItem (@menu[0..$#menu]) {
		$request->setResultLoopHash('item_loop', $cnt, $eachItem);
		$cnt++;
	}

	$request->setStatusDone();
}

# Generates the Source Select menu
sub avpSourceSelect {
	my $request = shift;
	my $client = $request->client();
	my $avpIPAddress = $gIPAddress{$client};
	my $zone = $curAvrZone{$client};
	my $curSource = $curAvrSource{$client};
	my $numInputs = $inputs{$avpIPAddress,0};

	$log->debug("Source Select menu routine entered..." );
#	$log->debug("The current source is:" . $curSource . ":\n");

	my @menu = ();
	my $i = 1;
	my $check;

	$gMenuUpdate{$client} = 1; # update menus from avp

	while ($i <= $numInputs) {
#		$log->debug("Table entry #" . $i . " is: " . $inputs{$avpIPAddress,$i} . "\n");
		my ($avrSource, $userSource) = split (/\|/, $inputs{$avpIPAddress,$i});
#		$log->debug($avrSource . "," . $userSource . "\n");
		if ($avrSource eq $curSource) {    # if this is the currently active input
			$check = 1;
		} else {
			$check = 0;
		};

		push @menu, {
			text => $userSource,
			radio => $check,
			actions  => {
				do  => {
					player => 0,
					cmd    => [ 'avpSetSource', $avrSource ],
				},
			},
		};

		$i++;
	}

	my $numitems = scalar(@menu);

	$request->addResult("count", $numitems);
	$request->addResult("offset", 0);
	my $cnt = 0;
	for my $eachItem (@menu[0..$#menu]) {
		$request->setResultLoopHash('item_loop', $cnt, $eachItem);
		$cnt++;
	}

	$request->setStatusDone();
}

#Generates the Preamp Level menu for non fixed volume players
sub avpLvl {
	my $request = shift;
	my $client = $request->client();
	my $cprefs = $prefs->client($client);
	my $avpIPAddress = $gIPAddress{$client};

	$log->debug("Preamp level menu routine entered..." );

	my $level = int($preLevel{$client});

	if ($level > 99) { #3 digits for .5 db numbers
		$level = int($level / 10);  #remove .5 db if present
	}

	my $max = 80 + $cprefs->get('maxVol');	# max volume user wants AVP to be set to

	$gMenuUpdate{$client} = 1; # update menus from amp

	$log->debug("The value of preLevel is: " . $level . "\n");

	#determine if user is using db or 0-100 for volume settings  ????

	my @menu = ();

	push @menu, {
		text => $client->string('PLUGIN_DENONAVPCONTROL_VOLUME') . " (0-" .$max. "):  [" .$level."]",
		nextWindow => 'refresh',
	};

	push @menu, {
		slider	=> 1,
		min 	=> 0,
		max		=> $max,
		adjust 	=> 1,
		initial	=> $level,
		sliderIcons => '',
		nextWindow => 'refresh',
		actions	=> {
			do  => {
				player => 0,
				cmd    => [ 'avpSetLvl' ],
				params => {
					valtag => 'value',
				},
#				nextWindow => 'refresh',
			},
		},
	};

	my $numitems = scalar(@menu);

	$request->addResult("count", $numitems);
	$request->addResult("offset", 0);
	my $cnt = 0;
	for my $eachItem (@menu[0..$#menu]) {
		$request->setResultLoopHash('item_loop', $cnt, $eachItem);
		$cnt++;
	}

	# check if menu not initialized and call AVP to get the volume
	if ($preLevel{$client} == -1) {
		# call the AVP to get volume
		$log->debug("Calling SendNetAvpVolSetting...\n");
		Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpVolSetting($client, $avpIPAddress, 0);
	}

	$request->setStatusDone();
}

#gets the channel level setting from the AVP value
sub getChannelLevel {
	my $client = shift;
	my $avp_param = shift;
	my $avp_lvl = $channels{$client,$avp_param};
	my $value = 0;

	if ($avp_lvl < 38 || $avp_lvl > 615) {
		return 'ERROR';
	}

	if ($avp_lvl > 99) { #3 digits for .5 db numbers
		$value = int($avp_lvl / 10) - 50; #remove .5 db if present
	} else {
		$value = $avp_lvl - 50;
	}
	$value = sprintf("%+d", $value);
	return $value;
}

# Generates the Channels Level menu
sub avpChannels {
	my $request = shift;
	my $client = $request->client();
	my $cprefs = $prefs->client($client);
	my $speakers = $cprefs->get('speakers');
	my $zone = $curAvrZone{$client};
	my $avp = $cprefs->get('pref_Avp');
	my $avpIPAddress = $gIPAddress{$client};

	$log->debug("Channel levels menu routine entered..." );

	my @menu = ();
	my $parm;
	my $level = '0';

	if ($channels{$client,"POPULATED"} == 0 ) {  #table not populated
		$log->debug("Channel table not populated: exiting");
		$request->setStatusDone();
		return;
	}

	$gMenuUpdate{$client} = 1; # update menus from amp

	if ($zone == 0) {
		my $menuText = "Mode: ";
		my $i = $surroundMode{$client};
		if ($i == 99) {
			$menuText .= "Unknown";
		} elsif ($avp == 1) {
			$menuText .= $client->string('PLUGIN_DENONAVPCONTROL_SURMD'.($i+1));
		} else {
			$menuText .= $client->string('PLUGIN_DENONAVPCONTROL_SURMDR'.($i+1));
		}

		push @menu,	{
			text => $menuText,
			id      => 'surroundInfo',
		};
	}

	$parm = 'CVFL';
	#$log->debug("The param is:" .$parm . "\n");
	$level = getChannelLevel($client,$parm);
	#$log->debug("The value param is:" .$level . "\n");

#	$log->debug("Level of FL speaker is: " . $level. "\n");

	push @menu, {
		text => $client->string('PLUGIN_DENONAVPCONTROL_'.$parm) . "  [".$level."dB]",
		nextWindow => 'refresh',
	};
	push @menu, {
		slider	=> 1,
		min 	=> -12 + 0,
		max		=> 12,
		#text	=> 'Left',
		#help    => 'help text',
		adjust 	=> 1,
		initial	=> $level,
		sliderIcons => '',
		nextWindow => 'refresh',
		actions	=> {
			do  => {
				player => 0,
				cmd    => [ 'avpSetChannels', $parm ],
				params => {
					valtag => 'value',
				},
			},
		},
	};

	$parm = 'CVFR';
	$level = getChannelLevel($client,$parm);

	push @menu, {
		text => $client->string('PLUGIN_DENONAVPCONTROL_'.$parm) . "  [".$level."dB]",
		nextWindow => 'refresh',
	};
	push @menu, {
		slider => 1,
		min 	=> -12 + 0,
		max		=> 12,
		adjust 	=> 1,
		initial	=> $level,
		sliderIcons => '',
		nextWindow => 'refresh',
		actions	=> {
			do  => {
				player => 0,
				cmd    => [ 'avpSetChannels', $parm ],
				params => {
					valtag => 'value',
				},
			},
		},
	};

	if ($zone == 0 && $surroundMode{$client} != 99 ) {  # main zone only
		if ($surroundMode{$client} > 2 ) { # center channel if not PURE/DIRECT or STEREO
			$parm = 'CVC';
			$level = getChannelLevel($client,$parm);

			push @menu, {
				text => $client->string('PLUGIN_DENONAVPCONTROL_'.$parm) . "  [".$level."dB]",
				nextWindow => 'refresh',
			};
			push @menu, {
				slider => 1,
				min 	=> -12 + 0,
				max		=> 12,
				adjust 	=> 1,
				initial	=> $level,
				#sliderIcons => 'volume',
				sliderIcons => '',
				nextWindow => 'refresh',
				actions	=> {
					do  => {
						player => 0,
						cmd    => [ 'avpSetChannels', $parm ],
						params => {
							valtag => 'value',
						},
					},
				},
			};
		};  # center channel

		# subwoofer channel
		if ($avp == 1) {
			$parm = 'CVSW1';
		} else {
			$parm = 'CVSW';
		}
		$level = getChannelLevel($client,$parm);


		push @menu, {
			text => $client->string('PLUGIN_DENONAVPCONTROL_'.$parm) . "  [".$level."dB]",
			nextWindow => 'refresh',
		};
		push @menu, {
			slider => 1,
			min 	=> -12 + 0,
			max		=> 12,
			adjust 	=> 1,
			initial	=> $level,
			sliderIcons => '',
			nextWindow => 'refresh',
			actions	=> {
				do  => {
					player => 0,
					cmd    => [ 'avpSetChannels', $parm ],
					params => {
						valtag => 'value',
					},
				},
			},
		};

		# surround channels
		if ($surroundMode{$client} > 2 ) {  # ignore the remaining channels for PURE/DIRECT	and STEREO
			if ($speakers > 0) {
				$parm = 'CVSL';
				$level = getChannelLevel($client,$parm);

				push @menu, {
					text => $client->string('PLUGIN_DENONAVPCONTROL_'.$parm) . "  [".$level."dB]",
					nextWindow => 'refresh',
				};
				push @menu, {
					slider => 1,
					min 	=> -12 + 0,
					max		=> 12,
					adjust 	=> 1,
					initial	=> $level,
					sliderIcons => '',
					nextWindow => 'refresh',
					actions	=> {
						do  => {
							player => 0,
							cmd    => [ 'avpSetChannels', $parm ],
							params => {
								valtag => 'value',
							},
						},
					},
				};
				$parm = 'CVSR';
				$level = getChannelLevel($client,$parm);

				push @menu, {
					text => $client->string('PLUGIN_DENONAVPCONTROL_'.$parm) . " [".$level."dB]",
					nextWindow => 'refresh',
				};
				push @menu, {
					slider => 1,
					min 	=> -12 + 0,
					max		=> 12,
					adjust 	=> 1,
					initial	=> $level,
					sliderIcons => '',
					nextWindow => 'refresh',
					actions	=> {
						do  => {
							player => 0,
							cmd    => [ 'avpSetChannels', $parm ],
							params => {
								valtag => 'value',
							},
						},
					},
				};
			} #if ($speakers > 0)

			if ($speakers == 2) { #front height
				$parm = 'CVFHL';
				$level = getChannelLevel($client,$parm);
				push @menu, {
					text => $client->string('PLUGIN_DENONAVPCONTROL_'.$parm) . "  [".$level."dB]",
					nextWindow => 'refresh',
				};
				push @menu, {
					slider => 1,
					min 	=> -12 + 0,
					max		=> 12,
					adjust 	=> 1,
					initial	=> $level,
					#sliderIcons => 'volume',
					sliderIcons => '',
					nextWindow => 'refresh',
					actions	=> {
						do  => {
							player => 0,
							cmd    => [ 'avpSetChannels', $parm ],
							params => {
								valtag => 'value',
							},
						},
					},
				};

				$parm = 'CVFHR';
				$level = getChannelLevel($client,$parm);

				push @menu, {
					text => $client->string('PLUGIN_DENONAVPCONTROL_'.$parm) . "  [".$level."dB]",
					nextWindow => 'refresh',
				};
				push @menu, {
					slider => 1,
					min 	=> -12 + 0,
					max		=> 12,
					adjust 	=> 1,
					initial	=> $level,
					sliderIcons => '',
					nextWindow => 'refresh',
					actions	=> {
						do  => {
							player => 0,
							cmd    => [ 'avpSetChannels', $parm ],
							params => {
								valtag => 'value',
							},
						},
					},
				};
			} elsif ($speakers == 3) { #front wide
				$parm = 'CVFWL';
				$level = getChannelLevel($client,$parm);

				push @menu, {
					text => $client->string('PLUGIN_DENONAVPCONTROL_'.$parm) . "  [".$level."dB]",
					nextWindow => 'refresh',
				};
				push @menu, {
					slider => 1,
					min 	=> -12 + 0,
					max		=> 12,
					adjust 	=> 1,
					initial	=> $level,
					sliderIcons => '',
					nextWindow => 'refresh',
					actions	=> {
						do  => {
							player => 0,
							cmd    => [ 'avpSetChannels', $parm ],
							params => {
								valtag => 'value',
							},
						},
					},
				};

				$parm = 'CVFWR';
				$level = getChannelLevel($client,$parm);

				push @menu, {
					text => $client->string('PLUGIN_DENONAVPCONTROL_'.$parm) . "  [".$level."dB]",
					nextWindow => 'refresh',
				};
				push @menu, {
					slider => 1,
					min 	=> -12 + 0,
					max		=> 12,
					adjust 	=> 1,
					initial	=> $level,
					sliderIcons => '',
					nextWindow => 'refresh',
					actions	=> {
						do  => {
							player => 0,
							cmd    => [ 'avpSetChannels', $parm ],
							params => {
								valtag => 'value',
							},
						},
					},
				};
			} elsif ($speakers == 4) { #back
				$parm = 'CVSBL';
				$level = getChannelLevel($client,$parm);

				push @menu, {
					text => $client->string('PLUGIN_DENONAVPCONTROL_'.$parm) . "  [".$level."dB]",
					nextWindow => 'refresh',
				};
				push @menu, {
					slider => 1,
					min 	=> -12 + 0,
					max		=> 12,
					adjust 	=> 1,
					initial	=> $level,
					sliderIcons => '',
					nextWindow => 'refresh',
					actions	=> {
						do  => {
							player => 0,
							cmd    => [ 'avpSetChannels', $parm ],
							params => {
								valtag => 'value',
							},
						},
					},
				};

				$parm = 'CVSBR';
				$level = getChannelLevel($client,$parm);

				push @menu, {
					text => $client->string('PLUGIN_DENONAVPCONTROL_'.$parm) . "  [".$level."dB]",
					nextWindow => 'refresh',
				};
				push @menu, {
					slider => 1,
					min 	=> -12 + 0,
					max		=> 12,
					adjust 	=> 1,
					initial	=> $level,
					sliderIcons => '',
					nextWindow => 'refresh',
					actions	=> {
						do  => {
							player => 0,
							cmd    => [ 'avpSetChannels', $parm ],
							params => {
								valtag => 'value',
							},
						},
					},
				};
			}
		}  # surround channels
	}  # if zone == 0

	my $numitems = scalar(@menu);

	$request->addResult("count", $numitems);
	$request->addResult("offset", 0);
	my $cnt = 0;

	for my $eachItem (@menu[0..$#menu]) {
		$request->setResultLoopHash('item_loop', $cnt, $eachItem);
		$cnt++;
	}

	$request->setStatusDone();
}

# ----------------------------------------------------------------------------
# Callback to grab client playerpref changes
# ----------------------------------------------------------------------------
sub playerPrefCommand {
	my $request = shift;

	# Do nothing if request is not defined
	if(!defined( $request)) {
		$log->debug( "playerPrefCommand() Request is not defined \n");
		return;
	}

	my $client = $request->client();

	# Do nothing if client is not defined
	if(!defined( $client)) {
		$log->debug( "playerPrefCommand() Client is not defined \n");
		$request->setStatusBadDispatch();
		return;
	}

	my $prefName = $request->getParam('_prefname');

#	$log->debug( "request: " . Dumper($request) . "\n");
#	$log->debug( "Player: " . $client->name() . ", Prefname: " . $prefName . "\n");

	# Only process if changing the Fixed vs Variable volume setting for one of our players
	if ( $gClientReg{$client->id} && ($prefName eq "digitalVolumeControl") ) {
		my $tempLevelFixed = !($request->getParam('_newvalue'));
		if ($tempLevelFixed ne $outputLevelFixed{$client}) {
			my $zone = $curAvrZone{$client};
			my $avpIPAddress = $gIPAddress{$client};
			if ( $client->power() ) {  # only if the player is turned on
				if ( $tempLevelFixed ) {  # changing from variable to fixed, so mute AVR
					Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpMuteToggle($client, $avpIPAddress, $zone, 1);  # mute the AVR
				}
				else {  # changing from fixed to variable, so unmute AVR if needed
					if ($curVolume{$client,$zone} <= 0) {
						Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpMuteToggle($client, $avpIPAddress, $zone, 0);  # unmute the AVR
					}
				}
			}
			$gFixedVarToggleInProgress{$client} = 1;  # so we can finish this in prefSetCallback
		}
		# call original function after a delay
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + .5), \&playerPrefCmdFuncRef, $request);
	}
	else {
		&{$gOrigPlayerPrefCmdFuncRef}($request);  # call original function
	}
}

# ----------------------------------------------------------------------------
# Call original playerPref function
# ----------------------------------------------------------------------------
sub playerPrefCmdFuncRef {
	my $client = shift;
	my $request = shift;

	&{$gOrigPlayerPrefCmdFuncRef}($request);  # call original function
}

# ----------------------------------------------------------------------------
# Callback to get server prefset changes
# ----------------------------------------------------------------------------
sub prefSetCallback {
	my $request = shift;
	my $client = $request->client();

	# Do nothing if client is not defined
	if(!defined( $client)) {
		$log->debug( "prefSetCallback() Client is not defined \n");
		return;
	}

	my $nameSpace = $request->getParam('_namespace');
	my $prefName = $request->getParam('_prefname');

#	$log->debug( "request: " . Dumper($request) . "\n");
#	$log->debug( "Player: " . $client->name() . ", NameSpace: " . $nameSpace . ", PrefName: " . $prefName . "\n");

	if (!$gClientReg{$client->id} ) {   # Ignore if this is an unregistered player (possibly synced)
		$log->debug( "prefSetCallback() Player " . $client->name() . " is not registered\n");
		return;
	}

	my $cprefs = $prefs->client($client);
	my $prefZone = $cprefs->get('zone');
	my $prefPowerOnPlay = $cprefs->get('pref_PowerOnPlay');

	if ( !$client->power() ) {  # if player is not on, check to see if we need to turn off the AVR
		$log->debug( "prefSetCallback() Player " . $client->name() . " is powered off\n");

		# if the AVR is on, turn it off
		# TESTING - avoid powering the AVR off unnecessarily

#		if ($iPowerState{$client,$prefZone} && !$iPowerOffInProgress{$client} && !$iPowerOnInProgress{$client}) {
#			$log->debug( "prefSetCallback() Turning the AVR off\n");
#			my $gPowerOffDelay = 0.1;
#			$iPowerOffInProgress{$client} = 1;  # prevent re-entry
#			Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + $gPowerOffDelay), \&handlePowerOff);
#		}
	}
	elsif (!$prefPowerOnPlay && !$iPowerState{$client,$prefZone} && !$iPowerOnInProgress{$client}) {  # if the AVR is off, turn it on
		$log->debug( "prefSetCallback() Player " . $client->name() . " is powered on\n");
		$log->debug( "prefSetCallback() Turning the AVR on\n");
		my $request = $client->execute([('power', 1)]);  # power AVR on
	}

	if ( ($nameSpace eq "server") && ($prefName eq "digitalVolumeControl") ) {
		my $tempLevelFixed = !($request->getParam('_newvalue'));
		if ($tempLevelFixed ne $outputLevelFixed{$client}) {
			$outputLevelFixed{$client} = $tempLevelFixed;
			my $forv = $tempLevelFixed ? 'Fixed' : 'Variable';
			$log->debug("prefSetCallback() New player output level is: $forv \n");
			my $zone = $curAvrZone{$client};
			my $avpIPAddress = $gIPAddress{$client};
			if ( $tempLevelFixed ) {  # changing from variable to fixed, so sync AVR preamp volume to client
				if (!$gFixedVarToggleInProgress{$client} && $client->power()) {  # only need to do this if coming from server
					Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpMuteToggle($client, $avpIPAddress, $zone, 1);  # mute the AVR
				}
				$log->debug("prefSetCallback() Syncing AVR and client volumes\n");
				my $sbVolume = calculateSBVolume($client, $iInitialAvpVol{$client});
				handleVolSet( $client, $sbVolume);  # set volume level to initial value
				$client->hasDigitalOut(0);  # so that client apps will know to allow volume changes
			}
			else {   # changing from fixed to variable, so unmute AVR if necessary and reset curVolume
				if (!$gFixedVarToggleInProgress{$client} && $client->power()) {  # only need to do this if coming from server
					if ($curVolume{$client,$zone} <= 0) {
						Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpMuteToggle($client, $avpIPAddress, $zone, 0);  # unmute the AVR
					}
				}
				if ($zone == 0) {  # set preamp volume for audio menu
					$preLevel{$client} = abs($curVolume{$client,$zone});
				}
				$curVolume{$client,$zone} = 0;
				$client->hasDigitalOut(1);  # so player can be returned to fixed volume
			}
			$gFixedVarToggleInProgress{$client} = 0;
		}
	}
}

# ----------------------------------------------------------------------------
# Callback to get client state changes
# ----------------------------------------------------------------------------
sub commandCallback {
	my $request = shift;

	if (!$request) {
		return;
	}

	$log->debug( "commandCallback() p0: " . $request->{'_request'}[0] . "\n");
	$log->debug( "commandCallback() p1: " . $request->{'_request'}[1] . "\n");
	$log->debug( "commandCallback() p2: " . $request->getParam('_newvalue') . "\n");

	if ($request->isCommand([['displaynotify']]) ) {   # This should no longer happen after LMS fix #820
		return;
	}

	my $client = $request->client();

	# Do nothing if client is not defined
	if(!defined( $client)) {
		$log->debug( "commandCallback() Client is not defined \n");
		return;
	}

	$log->debug( "commandCallback() Player: " . $client->name() . "\n");

	if (!$gClientReg{$client->id} ) {   # Ignore if this is an unregistered player (possibly synced)
		$log->debug( "commandCallback() Unregistered player - bypassing \n");
		return;
	}

	if ($request->getResult('denonavpcontrolInitiated') ) {   # Ignore if it's our request
		$log->debug( "commandCallback() Self-initiated command - bypassing \n");
		return;
	}


	my $cprefs = $prefs->client($client);
	my $quickSelect = $cprefs->get('quickSelect');
	my $volumeSynch = $cprefs->get('pref_VolSynch');
	my $prefZone = $cprefs->get('zone');
	my $prefPowerOnPlay = $cprefs->get('pref_PowerOnPlay');

	my $timersRemoved;

	my $gPowerOnDelay = 0.1;				# Delay to turn on amplifier after player has been turned on (in seconds)
	my $gPowerOffDelay = 0.1;				# Delay to turn off amplifier after player has been turned off (in seconds)

	my $iPower = $client->power();		# Current player power state
	my $avpIPAddress = $gIPAddress{$client};

	# Get power on and off commands
	# Sometimes we do get only a power command, sometimes only a play/pause command and sometimes both
	if ( $request->isCommand([['power']])
	 || $request->isCommand([['play']])
	 || ($request->isCommand([['pause']]) && ($request->getParam('_newvalue') eq '0'))  # unpause but not pause
	 || $request->isCommand([['playlist'], ['play']])
	 || $request->isCommand([['playlist'], ['jump']])
	 || $request->isCommand([['playlist'], ['newsong']]) ) {
#		$log->debug("Power request1: $request \n");
		# Check with last known power state -> if different switch modes
		if ( ($iPowerState{$client,$prefZone} != $iPower) || $request->isCommand([['power']])) {
			$log->debug("commandCallback() Power: $iPower \n");
			if ( $iPower == 1 ) {
				if (!$prefPowerOnPlay || !$request->isCommand([['power']]) ) {
					if ( ($curAvrZone{$client} == $prefZone || $request->isCommand([['power']]))
							&& !$iPowerOnInProgress{$client} ) {  # power on primary zone
						# If player is turned on within delay, kill delayed power on/off timers
						Slim::Utils::Timers::killTimers( $client, \&handleSendPowerOn);  # should be unnecessary but...
						Slim::Utils::Timers::killTimers( $client, \&handlePowerOff);

						$iPowerState{$client,$prefZone} = 1;
						$iPowerOnInProgress{$client} = 1;
						$iPowerOffInProgress{$client} = 0;
						$curAvrZone{$client} = $prefZone;
						$gMenuPopulated{$client} = 0;
						$gLastVolChange{$client} = 0;
						$gDelayedVolChanges{$client} = 0;
						$iPaused{$client} = 0;
						$gRefreshCVTable{$client} = 1;  # refresh the channel volume table

						$iInitialAvpVol{$client} = calculateAvrVolume($client, 25);  # default to 25%
						$qSelect{$client} = $quickSelect;

						if ($request->isCommand([['play']]) || $request->isCommand([['playlist']])) {  # only play and playlist
							$log->debug("commandCallback() Pausing playback during power-on \n");
							my $request = $client->execute([('pause', '1')]);
							$request->addResult('denonavpcontrolInitiated', 1);
							$iPaused{$client} = 1;
						}

						# Check to see if player is set to fixed or variable output level
						my $forv = $outputLevelFixed{$client} ? 'Fixed' : 'Variable';
						$log->debug("commandCallback() Power On for AVP/AVR model: $gModelInfo{$avpIPAddress}" );
						$log->debug("commandCallback() Player output level is: $forv \n");

						Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + $gPowerOnDelay), \&handleSendPowerOn);
					}
				}
			} else {  # power off all zones
				# If player is turned off within delay, kill any delayed power timers
				Slim::Utils::Timers::killTimers( $client, \&handleSendPowerOn);
				Slim::Utils::Timers::killTimers( $client, \&handlePowerOff);
				$iPowerOffInProgress{$client} = 1;  # prevent re-entry

				if ( $iPowerOnInProgress{$client}) {
					$gPowerOffDelay += 5;  # allow time for power on to finish
				}
				Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + $gPowerOffDelay), \&handlePowerOff);
			}
		} elsif ( $iPowerOnInProgress{$client}) {   # pause or stop players during power on
			if ( !$request->isCommand([['pause']]) && ($iPaused{$client} < 2) ) {   # only for power, play and playlist (not pause)
				my $request;
				if ( !$isUPnP{$client} ) {  #  pause non-UPnP players during power on
					$log->debug("commandCallback() Pausing playback during power-on \n");
					$request = $client->execute([('pause', '1')]);
				} else {  # stop UPnP players
					$log->debug("commandCallback() Stopping playback during power-on \n");
					$request = $client->execute([('stop')]);
				}
				$request->addResult('denonavpcontrolInitiated', 1);
				$iPaused{$client} = 1;
			}
		} elsif ( $iPower == 1 && !$iPowerOnInProgress{$client}) {    # handle volume syncing and double-pause QS after power is on
		  	if ( $request->isCommand([['playlist'], ['newsong']]) && $outputLevelFixed{$client} && $volumeSynch ) {
				# Kill outstanding volume requests
				Slim::Utils::Timers::killTimers( $client, \&handleVolumeRequest);
				Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 0.25), \&handleVolumeRequest);
			} elsif ( $request->isCommand([['pause']]) && $quickSelect != 0 ) {   # check for 2 pauses in .5 secs for Quick Select
				# kill any dummy pauses that may be going on within the timer
				$timersRemoved = Slim::Utils::Timers::killTimers( $client, \&handleDummyPause);
				if ( $timersRemoved ) {
					$iPowerOnInProgress{$client} = 1;  # block other commands until QS completes
					$iInitialAvpVol{$client} = calculateAvrVolume($client, 25);
					$avrQSInput{$client} = "" ;
					$gMenuPopulated{$client} = 0;
					$gRefreshCVTable{$client} = 1;  # refresh the channel volume table
					$iPaused{$client} = 0;
					$log->debug("Dummy pause timers killed: $timersRemoved \n");
					Slim::Utils::Timers::killTimers( $client, \&handleQuickSelect);
					Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 1), \&handleQuickSelect, 2);
				} else {
					# delay the dummy pause by .5 second to check for Quick Select
					Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + .5), \&handleDummyPause);
				}
			}
		}
	# Get clients volume adjustment
	} elsif ( $request->isCommand([['mixer'], ['volume']]) && $outputLevelFixed{$client} ) {
		if ( !$iPowerOnInProgress{$client} ) {
			my $volAdjust = $request->getParam('_newvalue');
			
			# special case to catch player firmware bug that sets vol to 100 when output level is fixed
			if ( $volAdjust == 100) {
				$log->debug("*** DenonAvpControl:Volume set to 100% for " . $client->name() . " : changing to initial value\n");
				my $sbVolume = calculateSBVolume($client, $iInitialAvpVol{$client});
				handleVolSet( $client, $sbVolume, 1);  # set volume level to initial value
				return;
			}

			if ( $curAvrSource{$client} ne "") {
				$log->debug("*** DenonAvpControl:new SB vol: $volAdjust  \n");

				my $char1 = substr($volAdjust,0,1);
				my $getVolFromPlayer = 0;

				#if it's an incremental adjustment, get the new volume from the client
				if (($char1 eq '-') || ($char1 eq '+')) {
					my $zone = $curAvrZone{$client};
					if ($curVolume{$client,$zone} < 0) {
						$volAdjust += abs($curVolume{$client,$zone});  # compensate for LMS setting volume to 0 after mute
						handleVolSet( $client, $volAdjust, 1);  # set client volume
					}
					else {
						$getVolFromPlayer = 1;  # wait until we actually process the volume change
					}
				}

				# kill any volume changes that may be going on within the timer
				$timersRemoved = Slim::Utils::Timers::killTimers( $client, \&handleVolChanges);

				# Kill outstanding mute requests
				Slim::Utils::Timers::killTimers( $client, \&handleMutingToggle);
				my $lastVolChange = Time::HiRes::time() - $gLastVolChange{$client};
				my $iDelay = .25;  # set default volume change delay time
				if ( $lastVolChange > 2 || ($lastVolChange > $iDelay  && $gDelayedVolChanges{$client} > 3)) {
					# near-immediate vol change if it's been more than the default delay time and changes are backed up (or 2 secs otherwise)
					$iDelay = 0.01;
				} else {  # delay for the default time
					$gDelayedVolChanges{$client}++;   # increment the delayed vol change count
				}
				Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + $iDelay ), \&handleVolChanges, $volAdjust, $getVolFromPlayer);
			}
		}
	} elsif ( $request->isCommand([['mixer'], ['muting']]) && $outputLevelFixed{$client}) {
		if ( !$iPowerOnInProgress{$client} && $curAvrSource{$client} ne "") {
			$log->debug("Muting toggle request: \n");
			# Kill outstanding mute requests
			Slim::Utils::Timers::killTimers( $client, \&handleMutingToggle);
			# kill any volume changes that may be going on within the timer
			$timersRemoved = Slim::Utils::Timers::killTimers( $client, \&handleVolChanges);

#			$log->debug("Current SB volume: " . $client->volume() . "\n");

			# delay the muting toggle to give the SB time to fade up/down (but WHY???)
			Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 1 ), \&handleMutingToggle );
		}
	}
}

# ----------------------------------------------------------------------------
sub calculateAvrVolume {
	my $client = shift;
	my $volAdjust = shift;
	my $cprefs = $prefs->client($client);
	my $maxVolume = $cprefs->get('maxVol');	# max volume user wants AVP to be set to
	my $zone = $curAvrZone{$client};
	my $avrType = $cprefs->get('pref_Avp');
	my $DenonVol;

	$volAdjust = abs($volAdjust);  # safety valve
	$log->debug("Max AVR volume: $maxVolume \n");
	my $subVol = sprintf("%3d",(80 + $maxVolume) * sqrt($volAdjust));
	$log->debug("Client volume: $volAdjust \n");
	$log->debug("Raw subVol: $subVol \n");
#	$log->debug("MaxVol: $channels{$client,'MVMAX'} \n");
	my $width = 2;
	if ($zone == 0 && $avrType != 3 ) {  # 0.5dB increments only supported for main zone of AVP/AVR
		my $digit = int(substr($subVol,2,1));
		$subVol = int(($subVol+2)/10);  # round up for values of .8 and .9
		if (($digit>2) && ($digit<8)) {
			$subVol = $subVol*10 + 5;
			$width = 3;
		}
	} else {  # other zones or Marantz M1 / Denon Home Amp
		$subVol = int(($subVol+5)/10);
		if ($avrType == 3 ) {  # streaming amp
			$width = 3;
		}
	}

	$DenonVol = sprintf("%0*d",$width,$subVol);
	$log->debug("Calc Vol: $DenonVol \n");

	return $DenonVol;
}

# ----------------------------------------------------------------------------
sub handleDummyPause {
	my $client = shift;
#	$log->debug("handling Dummy Pause \n");
	my $timersRemoved = Slim::Utils::Timers::killTimers( $client, \&handleDummyPause);
}

# ----------------------------------------------------------------------------
sub handleMutingToggle {
	my $client = shift;
	my $avpIPAddress = $gIPAddress{$client};
	my $zone = $curAvrZone{$client};
	my $muteOnOff;

	my $sbVol = $client->volume();  # see if client muting is currently on
	$log->debug("Current SB volume: " . $sbVol . "\n");

	if ($sbVol <= 0 ) {  # need to mute
		$muteOnOff = 1;
		if ($sbVol < 0 ) {
			$curVolume{$client,$zone} = $sbVol;
		} else {
			$curVolume{$client,$zone} = 0;   #reset current volume
		}
	} else {   # need to unmute
		$muteOnOff = 0;
		$curVolume{$client,$zone} = 0;   #reset current volume
	}

	$log->debug("Handling Muting Toggle \n");
	Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpMuteToggle($client, $avpIPAddress, $zone, $muteOnOff);
}

# ----------------------------------------------------------------------------
sub handleVolSet {
	my $client = shift;
	my $newVol = shift;
	my $noCallback = shift;

	$log->debug("VolChange: $newVol \n");
	my $request = $client->execute([('mixer', 'volume', $newVol)]);
	if ($noCallback) {
		# Add a result so we can detect our own volume adjustments, to prevent a feedback loop
		$request->addResult('denonavpcontrolInitiated', 1);
	}
}

# ----------------------------------------------------------------------------
sub handleVolChanges {
	my $client = shift;
	my $volAdjust = shift;
	my $getVolFromPlayer = shift;
	my $avpIPAddress = $gIPAddress{$client};
	my $zone = $curAvrZone{$client};

	my $timersRemoved = Slim::Utils::Timers::killTimers( $client, \&handleVolChanges);
#	$log->debug("TESTING::: Volume change timers killed: $timersRemoved \n");

	if ($getVolFromPlayer) {  # get the current volume from the player
		$volAdjust = $client->volume();
	}

	$log->debug("*** DenonAvpControl:current SB volume: $volAdjust  \n");

	my $DenonVol = calculateAvrVolume($client, $volAdjust);

	$log->debug("VolChange: $DenonVol \n");

	if ($DenonVol != $curVolume{$client,$zone} ) {  # only send volume changes
		$curVolume{$client,$zone} = int($DenonVol);
		Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpVol($client, $avpIPAddress, $DenonVol, $zone);
		$gLastVolChange{$client} = Time::HiRes::time();  # update time of last volume change
		$gDelayedVolChanges{$client} = 0;   #reset the delayed volume change counter

	}
}

# ----------------------------------------------------------------------------
sub handleSendPowerOn {
	my $client = shift;
	my $avpIPAddress = $gIPAddress{$client};
	my $cprefs = $prefs->client($client);
	my $zone = $cprefs->get('zone');

	$log->debug("Handling Send Power ON \n");
	Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpOn($client, $avpIPAddress, $zone, 1);
}

# ----------------------------------------------------------------------------
sub handlePowerOn {
	my $class = shift;
	my $client = shift;

	$log->debug("Handling Power ON \n");
	Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 1), \&handleSendPowerOn);
}

# ----------------------------------------------------------------------------
sub handlePowerOn2 {
	my $class = shift;
	my $client = shift;
	my $cprefs = $prefs->client($client);
	my $avpIPAddress = $gIPAddress{$client};
	my $quickSelect = $cprefs->get('quickSelect');
	my $iDelay = $cprefs->get('delayQuick');   # Delay to set input after power on (in secs)

	my $inputSource = $quickSelect ? "" : $cprefs->get('inputSource');

	$log->debug("Handling Power ON 2\n");

	$avrQSInput{$client} = "";

	if ( $quickSelect ) {  # only if quick select is turned on
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + $iDelay), \&handleQuickSelect, 2);
		return;
	}

	if ( length($inputSource) ) {  # Switch to the AVR source if specified
		my $numInputs = $inputs{$avpIPAddress,0};
		my $found = 0;
		my $i = 1;
		my ($avrSource, $userSource);

		while ( $i <= $numInputs && !$found ) {
			$log->debug("Table entry #" . $i . " is: " . $inputs{$avpIPAddress,$i} . "\n");
			($avrSource, $userSource) = split (/\|/, $inputs{$avpIPAddress,$i});
			$log->debug("|" . $avrSource . "," . $userSource . "|\n");
			if ( $userSource eq $inputSource) {    # if this is the desired input
				$found = 1;
			}
			$i++;
		};

		if ( $found ) {
			Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + $iDelay), \&handleInputSelect, $avrSource);
			return;
		} else {
			$log->debug("Could not change source to: |" . $inputSource . "|\n");
		}
	}
	Slim::Utils::Timers::killTimers( $client, \&handleVolumeRequest);
	Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 2), \&handleVolumeRequest);  #sync the volume
}

# ----------------------------------------------------------------------------
sub handlePowerStatus {
	my $client = shift;
	my $cprefs = $prefs->client($client);
	my $avpIPAddress = $gIPAddress{$client};
	my $zone = $cprefs->get('zone');
	my $powerSynch = $cprefs->get('pref_PowerSynch');

	$log->debug("Checking AVR power ON/OFF status for " . $client->name() );
	if ( !$powerSynch || $iPowerOnInProgress{$client} == 1) {  # reschedule it if not active or powering on
		$log->debug("Polling inactive or power on in progress: rescheduling next power status check \n");
		my $powerPoll = int($cprefs->get('powerPoll'));
		Slim::Utils::Timers::killTimers( $client, \&handlePowerStatus );
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + $powerPoll), \&handlePowerStatus );
	} else {
		Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpPowerStatus($client, $avpIPAddress, $zone);
	}
}

# ----------------------------------------------------------------------------
sub retryPowerStatus {
	my $class = shift;
	my $client = shift;
	my $delay = shift;

	if (!defined($delay) || !$delay) {
		$delay = int($prefs->client($client)->get('powerPoll'));
	}

	$log->debug("Retrying failed Power status \n");
#	Slim::Utils::Timers::killTimers( $client, \&handlePowerStatus );
	Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + $delay), \&handlePowerStatus );
}

# ----------------------------------------------------------------------------
sub syncPowerState {
	my $class = shift;
	my $client = shift;
	my $avrPower = shift;
	my $zone = $curAvrZone{$client};
	my $player = $client->name();
	my $cprefs = $prefs->client($client);
	my $powerPoll = int($cprefs->get('powerPoll'));

	$log->debug("Checking Power ON/OFF status return \n");
	if ($avrPower != $iPowerState{$client,$zone} ) {  #sync power if necessary
		if ($iPowerOnInProgress{$client} == 1 ) {   # ignore the request if startup is in progress
			$log->debug("Power on in progress: ignoring player sync On/Off request \n");
		} else {
			$log->debug("Turning player " . $player . ($avrPower ? " ON" : " OFF") . " to sync with AVR\n");
			$iPowerState{$client,$zone} = $avrPower;
			$iPaused{$client} = 0;

			if ($avrPower == 1) {  # sync the volume if needed
				$iPowerOnInProgress{$client} = 1;
				Slim::Utils::Timers::killTimers( $client, \&handleVolumeRequest);
				Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 0.5), \&handleVolumeRequest );
			} else {   # power it off
				my $request = $client->execute([('power', 0)]);
				# Add a result so we can detect this event and prevent a feedback loop
				$request->addResult('denonavpcontrolInitiated', 1);
				$curAvrSource{$client} = "";  # clear the current source
			}
		}
	}

	my $syncSource = $cprefs->get('pref_SourceSynch');
	if ($avrPower == 1 && !$iPowerOnInProgress{$client} && $syncSource) {  # optionally check to see if the input source has changed
		my $avpIPAddress = $gIPAddress{$client};
		$log->debug("Polling to check the AVR input source...\n");
		$iInputSyncInProgress{$client} = 1;
		Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpInputSource($client, $avpIPAddress, $zone);
	}

	Slim::Utils::Timers::killTimers( $client, \&handlePowerStatus );
	if (!$client->power() && $powerPoll < 60) {  # if the player is off, minimum 60 seconds for poll
		$powerPoll = 60;
	}
	Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + $powerPoll), \&handlePowerStatus);  #schedule the next check
}

# ----------------------------------------------------------------------------
sub handleVolumeRequest {
	my $client = shift;
	my $avpIPAddress = $gIPAddress{$client};
	my $zone = $curAvrZone{$client};

	$log->debug( "Getting current volume from AVR: " . $client->name() . "\n");

	#now check with the AVR and get its current volume to set the player volume
	Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpVolSetting($client, $avpIPAddress, $zone);
	# /updateSqueezeVol will set the SB with the current amp setting
}

# ----------------------------------------------------------------------------
sub handleVolReq {
	my $class = shift;
	my $client = shift;
	my $noRetry = shift;
#	my $iDelay = 0.1;
	my $iDelay = 0.1;

	if ( $noRetry == 1) {  # an alternate QS command timed out
		$iPowerOnInProgress{$client} = 0;
		$gMenuPopulated{$client} = 1;   # no need to repopulate the menu
	} elsif ( $outputLevelFixed{$client} || $iPowerOnInProgress{$client}) {  # only if player is set to fixed output level (or power on)
		$log->debug( "Vol req retry from comms: " . $client->name() . "\n");
		if ($iPowerOnInProgress{$client}) {  #
			$iDelay = 0.5;
		}
		Slim::Utils::Timers::killTimers( $client, \&handleVolumeRequest);
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + $iDelay), \&handleVolumeRequest );
#		if ( $qSelect{$client} ) {   # if using Quick Select
#			$iPowerOnInProgress{$client} = 2;  # indicate that we already waited after QS
#		}
	}
}

# ----------------------------------------------------------------------------
sub handlePowerOff {
	my $client = shift;
	my $force = shift;
	my $cprefs = $prefs->client($client);
	my $avpIPAddress = $gIPAddress{$client};
	my $prefZone = $cprefs->get('zone');

	if ( !$force && ( $iPowerState{$client,$prefZone} == 1 || $iPowerOnInProgress{$client} ) ) {
		$log->debug("Handling primary zone Power OFF, checking input source \n");
		$curAvrZone{$client} = $prefZone;
		Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpInputSource($client, $avpIPAddress, $prefZone);
	} else {
		if ( ($force == 1) && $iPowerState{$client,$prefZone} == 1) {
			$log->debug("Turning off primary zone\n");
			if ($cprefs->get('pref_Avp') == 3) {  # set streaming amps to TV input before powering off
				Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpSetSource($client, $avpIPAddress, "TV", $prefZone, 1);
				Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 2), \&handleZonePowerOff, $avpIPAddress, $prefZone);
			} else {
				Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpStandBy($client, $avpIPAddress, $prefZone);
				$curVolume{$client,$prefZone} = 0;
				$iPowerState{$client,$prefZone} = 0;
			}
			$curAvrSource{$client} = "";  # clear the current source
		}

		if ($cprefs->get('pref_AudioMenu') && $cprefs->get('pref_MultiZone') ) {  # if multi-zone support in effect
			$log->debug("Turning off secondary zones\n");
			for (my $i = 0; $i<4; $i++) {  # turn off other zones if on
				if ( ($i != $prefZone) && ($iPowerState{$client,$i} == 1 )) {
					Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time()+$i+1), \&handleZonePowerOff, $avpIPAddress, $i);
				}
			}
		}
	}

	if ( !$force ) {
		$iPowerOnInProgress{$client} = 0;
		$iPowerOffInProgress{$client} = 1;
	}
}

# ----------------------------------------------------------------------------
sub handleZonePowerOff {
	my $client = shift;
	my $avpIPAddress = shift;
	my $zone = shift;

	Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpStandBy($client, $avpIPAddress, $zone);
	$curVolume{$client,$zone} = 0;
	$iPowerState{$client,$zone} = 0;
	$log->debug("Zone " . ($zone+1) . " powered off\n");
}

# ----------------------------------------------------------------------------
sub handleQuickSelect {
	my $client = shift;
	my $timeout = shift;
	my $cprefs = $prefs->client($client);
	my $avpIPAddress = $gIPAddress{$client};
	my $quickSelect = $cprefs->get('quickSelect');
	my $zone = $cprefs->get('zone');

	$log->debug("Handling quick select \n");
	Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpQuickSelect($client, $avpIPAddress, $quickSelect, $zone, $timeout);
	$qSelect{$client} = $quickSelect;
}

# ----------------------------------------------------------------------------
sub handleInputQuery {
	my $class = shift;
	my $client = shift;
	my $avrInput = shift;
	my $earlyDetection = shift;
	my $cprefs = $prefs->client($client);
	my $prefZone = $cprefs->get('zone');
	my $zone = $curAvrZone{$client};

	if ( $zone ne $prefZone) {  # secondary zone - ignore
		return;
	}

	$log->debug("Handling input query response: " . $avrInput . "\n");

	if ( $iInputSyncInProgress{$client} ) {  # if this is an input sync request, check it
		$iInputSyncInProgress{$client} = 0;
		if ( $avrInput ne $curAvrSource{$client} ) {  # the AVR input has changed
			if ( $avrInput ne $avrQSInput{$client} && $client->power() ) {  # the input is not for the player
				$log->debug("Input sync detected AVR source change. Pausing playback... \n");
				my $request = $client->execute([('pause', '1')]);  # pause playback
				$request->addResult('denonavpcontrolInitiated', 1);  # prevent callback loop
			}
			$curAvrSource{$client} = $avrInput;   # store the new source
		}
		return;
	}

	$curAvrSource{$client} = $avrInput;   # store the current source

	if ( $iPowerOffInProgress{$client} ) {
		my $force;
		my $quickSelect = $cprefs->get('quickSelect');
		my $inputSource = length($cprefs->get('inputSource'));
		if ( $avrInput eq $avrQSInput{$client} ) {  # only power off if it's the input for the associated player
			$force = 1;
			$log->debug("Handling primary zone Power OFF \n");
		} else {
			$force = 2; #don't power off
			$log->debug("Input changed; skipping Power OFF\n");
		}
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 1), \&handlePowerOff, $force );

		$avrQSInput{$client} = "" ;
		$iPowerOffInProgress{$client} = 0;
	} else {
		if ($avrQSInput{$client} eq "") {   # if this is from the primary QS
			$avrQSInput{$client} = $avrInput;  # store the input source
		}
#		} elsif (($avrInput ne $avrQSInput{$client}) && ($cprefs->get('quickSelect') == $qSelect{$client}) ) {  # HDMI-CEC changed the input on us
#			Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 0.1), \&handleInputSelect, $avrQSInput{$client} );  # change it back
#		}
		if ($earlyDetection == 0) {  # not coming from the QS command response
			$iPowerOnInProgress{$client} = 0;  # re-open command processing
			my $volPoll = $cprefs->get('volPoll');
			if ( $client->power() && $volPoll ) {  # set up volume polling if player is on and polling enabled
				$log->debug( "Setting timer for next volume poll \n");
				Slim::Utils::Timers::killTimers( $client, \&handleVolumeRequest);   # sync volume
				Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + $volPoll), \&handleVolumeRequest);
			}
		}
	}
}

# ----------------------------------------------------------------------------
sub handleInputSelect {
	my $client = shift;
	my $avrSource = shift;
	my $cprefs = $prefs->client($client);
	my $avpIPAddress = $gIPAddress{$client};
	my $zone = $cprefs->get('zone');

	$log->debug("Handling input select\n");
	Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpSetSource($client, $avpIPAddress, $avrSource, $zone, 1);
	$curAvrSource{$client} = $avrSource;
	if ($avrQSInput{$client} eq "") {   # if this is from the primary QS or source select
		$avrQSInput{$client} = $avrSource;  # store the input source
	}
	$log->debug("Changed source to: " . $avrSource . "\n");

	Slim::Utils::Timers::killTimers( $client, \&handleVolumeRequest);
 	Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 2), \&handleVolumeRequest);  #sync the volume
}

# ----------------------------------------------------------------------------
sub handleInputSource {
	my $client = shift;
	my $cprefs = $prefs->client($client);
	my $avpIPAddress = $gIPAddress{$client};
	my $zone = $cprefs->get('zone');
	my $onOff = $iPowerOffInProgress{$client} ? "OFF" : "ON / Quick Select";

	$log->debug("Handling zone Power " . $onOff . ", checking input source \n");
	Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpInputSource($client, $avpIPAddress, $zone);
}

# ----------------------------------------------------------------------------
sub retryInputSource {  # called from comms error routine after failed 'SI' command
	my $class = shift;
	my $client = shift;

	$log->debug("Retrying failed input source query \n");
	Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + .3), \&handleInputSource );
}

# ----------------------------------------------------------------------------
sub updateSqueezeVol { #used to sync SB vol with AVP
	my $class = shift;
	my $client = shift;
	my $avpVol = shift;
	my $avpIPAddress = $gIPAddress{$client};
	my $zone = $curAvrZone{$client};
	my $cprefs = $prefs->client($client);
	my $audioEnabled = $cprefs->get('pref_AudioMenu');
	my $prefZone = $cprefs->get('zone');
	my $iDelay = 0;  # used to delay some function calls

	$log->debug("Handling response to vol request \n");

	if ( $iPowerOnInProgress{$client} ) {  #volume sync from Quick Select
		if ($zone == $prefZone) {  # only if this is the original zone
			$log->debug("Saving initial AVR volume value (" . int($avpVol) . ")\n");
			$iInitialAvpVol{$client} = int($avpVol);  #store inital volume for use later
		}

		if ( $iPaused{$client} ) {  # if we paused playback during power on processing, resume after delay
			$log->debug("setting timer to resume playback after power-on pause \n");
#			$iDelay = $cprefs->get('delayQuick');   # Delay to resume playback after power on (in secs)
#			if ($iDelay < 2) {   # wait minimum of 2 secs
				$iDelay = 2;
#			}
			Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + $iDelay ), \&startPlayback);
		} else {
			$iPaused{$client} = 2;    # Indicate that we are not pausing during power-on (just in case)
		}

		my $modelInfo = $gModelInfo{$avpIPAddress};
		if ( $modelInfo eq "" || $modelInfo eq "unknown" || $modelInfo eq "inprogress") {  # get the model info if not yet available
			$log->debug("Getting AVP/AVR model string from device \n");
			Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 0.3), \&getAvpModelInfo);
			$iDelay = 5;  # allow more time before (re-)populating the menu
		}
		else {
			$iDelay = 0.3;
		}

		if ($audioEnabled && !$gMenuPopulated{$client} && ($zone == $prefZone)) {  # need to populate menus?
			Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + $iDelay ), \&getAvpSettings, $zone );
		}
	}

	if ( !$outputLevelFixed{$client}) {   # only if player is set at variable output level
		if ($zone == $prefZone) {  # only if original zone
			$preLevel{$client} = int($avpVol);
			$log->debug("New preamp level is: " . $preLevel{$client} . "\n");
			if ($gMenuUpdate{$client}) {
				Slim::Control::Request::executeRequest( $client, [ 'avpLvl' ] );
			}
		}
	} else {
		my $curVol = $curVolume{$client,$zone};
		$log->debug( "The client is: " . $client->name() . "\n");
		$log->debug( "AVR vol: " . $avpVol . "\n");
		$log->debug( "Old vol: " . $curVol . "\n");

		if ($avpVol != $curVol && $curVol >= 0 ) {  # if volume changed (and not muted), sync them up
			$curVolume{$client,$zone} = $avpVol;   # store current AVR volume

			my $volAdjust = calculateSBVolume($client, $avpVol);

			if ($zone == $prefZone) {  # only if the primary zone
				handleVolSet( $client, $volAdjust, 1);  # set client volume
			}
		}
	}

	if ($zone != $prefZone) {  # our work here is done if powering on a secondary zone
		$iPowerOnInProgress{$client} = 0;
		return;
	}

	if ( $iPowerOnInProgress{$client} && ($avrQSInput{$client} eq "" || $audioEnabled)) {
		if ($audioEnabled && !$gMenuPopulated{$client}) {  # audio menus in use
			$iDelay = 3;  # allow more time for menus to be populated
		} else {
			$iDelay = 0.25; # no need to wait as long
		}
		$log->debug("Setting timer to store AVR input \n");
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + $iDelay), \&handleInputSource );
	} else {
		$iPowerOnInProgress{$client} = 0;
	}

	my $volPoll = $cprefs->get('volPoll');
	if ( $client->power() && $volPoll && !$iPowerOnInProgress{$client}) {  # set up next volume poll if player is on and polling enabled
		$log->debug( "Setting timer for next volume poll \n");
		Slim::Utils::Timers::killTimers( $client, \&handleVolumeRequest);   # sync volume
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + $iDelay + $volPoll), \&handleVolumeRequest);
	} else {
		$log->debug( "Bypassing volume polling. Player is not on or volume polling disabled.\n");
	}
}

# ----------------------------------------------------------------------------
sub startPlayback {  # resume playback after pause during power on
	my $client = shift;

	if ( $iPowerOnInProgress{$client} ) {  # wait until power on is complete
		$log->debug("Power on in progress - delaying playback after power-on \n");
		Slim::Utils::Timers::killTimers( $client, \&startPlayback);
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 1), \&startPlayback );
		return;
	}

	my $request;
	if ( !$isUPnP{$client} ) {  #  unpause non-UPnP players during power on
		$log->debug("Resuming paused playback after power-on \n");
		$request = $client->execute([('pause', 0)]);
	} else {  # restart playback for UPnP players
		$log->debug("Resuming stopped playback after power-on \n");
		$request = $client->execute([('playlist', 'index', '+0')]);
		$request->addResult('denonavpcontrolInitiated', 1);
		$request = $client->execute([('play')]);
	}
	$request->addResult('denonavpcontrolInitiated', 1);
	$iPaused{$client} = 2;    # Indicate that we are no longer pausing playback during power on
}

# ----------------------------------------------------------------------------
sub getAvpModelInfo {  # populate the AVR model info
	my $client = shift;
	my $avpIPAddress = $gIPAddress{$client};
	my $modelInfo = $gModelInfo{$avpIPAddress};

	if ( $modelInfo eq "" || $modelInfo eq "unknown") {
		$gModelInfo{$avpIPAddress} = "inprogress";
		$log->debug("Getting AVR model string for device: " . $avpIPAddress);
		Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpGetModelInfo($client, $avpIPAddress);
	}
	elsif (!$gInputTablePopulated{$avpIPAddress} ) {  # populate the input table from the AVR
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 0.5 ), \&getAvpInputTable);
	}
}

# ----------------------------------------------------------------------------
sub getAvpInputTable {  # populate the AVR input table
	my $client = shift;
	my $avpIPAddress = $gIPAddress{$client};
	my $cprefs = $prefs->client($client);
	my $audioEnabled = $cprefs->get('pref_AudioMenu');
	my $quickSelect = $cprefs->get('quickSelect');
	my $inputSource = $quickSelect ? "" : $cprefs->get('inputSource');

	if ($audioEnabled || length($inputSource)) {  # skip if we don't need the table
		$log->debug("Getting AVR input table for device: " . $avpIPAddress);
		Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpGetInputs($client, $avpIPAddress);
	}
}

# ----------------------------------------------------------------------------
sub getAvpSettings {  # populate the client audio menu
	my $client = shift;
	my $zone = shift;
	my $avpIPAddress = $gIPAddress{$client};

	$log->debug("Getting AVR menu values\n");

	if ($zone == 0) {  # main menu for the main zone only
		# now check with the AVP to set the values of the settings
		Plugins::DenonAvpControl::DenonAvpComms::SendNetGetAvpSettings($client, $avpIPAddress, $gRefreshCVTable{$client});
	} else {   # get channel levels only for other zones
		Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpChannelLevels($client, $avpIPAddress, $zone);
	}
	$gMenuPopulated{$client} = 1;
}

# ----------------------------------------------------------------------------
sub calculateSBVolume {  # convert AVR volume to SB value (0-100)
	my $client = shift;
	my $avpVol = shift;
	my $cprefs = $prefs->client($client);
	my $avrType = $cprefs->get('pref_Avp'); # AVR type
	my $maxVolume = $cprefs->get('maxVol');	# max volume user wants AVR to be set to

	# change the AVR volume to the SB value

	my $intVol = int($avpVol);

	$log->debug("Max volume: $maxVolume \n");
	$log->debug("AVR volume: $intVol \n");

	if ( ($avrType == 3) && ($intVol <=100)) {  # Marantz M1 or Denon Home Amp
		$intVol *= 10;
	} elsif ( (length($avpVol) < 3) || (substr($avpVol,2,1) ne '5') ) {
		$intVol = substr($avpVol,0,2) * 10;
	}

	my $volAdjust = sprintf("%d", (($intVol / (80 + $maxVolume))**2) + 0.5);
	if ($volAdjust > 100) {
		$volAdjust = 100;
	}
	$log->debug("New SB Vol for AVR: " . $volAdjust . "\n");

	return $volAdjust;
}

# ----------------------------------------------------------------------------
sub avpSetSM { # used to set the AVP surround mode
	my $request = shift;
	my $client = $request->client();

	my $avpIPAddress = $gIPAddress{$client};
	my $sMode = $request->getParam('_surroundMode'); #surround mode index
	my $sOldMode = $request->getParam('_oldSurroundMode'); #old surround mode index
	if ($sMode != $surroundMode{$client}) { #change the value
		Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpSurroundMode($client, $avpIPAddress, $sMode);
		$surroundMode{$client} = $sMode;
	}
	$request->setStatusDone();
}

# ----------------------------------------------------------------------------
sub updateSurroundMode { #used to sync Surround Mode with AVP
	my $class = shift;
	my $client = shift;
	$surroundMode{$client} = shift; #will auto pick avp or avr

	$log->debug("New SM is: " . $surroundMode{$client} . "\n");

	if ($gMenuUpdate{$client}) {
		Slim::Control::Request::executeRequest( $client, [ 'avpSM' ] );
	}
}

# ----------------------------------------------------------------------------
sub avpSetRmEq { # used to set the AVP room equalizer mode
	my $request = shift;
	my $client = $request->client();
	my $avpIPAddress = $gIPAddress{$client};

	my $sMode = $request->getParam('_roomEq'); #Room eq index
	my $sOldMode = $request->getParam('_oldRoomEq'); #Room eq index
	$log->debug("sMode: $sMode \n");
	if ($sMode != $roomEq{$client}) {
		Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpRoomMode($client, $avpIPAddress, $sMode);
		$roomEq{$client} = $sMode;
	}
	$log->debug("roomEq: $roomEq{$client} \n");

	$request->setStatusDone();
}

# ----------------------------------------------------------------------------
sub updateRoomEq { #used to sync Room EQ with AVP
	my $class = shift;
	my $client = shift;
	$roomEq{$client} = shift;
	$log->debug("New Room EQ is: " . $roomEq{$client}. "\n");

	if ($gMenuUpdate{$client}) {
		Slim::Control::Request::executeRequest( $client, [ 'avpRmEq' ] );
	}
}

# ----------------------------------------------------------------------------
sub avpSetDynEq{ # used to set the AVP dynamic equalizer mode
	my $request = shift;
	my $client = $request->client();
	my $avpIPAddress = $gIPAddress{$client};

	my $sMode = $request->getParam('_dynamicEq'); #dynamic equalizer mode
	my $sOldMode = $request->getParam('_oldDynamicEq'); # old dynamic equalizer mode
	$log->debug("sMode: $sMode \n");
	if ($sMode != $dynamicEq{$client}) {
		Plugins::DenonAvpControl::DenonAvpComms::SendNetDynamicEq($client, $avpIPAddress, $sMode);
		$dynamicEq{$client} = $sMode;
	}

	$log->debug("dynamicEq: $dynamicEq{$client} \n");

	$request->setStatusDone();

	# update the plugin menu
	$log->debug("Refreshing menus after DynEq setting");
	Slim::Control::Jive::refreshPluginMenus($client);
}

# ----------------------------------------------------------------------------
sub updateDynEq { #used to sync Dynamic EQ with AVP
	my $class = shift;
	my $client = shift;
	$dynamicEq{$client} = shift;
	$log->debug("Dynamic EQ is: " . $dynamicEq{$client}. "\n");

	if ($gMenuUpdate{$client}) {
		Slim::Control::Request::executeRequest( $client, [ 'avpDynEq' ] );
	}
}

# ----------------------------------------------------------------------------
sub avpSetNM { # used to set the AVP Night mode
	my $request = shift;
	my $client = $request->client();
	my $avpIPAddress = $gIPAddress{$client};

	my $sMode = $request->getParam('_nightMode'); #night mode index
	my $sOldMode = $request->getParam('_oldNightMode'); # old night mode index
	if ($sMode != $nightMode{$client}) {
		Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpNightMode($client, $avpIPAddress, $sMode);
		$nightMode{$client} = $sMode;
	}
	$log->debug("nightMode: $nightMode{$client} \n");

	$request->setStatusDone();
}

# ----------------------------------------------------------------------------
sub updateNM { #used to sync Night Mode with AVP
	my $class = shift;
	my $client = shift;
	$nightMode{$client} = shift;
	$log->debug("Night Mode is: " . $nightMode{$client}. "\n");

	if ($gMenuUpdate{$client}) {
		Slim::Control::Request::executeRequest( $client, [ 'avpNM' ] );
	}
}

# ----------------------------------------------------------------------------
sub avpSetRes { # used to set the AVP restorer mode
	my $request = shift;
	my $client = $request->client();
	my $avpIPAddress = $gIPAddress{$client};

	my $sMode = $request->getParam('_restorer'); #restorer index
	my $sOldMode = $request->getParam('_oldRestorer'); # old restorer index
	if ($sMode != $restorer{$client}) {
		Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpRestorerMode($client, $avpIPAddress, $sMode, 0);
		$restorer{$client} = $sMode;
	}

	$log->debug("restorer: $restorer{$client} \n");

	$request->setStatusDone();
}

# ----------------------------------------------------------------------------
sub updateRestorer { #used to sync Restorer with AVP
	my $class = shift;
	my $client = shift;
	$restorer{$client} = shift;
	$log->debug("Restorer Mode is: " . $restorer{$client}. "\n");

	if ($gMenuUpdate{$client}) {
		Slim::Control::Request::executeRequest( $client, [ 'avpRes' ] );
	}
}

# ----------------------------------------------------------------------------
sub avpSetRefLvl { # used to set the AVP reference level mode
	my $request = shift;
	my $client = $request->client();
	my $avpIPAddress = $gIPAddress{$client};

	my $sMode = $request->getParam('_refLevel'); #ref level index
	my $sOldMode = $request->getParam('_oldRefLevel'); # old ref level index
	if ($sMode != $refLevel{$client}) {
		Plugins::DenonAvpControl::DenonAvpComms::SendNetRefLevel($client, $avpIPAddress, $sMode);
		$refLevel{$client} = $sMode;
	}

	$log->debug("ref level: $refLevel{$client} \n");

	$request->setStatusDone();
}

# ----------------------------------------------------------------------------
sub updateRefLevel { #used to sync reference level with AVP
	my $class = shift;
	my $client = shift;
	$refLevel{$client} = shift;
	$log->debug("Reference Level is: " . $refLevel{$client}. "\n");

	if ($gMenuUpdate{$client}) {
		Slim::Control::Request::executeRequest( $client, [ 'avpRefLvl' ] );
	}
}

# ----------------------------------------------------------------------------
sub avpSetSw { # used to set the AVP Subwoofer state
	my $request = shift;
	my $client = $request->client();
	my $avpIPAddress = $gIPAddress{$client};

	my $sMode = $request->getParam('_subwoofer'); #Subwoofer index
	my $sOldMode = $request->getParam('_oldSubwoofer'); # old Subwoofer index
	if ($sMode != $subwoofer{$client}) {
		Plugins::DenonAvpControl::DenonAvpComms::SendNetSwState($client, $avpIPAddress, $sMode);
		$subwoofer{$client} = $sMode;
	}

	$log->debug("subwoofer: $subwoofer{$client} \n");

	$request->setStatusDone();
}

# ----------------------------------------------------------------------------
sub updateSw { #used to sync SW state with AVP
	my $class = shift;
	my $client = shift;
	$subwoofer{$client} = shift;
	$log->debug("Subwoofer state is: " . $subwoofer{$client}. "\n");

	if ($gMenuUpdate{$client}) {
		Slim::Control::Request::executeRequest( $client, [ 'avpSw' ] );
	}
}

# ----------------------------------------------------------------------------
sub avpSetQuickSelect { # used to execute a Quick Select command
	my $request = shift;
	my $client = $request->client();
	my $sMode = $request->getParam('_quickSelect'); #Quick Select index

	if ($iPowerOnInProgress{$client} == 1) {   	# ignore the request if another QS is in progress
		$log->debug("Quick select in progress: ignoring menu QS $sMode request \n");
		$request->setStatusDone();
		return;									# not very elegant but ...
	}

	my $avpIPAddress = $gIPAddress{$client};
	my $cprefs = $prefs->client($client);
	my $zone = $cprefs->get('zone');
	my $quickSelect = $cprefs->get('quickSelect');

	$gMenuPopulated{$client} = 0;   # must repopulate menu after any QS
	$iPowerOnInProgress{$client} = 1;  # block other commands until QS completes
	$iPaused{$client} = 0;	# reset the power-on pause indicator

	if (($sMode == $quickSelect) && ($curAvrZone{$client} == $zone) ) {  # if it is our defined Quick Select and zone
		$iInitialAvpVol{$client} = calculateAvrVolume($client, 25);
		$avrQSInput{$client} = "" ;
	}

	$gRefreshCVTable{$client} = 1;  # refresh the channel volume table

	Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpQuickSelect($client, $avpIPAddress, $sMode, $curAvrZone{$client}, 2);
	$qSelect{$client} = $sMode;
	$gAllowQSUpdate{$client} = 1;  # allow QS update

	$log->debug("quick select: $sMode \n");

	$request->setStatusDone();
}

# ----------------------------------------------------------------------------
sub avpSaveQuickSelect { # used to save/update a Quick Select command
	my $request = shift;
	my $client = $request->client();
	my $quickSelect = $qSelect{$client};
	my $clientApp = $client->controllerUA;

	if ($quickSelect == 0) {   # just in case
		$request->setStatusDone();
		return;
	}

	if ($iPowerOnInProgress{$client} == 1 || !$gAllowQSUpdate{$client} ) {   	# ignore the request if a QS is in progress
		$log->debug("Quick select in progress: ignoring menu QS $quickSelect save request \n");
		$request->setStatusDone();
		return;		# not very elegant but ...
	}

	my $avpIPAddress = $gIPAddress{$client};
	my $zone = $curAvrZone{$client};

	Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpSaveQuickSelect($client, $avpIPAddress, $quickSelect, $zone);

	$gAllowQSUpdate{$client} = 0;  # block further updates until another QS is done or menu is rebuilt

	my $message = $client->string('PLUGIN_DENONAVPCONTROL_QUICK_SAVE3') . " " . $quickSelect;

	if ( ($client->controllerUA =~ m/^Mozilla/) ) {  # use special function for Material Skin
		Slim::Control::Request::executeRequest( $client, ['material-skin', 'send-notif', 'type:info', 'msg:'.$message, 'client:'.$client->id]);
	} else {
		$client->showBriefly( { 'jive' => { 'text' => [ $message ], } },{'duration' => 2, 'scroll' => 1, 'block' => 1 } );
	}

	$log->debug("Updating quick select: $quickSelect \n");

	$request->setStatusDone();
}

# ----------------------------------------------------------------------------
sub avpSetZone { # used to change the AVR zone
	my $request = shift;
	my $client = $request->client();
	my $zone = $request->getParam('_zone'); # new zone

	$log->debug("Change zone routine entered\n");

	if ($zone == $curAvrZone{$client} ) {   # don't do anything if the same zone
		$log->debug("Zone is already active: ignoring AVR Zone Select request \n");
		$request->setStatusDone();
		return;
	}

	if ($iPowerOnInProgress{$client} == 1) {   	# ignore the request if a QS is in progress
		$log->debug("Quick select in progress: ignoring AVR Zone Select request \n");
		$request->setStatusDone();
		return;
	}

	if ($avrQSInput{$client} eq "") {   	# ignore the request if no AVR source is defined
		$log->debug("No initial source exists: ignoring AVR Zone Select request \n");
		$request->setStatusDone();
		return;
	}

	$curAvrZone{$client} = $zone;

	my $iDelay = 1;

	if ($iPowerState{$client,$zone} == 0) {  # turn it on if not on
		$gRefreshCVTable{$client} = 0;  # don't refresh the channel volume table
		avpPowerOn($request);   # turn it on
	} else {  # it's already on
		handleVolumeRequest($client);  #sync the volume
		$iDelay = 0.25;
	}

	my $cprefs = $prefs->client($client);
	my $prefZone = $cprefs->get('zone');   # original zone

	if ($zone != $prefZone) {  # no need to set the source if it's the original zone
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + $iDelay), \&setInputSource);
	}

	$curVolume{$client,$zone} = 0;  # force player volume sync

	$log->debug("Changing zone to: " . $zone . "\n");

	$request->setStatusDone();
}

# ----------------------------------------------------------------------------
sub setInputSource { # used to change the input source for the current zone after startup
	my $client = shift;
	my $avpIPAddress = $gIPAddress{$client};
	my $source = $avrQSInput{$client};
	my $zone = $curAvrZone{$client};

	Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpSetSource($client, $avpIPAddress, $source, $zone, 0);
	$log->debug("Changed source to: " . $source . "\n");
	$iPowerOnInProgress{$client} = 0;

}

# ----------------------------------------------------------------------------
sub avpSetSource { # used to change the input source
	my $request = shift;
	my $client = $request->client();
	my $sMode = $request->getParam('_source'); # source name

	if ($iPowerOnInProgress{$client} == 1) {   	# ignore the request if a QS is in progress
		$log->debug("Quick select in progress: ignoring menu Source Select request \n");
		$request->setStatusDone();
		return;									# not very elegant but ...
	}

	my $avpIPAddress = $gIPAddress{$client};
	my $zone = $curAvrZone{$client};

	$gRefreshCVTable{$client} = 1;  # refresh the channel volume table
	Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpSetSource($client, $avpIPAddress, $sMode, $zone, 0);
	$curAvrSource{$client} = $sMode;
	$log->debug("Changed source to: " . $sMode . "\n");


	$request->setStatusDone();
}

# ----------------------------------------------------------------------------
sub avpPowerToggle { # used to power the AVR on/off
	my $request = shift;
	my $client = $request->client();
	my $sMode = $request->getParam('_onOff'); # On or Off
	my $showMenu = $request->getParam('_menuPopulated');  # was the audio menu populated?

	if ($iPowerOnInProgress{$client} == 1) {   	# ignore the request if a QS is in progress
		$log->debug("Power on in progress: ignoring menu Power On/Off request \n");
	} elsif ($sMode == 1) {  # power is on
		avpPowerOff($request, $showMenu);  # turn it off
	} else {
		avpPowerOn($request);   # turn it on
	}

	$request->setStatusDone();
}

# ----------------------------------------------------------------------------
sub avpPowerOn { # used to power on the AVR
	my $request = shift;
	my $client = $request->client();
	my $zone = $curAvrZone{$client};
	my $avpIPAddress = $gIPAddress{$client};
	my $cprefs = $prefs->client($client);
	my $prefZone = $cprefs->get('zone');

	$iPowerOnInProgress{$client} = 1;

	$log->debug("Handling menu Power ON request \n");
	Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpOn($client, $avpIPAddress, $zone, 0);

	$iPaused{$client} = 0;
	$iPowerState{$client,$zone} = 1;
}

# ----------------------------------------------------------------------------
sub avpPowerOff { # used to power off the AVR
	my $request = shift;
	my $showMenu = shift;
	my $client = $request->client();

#	$log->debug("Show menu flag = " . $showMenu . "\n");
	if ($showMenu == 0) {
		$log->debug("Audio menu not yet displayed: refreshing menu \n");
	} else {
		my $cprefs = $prefs->client($client);
		my $prefZone = $cprefs->get('zone');
		my $zone = $curAvrZone{$client};
		my $avpIPAddress = $gIPAddress{$client};
		$log->debug("Handling menu Power OFF request \n");
		Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpStandBy($client, $avpIPAddress, $zone);
		$curVolume{$client,$zone} = 0;
		$iPowerState{$client,$zone} = 0;

		if (($zone == $prefZone) || !$iPowerState{$client,$prefZone} ) {  # if the primary zone is "off", see if any others are "on"
#			$avrQSInput{$client} = "" ;
			my $i;
			for ($i = 0; $i<4; $i++) {
				if ($iPowerState{$client,$i} == 1 ) {
					$curAvrZone{$client} = $i;
					$curVolume{$client,$i} = 0;  # force player volume sync
					$log->debug("Current zone set to $i \n");
					last;
				}
			}
			if ($i == 4) {  # no zones are "on"
				# Turn the Lyrion player off
				my $request = $client->execute([('power', 0)]);
				# Add a result so we can detect this event and prevent a feedback loop
				$request->addResult('denonavpcontrolInitiated', 1);
				$curAvrSource{$client} = "";    # clear the current source
				$curAvrZone{$client} = $prefZone;
			}
		} else {
			$curAvrZone{$client} = $prefZone;  # else revert to the primary zone
			$curVolume{$client,$prefZone} = 0;  # force player volume sync
		}
		if ($curAvrSource{$client} ne "" ) {
			$iPaused{$client} = 0;
			Slim::Utils::Timers::killTimers( $client, \&handleVolumeRequest);
			Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 0.25), \&handleVolumeRequest);  #sync the volume
		}
	}
}

# ----------------------------------------------------------------------------
sub avpSetLvl { # used to set the AVP preamp level for variable mode
	my $request = shift;
	my $client = $request->client();

	my $level = $request->getParam('_level'); # AVR volume

	$level =~ m/(-?\d+)/; #remove label
	$level = $1;

	$log->debug("Preamp level change request: " . $preLevel{$client} . "->" . $level . "\n");

	if ( !$outputLevelFixed{$client} && ($level != $preLevel{$client}) ) {
		$preLevel{$client} = $level;
		$level = sprintf("%0*d",2,$level);
		my $cprefs = $prefs->client($client);
		my $avpIPAddress = $gIPAddress{$client};
		my $zone = $curAvrZone{$client};
		Plugins::DenonAvpControl::DenonAvpComms::SendNetAvpVol($client, $avpIPAddress, $level, $zone );
	}

	$log->debug("preamp level: $preLevel{$client} \n");

	$request->setStatusDone();
}

# ----------------------------------------------------------------------------
sub avpSetChannels { # used to set the AVP channels
	my $request = shift;
	my $client = $request->client();

	my $channel = $request->getParam('_channel'); #the channel call
	my $level = $request->getParam('_level'); #channel level

	$level =~ m/(-?\d+)/; #remove label
	my $value = $1;
	my $oldValue = int($channels{$client,$channel});


	#convert channel level value for call
	$value += 50; #set to db abs value

	$log->debug("Channel change: " . $channel . " " . $oldValue . "->" . $value);

	if ( $value != $oldValue) {  #don't execute if the same
		$channels{$client,$channel} = $value;  # update the table entry
		my $zone = $curAvrZone{$client};
		my $avpIPAddress = $gIPAddress{$client};
		Plugins::DenonAvpControl::DenonAvpComms::SendNetChannelLevel($client, $avpIPAddress, $zone, $channel, $value);
	}

	$request->setStatusDone();

}

# ----------------------------------------------------------------------------
sub updateChannels { #used to sync channels level with AVP
	my $class = shift;
	my $client = shift;
	my $saveHashTable = shift;

	if ($saveHashTable) {  # get the channel table address
		$log->debug("Channel table was updated.\n");
		my $hashRef = Plugins::DenonAvpControl::DenonAvpComms::getChannelsHash();
		%channels = %$hashRef;
	}
}

# ----------------------------------------------------------------------------
sub handleModelInfo { #store model info string from AVR
	my $class = shift;
	my $client = shift;
	my $modelInfo = shift;
	my $avpIPAddress = $gIPAddress{$client};

	$log->debug("Model info string is: $modelInfo");

	$gModelInfo{$avpIPAddress} = $modelInfo;

	if (!$gInputTablePopulated{$avpIPAddress} ) {  # populate the input table from the AVR
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 0.5 ), \&getAvpInputTable);
	}
}

# ----------------------------------------------------------------------------
sub updateInputTable { #store input table from AVR
	my $class = shift;
	my $client = shift;
	my $avpIPAddress = $gIPAddress{$client};

	$log->debug("Input table was populated for: " . $gModelInfo{$avpIPAddress} );
	$gInputTablePopulated{$avpIPAddress} = 1;

	my $hashRef = Plugins::DenonAvpControl::DenonAvpComms::getInputsHash();
	%inputs = %$hashRef;
}

# ----------------------------------------------------------------------------
# used to determine if connection used is digital
# We don't care if the user wants to use this in analog or non 100%
sub denonAvpInit {
	my $client = shift;
}

# ----------------------------------------------------------------------------
# determine if this player is using the DenonAvpControl plugin and its enabled
sub usingDenonAvpControl() {
	my $client = shift;
	my $cprefs = $prefs->client($client);
	my $pluginEnabled = $cprefs->get('pref_Enabled');

	# cannot use DS if no digital out (as with Baby)
	if ( (!$client->hasDigitalOut()) || ($client->model() eq 'baby')) {
		return 0;
	}
 	if ($pluginEnabled == 1) {
		return 1;
	}
	return 0;
}

# ----------------------------------------------------------------------------
# external volume indication support code
# used by iPeng and other controllers
sub getexternalvolumeinfoCLI {
	my @args = @_;
	&reportOnOurPlayers();
	if ( defined($getexternalvolumeinfoCoderef) ) {
		# chain to the next implementation
		return &$getexternalvolumeinfoCoderef(@args);
	}
	# else we're authoritative
	my $request = $args[0];
	$request->setStatusDone();
}

# ----------------------------------------------------------------------------
sub reportOnOurPlayers() {
	# loop through all currently attached players
	foreach my $client (Slim::Player::Client::clients()) {
		if (&usingDenonAvpControl($client) ) {
			# using our volume control, report on our capabilities
			$log->debug("Note that ".$client->name()." uses us for external volume control");
			Slim::Control::Request::notifyFromArray($client, ['getexternalvolumeinfo', 0,   1,   string(&getDisplayName())]);
#			Slim::Control::Request::notifyFromArray($client, ['getexternalvolumeinfo', 'relative:0', 'precise:1', 'plugin:DenonAvpControl']);
			# precise:1		can set exact volume
			# relative:1		can make relative volume changes
			# plugin:DenonSerial	this plugin's name
		}
	}
}

# --------------------------------------- external volume indication code -------------------------------
# end with something for plugin to do
1;
