#	DenonAvpComms
#
#	Author:	Chris Couper <chris(dot)c(dot)couper(at)gmail(dot)com>
#
#	Copyright (c) 2008-2025 Chris Couper
#	All rights reserved.
#
#	----------------------------------------------------------------------
#	Function:	Send HTTP Commands to support DenonAvpControl plugin
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
package Plugins::DenonAvpControl::DenonAvpComms;

use strict;
use base qw(Slim::Networking::Async);

use URI;
use Slim::Utils::Log;
use Slim::Utils::Misc;
use Slim::Utils::Prefs;
use Socket qw(:crlf);
#use Data::Dumper; #used to debug array contents

# ----------------------------------------------------------------------------
my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.denonavpcontrol',
	'defaultLevel' => 'ERROR',
	'description'  => 'PLUGIN_DENONAVPCONTROL_MODULE_NAME',
});

# ----------------------------------------------------------------------------
# Global Variables
# ----------------------------------------------------------------------------
	my $prefs = preferences('plugin.denonavpcontrol'); #name of preferences
	my $self;
	my %gGetPSModes = 0;	# looping through the PS modes
	my %gErrorCount = 0;   # used to limit the number of consecutive comm errors
	my %gInputQueryInProgress = 0;
	my %gPowerStatusInProgress = 0;
	my %gVolumeQueryInProgress = 0;
	my %gBlock = 0;   # used to enforce synchronous socket i/o per AVR
	my %gNewAvr = 0;
	my %gStartupInProgress = 0;
	my %inactiveInputs = ();  # inactive AVR inputs
	our %channels = ();  # active audio channels
	our %inputs = ();  # all AVR inputs

	my @surroundModes = ( # the avp surround mode commands
		'MSDIRECT',
		'MSPURE DIRECT',
		'MSSTEREO',
		'MSSTANDARD',
		'MSDOLBY DIGITAL',
		'MSDTS SURROUND',
		'MSWIDE SCREEN',
		'MS7CH STEREO',
		'MSSUPER STADIUM',
		'MSROCK ARENA',
		'MSJAZZ CLUB',
		'MSCLASSIC CONCERT',
		'MSMONO MOVIE',
		'MSMATRIX',
		'MSVIDEO GAME'
		);
	my @surroundModes_r = ( # the avr surround mode commands
		'MSDIRECT',
		'MSPURE DIRECT',
		'MSSTEREO',
		'MSDOLBY DIGITAL',
		'MSDTS SURROUND',
		'MSMCH STEREO',
		'MSROCK ARENA',
		'MSJAZZ CLUB',
		'MSMONO MOVIE',
		'MSMATRIX',
		'MSVIDEO GAME',
		'MSMULTI CH IN'
		);
	my @roomModes = ( # the avp room equalizer modes
		'PSROOM EQ:AUDYSSEY',
		'PSROOM EQ:BYP.LR',
		'PSROOM EQ:FLAT',
		'PSROOM EQ:MANUAL',
		'PSROOM EQ:OFF'
		);
	my @multEqModes = ( # the avr mult equalizer modes
		'PSMULTEQ:AUDYSSEY',
		'PSMULTEQ:BYP.LR',
		'PSMULTEQ:FLAT',
		'PSMULTEQ:MANUAL',
		'PSMULTEQ:OFF'
		);
	my @nightModes = ( # the avp night modes
		'PSDYNSET NGT',
		'PSDYNSET EVE',
		'PSDYNSET DAY',
		);
	my @nightModes_avr = ( # the avr night modes
		'PSDYNVOL NGT',
		'PSDYNVOL EVE',
		'PSDYNVOL DAY',
		'PSDYNVOL OFF',
		);
	my @nightModes_avr_new = ( # the new avr night modes
		'PSDYNVOL HEV',
		'PSDYNVOL MED',
		'PSDYNVOL LIT',
		'PSDYNVOL OFF',
		);
	my @restorerModes = ( # the old restorer modes
		'PSRSTR OFF',
		'PSRSTR MODE1',
		'PSRSTR MODE2',
		'PSRSTR MODE3',
		);
	my @restorerModes_new = ( # the new restorer modes
		'PSRSTR OFF',
		'PSRSTR HI',
		'PSRSTR MED',
		'PSRSTR LOW',
		);
	my @restorerModes_marantz = ( # the marantz restorer modes
		'PSMDAX OFF',
		'PSMDAX HI',
		'PSMDAX MED',
		'PSMDAX LOW',
		);
	my @dynamicVolModes = ( # the avp dynamic volume modes
		'PSDYN OFF',
		'PSDYN ON',
		'PSDYN VOL'
		);
	my @dynamicEqModes = ( # the avr dynamic Eq modes
		'PSDYNEQ OFF',
		'PSDYNEQ ON'
		);
	my @refLevelModes = ( # the avp reference level modes
		'PSREFLEV 0',
		'PSREFLEV 5',
		'PSREFLEV 10',
		'PSREFLEV 15',
		);
	my @sWPowerModes = ( #the avp SW power modes
		'PSSWR OFF',
		'PSSWR ON'
	);
# ----------------------------------------------------------------------------
# References to other classes
# ----------------------------------------------------------------------------
my $classPlugin		= undef;

# ----------------------------------------------------------------------------
sub new {
	my $ref = shift;
	$classPlugin = shift;

	$log->debug( "*** DenonAvpControl::DenonAvpComms::new() " . $classPlugin . "\n");
	$self = $ref->SUPER::new;
}

sub getChannelsHash {
	\%channels;
}

sub getInputsHash {
	\%inputs;
}

# ----------------------------------------------------------------------------
sub SendNetAvpVol {
	my $client = shift;
	my $url = shift;
	my $vol = shift;
	my $zone = shift;
	my $request;

	if ($zone == 0 ) {
		$request= "MV" .  $vol . $CR ;
	} elsif ($zone == 1 ) {
		$request= "Z2" .  $vol . $CR ;
	} elsif ($zone == 2 ) {
		$request= "Z3" .  $vol . $CR ;
	} else {
		$request= "Z4" .  $vol . $CR ;
	}

	$log->debug("Calling writemsg for volume command: $request");
#	writemsg($request, $client, $url, 0.15);
	writemsg($request, $client, $url, 0.25);
}

# ----------------------------------------------------------------------------
sub SendNetAvpVolSetting {
	my $client = shift;
	my $url = shift;
	my $zone = shift;
	my $request;

	if ($zone == 0 ) {
		$request= "MV?" . $CR ;
	} elsif ($zone == 1 ) {
		$request= "Z2?" . $CR ;
	} elsif ($zone == 2 ) {
		$request= "Z3?" . $CR ;
	} else {
		$request= "Z4?" . $CR ;
	}

	$log->debug("Calling writemsg for volume query: $request");
	$gVolumeQueryInProgress{$client} = 0;
	my $delayed = writemsg($request, $client, $url);
	if ($delayed) {   # queue it here instead of in writemsg
		Slim::Utils::Timers::killSpecific($delayed);
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + .2), \&SendNetAvpVolSetting, $url, $zone);
	} else {
		$gVolumeQueryInProgress{$client} = 1;
	}
}

# ----------------------------------------------------------------------------
sub SendNetAvpSurroundMode {
	my $client = shift;
	my $url = shift;
	my $mode = shift;
	my $cprefs = $prefs->client($client);
	my $avp = $cprefs->get('pref_Avp');
	my $request;

	if ($avp == 1) {   # Denon AVP
		$request = $surroundModes[$mode] . $CR ;
	} else {
		$request = $surroundModes_r[$mode] . $CR ;
	}
	writemsg($request, $client, $url, 2);
}

# ----------------------------------------------------------------------------
sub SendNetAvpRoomMode {
	my $client = shift;
	my $url = shift;
	my $mode = shift;
	my $cprefs = $prefs->client($client);
	my $avp = $cprefs->get('pref_Avp');
	my $request;

	if ($avp == 1) {   #Denon AVP
		$request = $roomModes[$mode] . $CR ;
	} else {
		$request = $multEqModes[$mode] . $CR ;
	}
	writemsg($request, $client, $url);
}

# ----------------------------------------------------------------------------
sub SendNetAvpNightMode {
	my $client = shift;
	my $url = shift;
	my $mode = shift;
	my $cprefs = $prefs->client($client);
	my $avp = $cprefs->get('pref_Avp');
	my $request;

	if ($avp == 1) {   # Denon AVP
		$request = $nightModes[$mode] . $CR ;
	} else {
		$request = $nightModes_avr[$mode] . $CR ;
	}
	writemsg($request, $client, $url);
}

# ----------------------------------------------------------------------------
sub SendNetAvpRestorerMode {
	my $client = shift;
	my $url = shift;
	my $mode = shift;
	my $new = shift;
	my $cprefs = $prefs->client($client);
	my $avp = $cprefs->get('pref_Avp');
	my $request;

	if ($avp == 2) {  # Marantz AVR
		$request = $restorerModes_marantz[$mode] . $CR ;
	} elsif ($new || ($gNewAvr{$client} == 1)) {    # use new API for new Denon AVR models
		$request = $restorerModes_new[$mode] . $CR ;
	} else {
		$request = $restorerModes[$mode] . $CR ;
	}
	writemsg($request, $client, $url);
}

# ----------------------------------------------------------------------------
sub SendNetDynamicEq {
	my $client = shift;
	my $url = shift;
	my $mode = shift;
	my $cprefs = $prefs->client($client);
	my $avp = $cprefs->get('pref_Avp');
	my $request;

	$log->debug("Calling writemsg for dynamic eq command");
	if ($avp == 1) {  # Denon AVP
		$request = $dynamicVolModes[$mode] . $CR ;
	} else {
		$request = $dynamicEqModes[$mode] . $CR ;
	}
	writemsg($request, $client, $url);
}

# ----------------------------------------------------------------------------
sub SendNetRefLevel {
	my $client = shift;
	my $url = shift;
	my $mode = shift;

	$log->debug("Calling writemsg for reference level command");
	my $request = $refLevelModes[$mode] . $CR ;
	writemsg($request, $client, $url);
}

# ----------------------------------------------------------------------------
sub SendNetSwState{
	my $client = shift;
	my $url = shift;
	my $mode = shift;

	$log->debug("Calling writemsg for subwoofer on/off command");
	my $request = $sWPowerModes[$mode] . $CR ;
	writemsg($request, $client, $url);
}

# ----------------------------------------------------------------------------
sub SendNetGetAvpSettings {
	my $client = shift;
	my $url = shift;
	my $sMode = shift;
	my $request;

	if ( ($sMode == 0) || ($sMode == 1))  {
		$gGetPSModes{$client} = 1; #its the main menu looking for all settings
		$request= "MS?" . $CR ;
		if ($sMode == 1) {
			$channels{$client,"POPULATED"} = 0;  # need to populate the channel volume table
		}
	} else {
		$gGetPSModes{$client} = -1; #its the index menus looking for one setting
		$request= $sMode . $CR ;
	}
	writemsg($request, $client, $url);
}

# ----------------------------------------------------------------------------
sub SendNetChannelLevel {
	my $client = shift;
	my $url = shift;
	my $zone = shift;
	my $channel = shift;
	my $value = shift;
	my $request;

#	$channels{$client,$channel} = $value;

	if ($zone == 0 ) {
		$request= "" ;
	} elsif ($zone == 1 ) {
		$request= "Z2" ;
	} elsif ($zone == 2 ) {
		$request= "Z3" ;
	} else {
		$request = "Z4" ;
	}
	$request = $request . $channel . " " . $value . $CR ;

	$log->debug("Calling writemsg for channel setting " . $request);
	writemsg($request, $client, $url);
}

# ----------------------------------------------------------------------------
sub SendNetAvpChannelLevels {
	my $client = shift;
	my $url = shift;
	my $zone = shift;
	my $timeout = 1;
	my $request;

	if ($zone == 0 ) {
		$request= "" ;
	} elsif ($zone == 1 ) {
		$request= "Z2" ;
	} elsif ($zone == 2 ) {
		$request= "Z3" ;
	} else {
		$request = "Z4" ;
	}
	$request =  $request . "CV?" . $CR ;

	$gGetPSModes{$client} = 8;  # in case we have to retry
	$channels{$client,"POPULATED"} = 0;

	$log->debug("Calling query for channel level values");
	writemsg($request, $client, $url, $timeout);
}

# ----------------------------------------------------------------------------
sub LoopGetAvpSettings {
	my $client = shift;
	my $url = shift;
	Slim::Utils::Timers::killTimers( $client, \&SendTimerLoopRequest);
	Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + .1), \&SendTimerLoopRequest, $url);
}

# ----------------------------------------------------------------------------
sub SendTimerLoopRequest {
	my $client = shift;
	my $url = shift;
	my $cprefs = $prefs->client($client);
	my $avp = $cprefs->get('pref_Avp');
	my $zone = $cprefs->get('zone');
	my $request;
	my $timeout = 0.5;

	if ($gInputQueryInProgress{$client} == 1) {  # wait for SI? command to complete
		$log->debug("Timer loop request: 'SI?' in progress - retry");
		LoopGetAvpSettings($client, $url);
	}

	if ($avp != 1 && $gGetPSModes{$client} == 4) { #avr don't do this
		$gGetPSModes{$client} = 5; #skip it
	}

	if ($gGetPSModes{$client} == 7) { # subwoofer on/off not supported for now
		$gGetPSModes{$client} = 8; #skip it
	}

	$log->debug("Timer loop request: PSMode=" . $gGetPSModes{$client});

	if ($gGetPSModes{$client} == 1) {
		$request= "MS?" . $CR ;
	} elsif ($gGetPSModes{$client} == 2) {
		if ($avp == 1) {  # Denon AVP
			$request= "PSROOM EQ: ?" . $CR ;
		} else {
			$request= "PSMULTEQ: ?" . $CR ;
		}
	} elsif ($gGetPSModes{$client} == 3) {
		if ($avp == 1) {  # Denon AVP
			$request= "PSDYN ?" . $CR ;
		} else {
			$request= "PSDYNEQ ?" . $CR ;
		}
	} elsif ($gGetPSModes{$client} == 4) { #avp only
		$request= "PSDYNSET ?" . $CR ;
	} elsif ($gGetPSModes{$client} == 5) {
		if ($avp == 2) {  # Marantz AVR
			$request= "PSMDAX ?" . $CR ;
		} else {
			$request= "PSRSTR ?" . $CR ;
		}
	} elsif ($gGetPSModes{$client} == 6) {
		$request= "PSREFLEV ?" . $CR ;
	} elsif ($gGetPSModes{$client} == 7) {
		$request= "PSSWR ?" . $CR ;
	} elsif ($gGetPSModes{$client} == 8) {
		if ($channels{$client,"POPULATED"} == 0) {  #need to populate the channel vol table
			if ($zone == 0 ) {
				$request= "" ;
			} elsif ($zone == 1 ) {
				$request= "Z2" ;
			} elsif ($zone == 2 ) {
				$request= "Z3" ;
			} else {
				$request = "Z4" ;
			}
			$request =  $request . "CV?" . $CR ;
		} else {
			$gGetPSModes{$client} = 0; #already populated, end gracefully
			return;
		}
	} else {
		$gGetPSModes{$client} = -1; #cancel it, we are done
		return;
	}
	writemsg($request, $client, $url, $timeout);
}

# ----------------------------------------------------------------------------
sub SendNetAvpMuteStatus {
	my $client = shift;
	my $url = shift;
	my $timeout = 1;
	my $request = "MU?" . $CR ;

	$log->debug("Calling query for mute status");
	writemsg($request, $client, $url, $timeout);
}

# ----------------------------------------------------------------------------
sub SendNetAvpMuteToggle {
	my $client = shift;
	my $url = shift;
	my $zone = shift;
	my $muteToggle = shift;
	my $timeout = 0.25;
	my $request;

	if ($zone == 0 ) {
		$request= "" ;
	} elsif ($zone == 1 ) {
		$request= "Z2" ;
	} elsif ($zone == 2 ) {
		$request= "Z3" ;
	} else {
		$request = "Z4" ;
	}

	if ($muteToggle == 1) {
		$request = $request . "MUON" . $CR ;
	}
	else {
		$request = $request . "MUOFF" . $CR ;
	}

	$log->debug("Calling writemsg for Mute command");
	writemsg($request, $client, $url, $timeout);
#	writemsg($request, $client, $url, 0);
}

# ----------------------------------------------------------------------------
sub SendNetAvpPowerStatus {
	my $client = shift;
	my $url = shift;
	my $zone = shift;
	my $request;
	my $timeout = 0.5;
#	my $timeout = 2;
	my $cprefs = $prefs->client($client);
	my $avrType = $cprefs->get('pref_Avp');

	if ($avrType == 3 ) {
		$request= "PW?" . $CR ;   # single zone power amps
	} elsif ($zone == 0 ) {
		$request= "ZM?" . $CR;
	} elsif ($zone == 1 ) {
		$request= "Z2?" . $CR ;
	} elsif ($zone == 2 ) {
		$request= "Z3?" . $CR ;
	} else {
		$request= "Z4?" . $CR ;
	}

	$log->debug("Calling writemsg for zone power status");
	$gPowerStatusInProgress{$client} = 0;
	my $delayed = writemsg($request, $client, $url, $timeout);
	if ($delayed) {   # queue it here instead of in writemsg
		Slim::Utils::Timers::killSpecific($delayed);
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + .2), \&SendNetAvpPowerStatus, $url, $zone);
	} else {
		$gPowerStatusInProgress{$client} = 1;
	}
}

# ----------------------------------------------------------------------------
sub SendNetAvpOn {
	my $client = shift;
	my $url = shift;
	my $zone = shift;
	my $startup = shift;
	my $request;
	my $timeout = $startup ? 2 : 0.5;  # wait longer if during player startup
	my $cprefs = $prefs->client($client);
	my $avrType = $cprefs->get('pref_Avp');

	if ($avrType == 3 ) {
		$request= "PWON" . $CR ;  # single zone power amps
	} elsif ($zone == 0 ) {
		$request= "ZMON" . $CR;
	} elsif ($zone == 1 ) {
		$request= "Z2ON" . $CR ;
	} elsif ($zone == 2 ) {
		$request= "Z3ON" . $CR ;
	} else {
		$request= "Z4ON" . $CR ;
	}

	$log->debug("Calling writemsg for On command");
	writemsg($request, $client, $url, $timeout);

	$gInputQueryInProgress{$client}	= 0;  # just in case
#	$gPowerStatusInProgress{$client} = 0;
	$gVolumeQueryInProgress{$client} = 0;
	$gGetPSModes{$client} = 0;
	$gStartupInProgress{$client} = $startup;  # indicate whether this is a "Player ON" (QS) event
}

# ----------------------------------------------------------------------------
sub SendNetAvpStandBy {
	my $client = shift;
	my $url = shift;
	my $zone = shift;
	my $request;
	my $cprefs = $prefs->client($client);
	my $avrType = $cprefs->get('pref_Avp');

	if ($avrType == 3 ) {
		$request= "PWSTANDBY" . $CR ;  # single zone power amps
	} elsif ($zone == 0 ) {
		$request= "ZMOFF" . $CR ;
	} elsif ($zone == 1 ) {
		$request= "Z2OFF" . $CR ;
	} elsif ($zone == 2 ) {
		$request= "Z3OFF" . $CR ;
	} else {
		$request= "Z4OFF" . $CR ;
	}

	$log->debug("Calling writemsg for Standby command");
#	writemsg($request, $client, $url, 0.25);
	writemsg($request, $client, $url, 1);
}

# ----------------------------------------------------------------------------
sub SendNetAvpQuickSelect {
	my $client = shift;
	my $url = shift;
	my $quickSelect = shift;
	my $zone = shift;
	my $timeout = shift;
	my $request;
	my $request2;
	my $cprefs = $prefs->client($client);
	my $avrType = $cprefs->get('pref_Avp');

	if ( $quickSelect == 0) {   # just in case
		return;
	}

	my $zone2 = $zone+1;

	$log->debug("Calling writemsg for quick select command");
	if ($zone == 0 ) {
		$request = "MS";
	} else {
		$request = "Z" . $zone2;
	}

	if ($avrType == 2) {  # Marantz AVR
		$request2 = "SMART";
	} else {
		$request2 = "QUICK";
	}

	$request = $request . $request2 . $quickSelect . $CR;
	$log->debug("Request is: " . $request);
	writemsg($request, $client, $url, $timeout);
}

# ----------------------------------------------------------------------------
sub SendNetAvpSaveQuickSelect {  # save the Quick Select settings to AVR
	my $client = shift;
	my $url = shift;
	my $quickSelect = shift;
	my $zone = shift;
	my $request;
	my $request2;
	my $cprefs = $prefs->client($client);
	my $avrType = $cprefs->get('pref_Avp');


	if ( $quickSelect == 0) {   # just in case
		return;
	}

	my $zone2 = $zone+1;

	$log->debug("Calling writemsg for quick select save command");
	if ($zone == 0 ) {
		$request = "MS";
	} else {
		$request = "Z" . $zone2;
	}

	if ($avrType == 2) {  # Marantz AVR
		$request2 = "SMART";
	} else {
		$request2 = "QUICK";
	}

	$request = $request . $request2 . $quickSelect . " MEMORY" . $CR;
	$log->debug("Request is: " . $request);
#	writemsg($request, $client, $url, 2);
#	writemsg($request, $client, $url, 0.25);
	writemsg($request, $client, $url);
}

# ----------------------------------------------------------------------------
sub SendNetAvpInputSource {
	my $client = shift;
	my $url = shift;
	my $zone = shift;
	my $request;

	my $zone2 = $zone+1;

	if ($zone == 0) {
		$request = "SI?" . $CR ;
	} else {
		$request = "Z" . $zone2 . "?" . $CR ;
	}

	if ($gGetPSModes{$client} > 0 ) {  # menu settings in progress - retry
		$log->debug("Menu population in progress - retrying");
		Slim::Utils::Timers::killTimers( $client, \&SendNetAvpInputSource);
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 1), \&SendNetAvpInputSource, $url, $zone);
	} else {
		$log->debug("Calling writemsg for input source query command");
		$gInputQueryInProgress{$client} = 0;
		my $delayed = writemsg($request, $client, $url, 1);
		if ($delayed) {   # queue it here instead of in writemsg
			Slim::Utils::Timers::killSpecific($delayed );
			Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + .2), \&SendNetAvpInputSource, $url, $zone);
		} else {
			$gInputQueryInProgress{$client} = 1;
		}
	}
}

# ----------------------------------------------------------------------------
sub SendNetAvpSetSource {  # set the AVR input source
	my $client = shift;
	my $url = shift;
	my $source = shift;
	my $zone = shift;
	my $onstartup = shift;
	my $request;
	my $cprefs = $prefs->client($client);
	my $prefZone = $cprefs->get('zone');
	my $timeout = 0.5;   # default if not coming from the menu

	if ( $source eq "") {   # just in case
		return;
	}

	$log->debug("Calling writemsg for source select command");
	if ($zone == 0) {
		$request = "SI";
	} else {
		$request = "Z" . ($zone+1);
	}

	if (!$onstartup && ($zone == $prefZone)) {  # only for primary zone source change from the menu
		# need to repopulate the channel level table if coming from the menu
		$gGetPSModes{$client} = 8;
		$channels{$client,"POPULATED"} = 0;
		$timeout = 2;   # allow more time for source changes from the menu
	}

	$request .= $source . $CR;
	$log->debug("Request is: " . $request);
	writemsg($request, $client, $url, $timeout);
}

# ----------------------------------------------------------------------------
sub SendNetAvpGetModelInfo {  # get the model string from the AVR
	my $client = shift;
	my $url = shift;
	my $request = "SYMO" . $CR ;

	$log->debug("Calling writemsg for model info query");
	writemsg($request, $client, $url, 2);
}

# ----------------------------------------------------------------------------
sub SendNetAvpGetInputs {  # get the input strings from the AVR
	my $client = shift;
	my $url = shift;
	my $cprefs = $prefs->client($client);
	my $avrType = $cprefs->get('pref_Avp');

	if ($avrType == 3) {  # Streaming amp (Marantz MODEL M1 or Denon Home Amp) - Hardcoded for now
		$inputs{$url,0} = 3;
		$inputs{$url,1} = "OPT|Digital";
		$inputs{$url,2} = "LINE|Line";
		$inputs{$url,3} = "TV|HDMI";
		$classPlugin->updateInputTable($client);
	} else {
		$inactiveInputs{$url,0} = 0;  # initialize the inactive input table
		my $request = "SSSOD ?" . $CR ;
		$log->debug("Calling writemsg for inactive inputs table query");
		writemsg($request, $client, $url, 1);
		Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + 1),
			\&SendNetAvpGetAllInputs, $url );  # get the input table
	}
}

# ----------------------------------------------------------------------------
sub SendNetAvpGetAllInputs {  # get the input strings from the AVR
	my $client = shift;
	my $url = shift;

	$inputs{$url,0} = 0;  # initialize the input table
	my $request = "SSFUN ?" . $CR ;
	$log->debug("Calling writemsg for input table query");
	writemsg($request, $client, $url, 1);
}

# ----------------------------------------------------------------------------
sub writemsg {
	my $request = shift;
	my $client = shift;
	my $url = shift;
	my $timeout = shift;
#	my $delayed = shift;

#	if (!defined($delayed) || !$delayed) {  #test to try delaying all writes for 0.1 second to avoid socket timeouts
#		Slim::Utils::Timers::setTimer( $request, (Time::HiRes::time() + .1), \&writemsg, $client, $url, $timeout, 1);
#		return;
#	}

	if  ($gBlock{$url} || $gPowerStatusInProgress{$client} || $gVolumeQueryInProgress{$client} || $gInputQueryInProgress{$client} ) {
#	if  ($gBlock{$url} ) {
		$log->debug("Command in progress - delaying AVR command request: " . $request);
		return (Slim::Utils::Timers::setTimer( $request, (Time::HiRes::time() + .2), \&writemsg, $client, $url, $timeout) ); #delay command
	}

	$gBlock{$url} = 1;   # block other commands until complete or timed out

	my $u = URI->new($url);
	my @pass = [ $request, $client ];

	if (!defined($timeout) || !$timeout) {
		$timeout = 0.5;
	}

	$self->write_async( {
		host        => $u->host,
		port        => $u->port,
		content_ref => \$request,
		Timeout     => $timeout,
		skipDNS     => 1,
		onError     => \&_catch,
		onRead      => \&_read,
		passthrough => [ $url, @pass ],
		} );

	$log->debug("Sent AVR command request: " . $request);
	return 0;
}

# ----------------------------------------------------------------------------
sub _catch {
	my $self  = shift;
	my $message = shift;
	my $url   = shift;
	my $track = shift;
	my $args  = shift;

	$self->disconnect;  #disconnect socket

	$log->debug("Socket write _catch routine called...");

	my @track = @$track;
	my $request = @track[0];
	my $client = @track[1];

	$gBlock{$url} = 0;  # unblock socket

	if ( $log->is_warn ) {
		logWarning("problem connecting to AVR at " . $url .  ", request=" . substr($request, 0, -1) . ", message=" . $message);
	}

	if ($request =~ m/(PW|Z(M|[2-4]))\?\r/ && $gPowerStatusInProgress{$client} ) {	 # Power status from polling
		if ( $log->is_info ) {
			$log->info("Power status polling timeout - retrying\n");
		}
		$gPowerStatusInProgress{$client} = 0;
		$classPlugin->retryPowerStatus($client, 0); # retry
		return;
	}

	if	($request =~ m/(MV|Z[2-4])\?/ && $gVolumeQueryInProgress{$client} ) {	 # Volume request from polling
		if ( $log->is_info ) {
			$log->info("Volume polling request timed out - retrying\n");
		}
		$gVolumeQueryInProgress{$client} = 0;
		$classPlugin->handleVolReq($client, 0); # retry
		return;
	}

	$gErrorCount{$client}++;
	if ($gErrorCount{$client} >= 10) {   # abort after 10 consecutive comm errors
		if ( $log->is_error ) {
			logError($gErrorCount{$client} . " consecutive comm errors for " . $client->name() . " AVR at " . $url . ". Check network connection...\n");
		}
		$gInputQueryInProgress{$client} = 0;
		$gPowerStatusInProgress{$client} = 0;
		$gVolumeQueryInProgress{$client} = 0;
		$gStartupInProgress{$client} = 0;
		$gBlock{$url} = 0;
		$gErrorCount{$client} = 0;    # reset the error count
		if ($gGetPSModes{$client} > 0 ) {  # problem getting one of the menu settings move to the next
			if ( $log->is_info ) {
				$log->info("Menu request failed. Moving to next menu setting request...\n");
			}
			$gGetPSModes{$client}++;
			LoopGetAvpSettings($client, $url);
		} elsif ($request =~ m/SYMO\r/ ) {  # if we were trying to get the AVR model, let the plugin know
			if ( $log->is_info ) {
				$log->info("Model info request timed out\n");
			}
			$classPlugin->handleModelInfo($client, "unknown");
		} else {
			$gGetPSModes{$client} = 0;  # we had an error so cancel any more outstanding AVR menu requests
		}
		$classPlugin->retryPowerStatus($client, 0); # restart power status polling if needed
		$classPlugin->handleVolReq($client, 0);  # restart volume polling if needed
	} elsif (($request =~ m/SI\?\r/) ||
				($gInputQueryInProgress{$client} && !$gGetPSModes{$client} ) ) {  # input source query failed
		if ( $log->is_info ) {
			$log->info("Calling retryInputSource\n");
		}
		$gInputQueryInProgress{$client} = 0;
		$classPlugin->retryInputSource($client);
	} elsif ( $message =~ m/(T|t)imed out/ ) {   # connect or request timed out
		if ($request =~ m/(MV|Z[2-4])\d\d/ && $message =~ m/onnect timed out/) {  # volume change connect timed out
			if ( $log->is_info ) {
				$log->info("Volume setting request connect timed out - retrying\n");
			}
			my $vol = substr($request,2,-1);
			my $zone = (substr($request,0,2) eq 'MV') ? 0 : substr($request,1,1);
			Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + .1),
				\&SendNetAvpVol, $url, $vol, $zone );  # retry the volume setting
		} elsif ($request =~ m/(Z[2-4])?MUO/ && $message =~ m/onnect timed out/) {
			if ( $log->is_info ) {
				$log->debug("Mute/unmute request connect timed out - retrying"."\n");
			}
			Slim::Utils::Timers::setTimer( $request, (Time::HiRes::time() + .1),
				\&writemsg, $client, $url, 0.25 );  # retry the mute/unmute
		} elsif ($request =~ m/(PW|ZM)ON\r/ || $request =~ m/Z\d\ON\r/) {  # power on timed out
			if ($gStartupInProgress{$client} ) {  # startup power on - do Quick Select
				$gStartupInProgress{$client} = 0;
				if ( $log->is_info ) {
					$log->info("Power ON timed out. Calling handlePowerOn2\n");
				}
				$classPlugin->handlePowerOn2($client);
			} else {   # power on from menu - sync the volume
				if ( $log->is_info ) {
					$log->info("Menu power on timed out. Calling handleVolReq\n");
				}
				$classPlugin->handleVolReq($client, 2);
			}
		} elsif ($request =~ m/(MS|Z[2-4])(QUICK|SMART)\d\r/) {  # QS timed out
			if ( $log->is_info ) {
				$log->info("Quick Select timed out. Calling handleVolReq\n");
			}
			my $cprefs = $prefs->client($client);
			my $quickSelect = $cprefs->get('quickSelect');
			my $noRetry = 0;
			if (substr($request,7,1) ne $quickSelect) {  # retry only if main QS
				$noRetry = 1;
			}
			$classPlugin->handleVolReq($client, $noRetry);
		} elsif	($request =~ m/(MV|Z[2-4])\?/) {  # Vol Req timed out
			if ( $log->is_info ) {
				$log->info("Volume request timed out. Calling handleVolReq\n");
			}
			$gVolumeQueryInProgress{$client} = 0;
			$classPlugin->handleVolReq($client, 0);
		} elsif ($request =~ m/^SSSOD/ ) {
			if ( $log->is_info ) {
				$log->info("Retrying inactive input table query function\n");
			}
			Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + .1),
				\&SendNetAvpGetInputs, $url );  # retry the input table retrieval
		} elsif ($request =~ m/^SSFUN/ ) {
			if ( $log->is_info ) {
				$log->info("Retrying input table query function\n");
			}
			Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + .1),
				\&SendNetAvpGetAllInputs, $url );  # retry the input table retrieval
		} elsif ($request =~ m/PSRSTR MODE\d/ ) {
			my $mode = substr($request,11,1);
			if ( $log->is_info ) {
				$log->info("Retrying restorer mode setting for newer AVR's\n");
			}
			Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + .1),
				\&SendNetAvpRestorerMode, $url, $mode, 1 );  # retry the restorer mode for newer AVR's
		} elsif ($request =~ m/SYMO\r/ ) {
			if ( $log->is_info ) {
				$log->info("Model info request timed out - retrying\n");
			}
			Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + .1),
				\&SendNetAvpGetModelInfo, $url );  # retry the model info request
		} elsif ($request =~ m/(Z(M|[2-4])OFF)|PWSTANDBY\r/ && $message =~ m/onnect timed out/ ) {  # power off connect timed out
			if ( $log->is_info ) {
				$log->info("Power off connect timed out - retrying\n");
			}
			my $zone = (substr($request,1,1) eq 'M') ? 0 : substr($request,1,1);
			Slim::Utils::Timers::setTimer( $client, (Time::HiRes::time() + .1),
				\&SendNetAvpStandBy, $url, $zone );  # retry the power off request
		} elsif ($request =~ m/CV[A-Z]+ \d\d/ ) {
			if ( $log->is_info ) {
				$log->info("Channel volume set request timed out\n");
			}
			$classPlugin->updateChannels($client, 0);  # to reset the in-progress flag
		} elsif ($gGetPSModes{$client} > 0) {  # timed out getting the AVR menu settings
			if ( $log->is_info ) {
				$log->info("Retrying AVR menu settings request\n");
			}
			LoopGetAvpSettings($client, $url);   # retry it
		}
	}
	else {
		$gGetPSModes{$client} = 0;  # we had an error so cancel anymore outstanding AVR menu requests
	}
}

sub getCRLine($$) {
	my $socket = shift;
	my $maxWait = shift;
	my $buffer = '';
	my $start = Time::HiRes::time();
	my $c;
	my $r;
	B: while ( (Time::HiRes::time() - $start) < $maxWait ) {
		if (main::ISWINDOWS) {
			$socket->recv($c,1);
			$r = length($c);
		}
		else {
			$r = $socket->read($c,1);
		}
		if ( $r < 1 ) { next B; }
		$buffer .= $c;
		if ( $c eq "\r" ) { return $buffer; }
	}
	return $buffer;
}

sub getBuf($) {
	my $socket = shift;
	my $maxWait = shift;
	my $buffer = '';
	my $maxChars = 1024;
	my $r;

	if (!defined($maxWait) || ($maxWait == 0) ) {
		$maxWait = .125;
	}

	$log->debug("getBuf sleeping for ".$maxWait." seconds");
	Time::HiRes::sleep($maxWait);

	$log->debug("getBuf reading socket");

	if (main::ISWINDOWS) {
		$socket->recv($buffer,$maxChars);
		$r = length($buffer);
	}
	else {
		$r = $socket->read($buffer,$maxChars);
	}

	$log->debug("getBuf routine returned ".$r." chars");
	return $buffer;
}

# ----------------------------------------------------------------------------
sub _read {
	my $self  = shift;
	my $url   = shift;
	my $track = shift;
	my $args  = shift;

	my $buf;
	my $buf2;
	my @track = @$track;
	my $i;
	my $sSM;
	my $request = @track[0];
	my $client = @track[1];
	my $len;
	my $subEvent;
	my $event;
	my $callbackOK = 0; 	# the returned message when the command was successful
	my $callbackError; 	# the returned message when the command was not successful

	$gBlock{$url} = 0;  # unblock client

	my $cprefs = $prefs->client($client);
	my $avrType = $cprefs->get('pref_Avp');


	$log->debug("read routine called");
	$buf = &getCRLine($self->socket,.125);
	my $read = length($buf);

	if ($read == 0) {
		$callbackOK = 0;
		$log->debug("Error: read routine returned 0 bytes");
		$self->_catch("End of file", $url, $track, $args);
		return;
	} else {
		$callbackOK = 1;
		$log->debug("Read ".$read."\n");
	}

	$gErrorCount{$client} = 0;  #reset the error counter

	# see what is coming back from the AVP
	my $command = substr($request,0,3);

	$log->debug("Buffer read ".$buf."\n");
	$log->debug("Client name: " . $client->name . "\n");
	$log->debug("Command is:" .$request);
#	$log->debug("Subcommand is:" .$command. "\n");

	if ($request =~ m/^SSSOD \?/) {  # if inactive input table mode then need to read each item as a new line
		$buf = $buf . &getBuf($self->socket, 1);
		my @verbs;
		my @lines = split (/\r/, $buf);
		my $linectr = @lines;
		$i = 0;
		my $j = 0;
		while ($i < $linectr) {
			$buf2 = $lines[$i];
			$read = length($buf2);
			if ($read < 7) {   # get out if too short
				last;
			}
			$log->debug("SSSOD Buffer read ".$buf2);
			$event = substr($buf2,0,5);
			if ($event eq "SSSOD") {
				$buf2 = substr($buf2,5);  # bump past the 'SSSOD'
				$buf2 =~ s/\s+$//;   # trim the trailing white space
				if ($buf2 eq " END") {   # get out
					last;
				} else {
					@verbs = split (/ /, $buf2);
					if ($verbs[1] eq "DEL") {  # inactive input
						$inactiveInputs{$url,$verbs[0]} = 1;
						$j++;
						$log->debug("Inactive input table entry #" . $j . ": " . $verbs[0] . "\n");
					}
				}
			} elsif ($j) {  # exit early as long as we got at least one
				last;
			}
			$i++;
		}
		if ($j) {
			$inactiveInputs{$url,0} = $j;  # store the number of table entries
		}
	}
	elsif ($request =~ m/^SSFUN \?/) {  # if input table mode then need to read each item as a new line
		$buf = $buf . &getBuf($self->socket, 1);
		my @verbs;
		my @lines = split (/\r/, $buf);
		my $linectr = @lines;
		$i = 0;
		my $j = 0;
		while ($i < $linectr) {
			$buf2 = $lines[$i];
			$read = length($buf2);
			if ($read < 7) {   # get out if too short
				last;
			}
			$log->debug("SSFUN Buffer read ".$buf2);
			$event = substr($buf2,0,5);
			if ($event eq "SSFUN") {
				$buf2 = substr($buf2,5);  # bump past the 'SSFUN'
				$buf2 =~ s/\s+$//;   # trim the trailing white space
				if ($buf2 eq " END") {   # add tuner and network inputs for newer HEOS AVR's
					$j++;
					$inputs{$url,$j} = "TUNER|Tuner";
					$j++;
					$inputs{$url,$j} = "NET|HEOS Music";
				} else {
					@verbs = split (/ /, $buf2);
					if (!exists $inactiveInputs{$url,$verbs[0]}) {  # only add it if it is active
						$j++;
						$inputs{$url,$j} = $verbs[0] . "|" . substr($buf2, length($verbs[0])+1);
						$log->debug("Input table entry #" . $j . ": " . $inputs{$url,$j} . "\n");
					}
				}
			} elsif ($j) {  # exit early as long as we got at least one
				last;
			}
			$i++;
		}
		if ($j) {
			$inputs{$url,0} = $j;  # store the number of table entries
		}
	}
	elsif ($request =~ m/^(Z[2-4])?CV\?|^SI[^\?]/ && ($avrType != 3) ) {  #if CV mode then need to read each item as a new line
		$buf = $buf . &getBuf($self->socket, 1);

		$log->debug("gGetPSModes:  ".$gGetPSModes{$client} );

		if ($gGetPSModes{$client} != 8) {  # get out now if from power on input source select
			$self->disconnect;   # testing...
			return;
		}

		my @verbs;
		my @lines = split (/\r/, $buf);
		my $linectr = @lines;
		my $iGotFL = 0;
		$i = 0;
		$log->debug("Number of lines: ".$linectr);
		while ($i < $linectr) {
			$buf2 = $lines[$i];
			$read = length($buf2);
			$log->debug("CV Buffer read: ".$buf2);
			if ($read < 3) {   # get out if too short
				last;
			}
			if (substr($buf2,0,2) =~ m/^Z\d/) {  #secondary zone
				$buf2 = substr($buf2,2);  # bump past the zone
			}
			$event = substr($buf2,0,2);
			$i++;
			if ($event eq "CV") {
				@verbs = split (/ /, $buf2);
				$channels{$client,$verbs[0]} = $verbs[1];
				if ($verbs[0] eq "CVFL") {
					if ($iGotFL == 1) {
						last;   # exit now; we already have the table
					}
					$iGotFL = 1;
				}
			} elsif ($event ne "SI" && $event ne "MS") {  # This can come anywhere in the buffer after "SI" change
					last;   #exit and try again later
			}
		}
		if ($iGotFL == 1) {
			$channels{$client,"POPULATED"} = 1;
		}

#		if ($channels{$client,"POPULATED"} == 1 ) {
#			$log->debug(Dumper(\%channels));
#		}
	}

	if ($gGetPSModes{$client} == -1 || ($gGetPSModes{$client} == 8 && $channels{$client,"POPULATED"} == 1)) {
		Slim::Utils::Timers::killTimers( $client, \&SendTimerLoopRequest);
#		$log->debug("Disconnecting Comms Session. gGetPSModes:" . $gGetPSModes{$client} . "\n");
		$self->disconnect;   # uncommented this; fixed problem with SI? connect timing out
		$gGetPSModes{$client} = 0;
	}

	if ($request =~ m/(PW|Z(M|[2-4]))\?\r/ && $gPowerStatusInProgress{$client} ) {	 # Power status from polling
#		$gPowerStatusInProgress{$client} = 0;
		$self->disconnect;
		if ( (substr($buf,0,2) ne substr($request,0,2)) ||
				(substr($buf,2,1) ne 'O' && substr($buf,0,9) ne 'PWSTANDBY' ) ) {  # invalid resp
			$log->debug("Invalid power status polling reply - retrying...\n");
			$classPlugin->retryPowerStatus($client, 0.3);  # retry
		} else {
			$gPowerStatusInProgress{$client} = 0;
			$log->debug("Power status polling reply.\n");
			my $onOff = 0;  # default to OFF
			if (substr($buf,2,2) eq 'ON') {
				$onOff = 1;
			}
			$classPlugin->syncPowerState($client, $onOff);
		}
	} elsif ($request =~ m/(PW|Z(M|[2-4]))ON\r/ && !$gStartupInProgress{$client} ) {  # AVR power on from menu
		$log->debug("Standalone power on complete; syncing volume.\n");
		$self->disconnect;
		$classPlugin->handleVolReq($client, 2);
	} elsif ($request =~ m/(ZM|PW)ON\r/) {	# power on
		if ( (substr($buf,2,3) eq 'ON' . $CR) || (substr($buf,0,2) eq 'CV') || (substr($buf,0,2) eq 'TF') ) {
			$self->disconnect;
			$gStartupInProgress{$client} = 0;
			$log->debug("Main zone is powered on\n");
			$log->debug("Calling HandlePowerOn2\n");
			$classPlugin->handlePowerOn2($client);
		} elsif ( ($buf eq 'ZMOFF'. $CR) || ($buf eq 'PWSTANDBY'. $CR) ) {
			$self->disconnect;
			$log->debug("Calling HandlePowerOn\n");
			$classPlugin->handlePowerOn($client);
		}
	} elsif ($request =~ m/Z[2-4]ON\r/ ) {   # zone power on
		if ($buf =~ m/^Z[2-4]ON|^CV|^HD/) {	# zone is on
			$self->disconnect;
			$gStartupInProgress{$client} = 0;
			$log->debug("Zone is powered on\n");
			$log->debug("Calling handlePowerOn2\n");
			$classPlugin->handlePowerOn2($client);
		}
		elsif ($buf =~ m/Z[2-4]OFF\r/) {	 # zone is off
			$self->disconnect;
			$log->debug("Calling HandlePowerOn for Zone\n");
			$classPlugin->handlePowerOn($client);
		}
	} elsif ($request =~ m/(MS|Z[2-4])(QUICK|SMART)\d\r/) {	# quick/smart select
		$event = substr($buf,0,2);
		my $cprefs = $prefs->client($client);
		my $quickSelect = $cprefs->get('quickSelect');

		if ( $buf =~ m/(MV|Z[2-4])\d\d/) {	# see if the element is a volume
			if ( ($event eq 'MV' && substr($request,0,2) eq 'MS') || $event eq substr($request,0,2)) {   # make sure it's our volume
				$self->disconnect;
				$subEvent = substr($buf,2,3);
				# call the plugin routine to deal with the volume
				$log->debug("Calling updateSqueezeVol\n");
				$classPlugin->updateSqueezeVol($client, $subEvent);
			}
		} elsif ( ($event eq 'SI') && substr($request,0,2) eq 'MS'
				&& substr($request,7,1) eq $quickSelect ) {  #check to see if the element is an input for the main QS
			$subEvent = substr($buf,2);  # go store the input
			$subEvent =~ s/\s+$//;  # remove trailing white space
			$log->debug("Calling handleInputQuery\n");
			$classPlugin->handleInputQuery($client, $subEvent, 1);
		} else {
			$self->disconnect;
			$log->debug("Calling handleVolReq\n");
			$classPlugin->handleVolReq($client, 0);
		}
	} elsif ($request =~ m/(MS|Z[2-4])(QUICK|SMART)\d MEMORY\r/) {	# quick/smart select save
		$log->debug("Process Quick Select update response"."\n");
		$self->disconnect;
	} elsif ($request =~ m/(ZMOFF|PWSTANDBY)\r/ || $request =~ m/Z[2-4]OFF\r/ ) { #standby
		$log->debug("Disconnect socket after Standby"."\n");
		$self->disconnect;
	} elsif (($request =~ m/(MV|Z[2-4])\?/) && $gVolumeQueryInProgress{$client} ) {  # volume request
		if ($buf =~ m/(MV|Z[2-4])\d\d/) {	# see if the element is a volume
			$event = substr($buf,0,2);
			if ($event eq substr($request,0,2)) {   # make sure it's our volume
				$subEvent = substr($buf,2,3);
				# call the plugin routine to deal with the volume
				$self->disconnect;
				$gVolumeQueryInProgress{$client} = 0;
				$log->debug("AVR volume inquiry response"."\n");
				$classPlugin->updateSqueezeVol($client, $subEvent);
			}
		} elsif (($buf =~ m/Z[2-4]/) && !($buf =~ m/Z[2-4](ON|OFF)\r/) ) {	# see if the element is an input
			$log->debug("Zone input inquiry"."\n");
			$subEvent = substr($buf,2);  # go store the input
			$subEvent =~ s/\s+$//;  # remove trailing white space
			$classPlugin->handleInputQuery($client, $subEvent, 1);
		} elsif ( substr($buf,0,5) eq 'MVMAX' || substr($buf,0,2) eq 'CV' || substr($buf,0,2) eq 'HD' ) {  # in the weeds?
			$self->disconnect;
			$gVolumeQueryInProgress{$client} = 0;
			$classPlugin->handleVolReq($client, 0);  # try again
		}
	} elsif ($request =~ m/(MV|Z[2-4])\d\d/) {
		$log->debug("Process Volume Setting response" . "\n");
		$self->disconnect;
	} elsif ($request =~ m/MU\?/) {
		$log->debug("Mute status inquiry"."\n");
		$event = substr($buf,0,2);
		if ($event eq 'MU') { #check to see if the element is a muting status
			$subEvent = substr($buf,2,2);  # get the status
			if ($subEvent eq 'OF' || $subEvent eq 'ON') {
#				$self->disconnect;
				$classPlugin->handleMutingToggle($client, $subEvent);
			}
		}
	} elsif ($request =~ m/MUO/) {
		$log->debug("Process Mute response"."\n");
		$self->disconnect;
	} elsif ($request =~ m/(SI|Z[2-4])\?/ && $gInputQueryInProgress{$client}) {  # source input inquiry response
		$log->debug("AVR input inquiry"."\n");
		$event = substr($buf,0,2);
		if ($event eq substr($request,0,2)) {   # make sure it's our input request
			if (!($buf =~ m/Z\d(ON|OFF|\d\d)/)) {  #skip if it's a zone ON/OFF status or volume
				$subEvent = substr($buf,2);  # get the input
				#$log->debug("Length of string is: " . length($subEvent) );
				$self->disconnect;
				$gInputQueryInProgress{$client} = 0;
				$subEvent =~ s/\s+$//;
				$classPlugin->handleInputQuery($client, $subEvent, 0);
			}
		} else {
			$self->disconnect;
			$gInputQueryInProgress{$client} = 0;
			$classPlugin->retryInputSource($client);  # try it again later
		}
	} elsif ($request =~ m/^Z[2-4][^(CV\?)]/) {  # zone source input setting response
		$log->debug("AVR zone input setting response"."\n");
		$event = substr($buf,0,4);
		if ($event eq substr($request,0,4)) {   # make sure it's our request response
			$self->disconnect;
		}
	} elsif ($request =~ m/SYMO/) {
		$log->debug("AVR model info inquiry\n");
		if ( substr($buf,0,4) eq 'SYMO') { #check to see if the element is model info
			$subEvent = substr($buf,4);  # get the input
			$subEvent =~ s/\s+$//;
		} else {
			$subEvent = "unknown";
		}
		$self->disconnect;
		$classPlugin->handleModelInfo($client, $subEvent);
	} elsif ($request =~ m/SSFUN/) {
		$log->debug("AVR input table inquiry\n");
		$self->disconnect;
		$classPlugin->updateInputTable($client);
	} elsif ($request =~ m/MS/ || $request =~ m/^PS/ || $request =~ m/^(Z[2-4])?CV|^SI/) {
		my $iFound = 0;
		if ($request =~ m/^(Z[2-4])?CV|^SI/) {
			if ($channels{$client,"POPULATED"} == 1 ) {
				$i=0;
				if ($request =~ m/CV\?|^SI/) {
					$i=1;
				}
				$log->debug("Process Channel volume response");
				$classPlugin->updateChannels($client, $i);
				$iFound = 1;
			}
			$self->disconnect;    # we disconnected after building the table
		} else {
			my @events = split(/\r/,$buf); #break string into array
			foreach $event (@events) { # loop through the event array parts
				$log->debug("The value of the array element is: " . $event . "\n");
				$command = substr($event,0,2);
				if ($request =~ m/MS/ && $command eq 'MS') { #check to see if the element is a surround mode
					my $sModes_ref;
					my $sModes;
					if ($avrType == 1) {    # Denon AVP
						$sModes_ref = \@surroundModes;
					} else {   # AVR
						$sModes_ref = \@surroundModes_r;
					}
					$subEvent = substr($events[0],0,5);

					$i=0;
					foreach $sModes (@$sModes_ref) {
						$sSM = substr($sModes,0,5);
						if (($subEvent eq $sSM)
						  || (substr($events[0],3,2) eq "CH" && $sSM eq "MS7CH")
						  || (substr($events[0],2) =~ m/^VIRTUAL|^NEURAL|^MULTI/ && $sSM eq "MSDTS")) {
							$iFound = 1;
							last;
						}
						$i++;
					} # foreach (@$sModes)
					if (!$iFound) {  # set the surround mode to "Unknown"
						$iFound = 1;
						$i = 99;
						$sModes = "Unknown";
					}
					# call the surround mode plugin routine to set the value
					$log->debug("Surround Mode is: " . $sModes . "\n");
					$classPlugin->updateSurroundMode($client, $i);					
					$self->disconnect;
				} elsif ($request =~ m/^PS/ && $command eq 'PS') { #check to see if the element is a PS mode
					$subEvent = substr($events[0],0,6);
					if ( $subEvent eq 'PSROOM') { #room modes
						$i=0;
						foreach (@roomModes) {
							if ($roomModes[$i] eq $events[0]) {
								# call the room mode plugin routine to set the value
								$log->debug("Room Mode is: " . $roomModes[$i] . "\n");
								$classPlugin->updateRoomEq($client, $i);
								$iFound = 1;
								last;
							} # if
							$i++;
						} # foreach roomModes
					} elsif ( $subEvent eq 'PSMULT') { #mult eq modes
						$i=0;
						foreach (@multEqModes) {
							if ($multEqModes[$i] eq $events[0]) {
								# call the room mode plugin routine to set the value
								$log->debug("Mult Eq Mode is: " . $multEqModes[$i] . "\n");
								$classPlugin->updateRoomEq($client, $i);
								$iFound = 1;
								last;
							} # if
							$i++;
						} # foreach multEqModes
					} elsif ($subEvent eq 'PSDYNS') { # night mode
						$i=0;
						foreach (@nightModes) {
							if ($nightModes[$i] eq $events[0]) {
								# call the night mode plugin routine to set the value
								$log->debug("Night Mode is: " . $nightModes[$i] . "\n");
								$classPlugin->updateNM($client, $i);
								$iFound = 1;
								last;
							} # if
							$i++;
						} # foreach nightModes
					} elsif ($subEvent eq 'PSDYNV') { # night mode avr
						$i=0;
						foreach (@nightModes_avr) {
							if ($nightModes_avr[$i] eq $events[0]) {
								# call the night mode plugin routine to set the value
								$log->debug("Night Mode is: " . $nightModes_avr[$i] . "\n");
								$classPlugin->updateNM($client, $i);
								$iFound = 1;
								last;
							} # if
							$i++;
						} # foreach nightModes_avr
					} elsif ($subEvent eq 'PSDYN ') { # dynamic volume
						$i=0;
						foreach (@dynamicVolModes) {
							if ($dynamicVolModes[$i] eq $events[0]) {
								# call the dynamic vol mode plugin routine to set the value
								$log->debug("Dynamic Volume Mode is: " . $dynamicVolModes[$i] . "\n");
								$classPlugin->updateDynEq($client, $i);
								$iFound = 1;
								last;
							} # if
							$i++;
						} # foreach dynamicVolModes
					} elsif ($subEvent eq 'PSDYNE') { # dynamic equalizer for avr
						$i=0;
						foreach (@dynamicEqModes) {
							if ($dynamicEqModes[$i] eq $events[0]) {
								# call the dynamic vol mode plugin routine to set the value
								$log->debug("Dynamic Eq Mode is: " . $dynamicEqModes[$i] . "\n");
								$classPlugin->updateDynEq($client, $i);
								$iFound = 1;
								last;
							} # if
							$i++;
						} # foreach dynamicEqModes
					} elsif ($subEvent eq 'PSRSTR') { # restorer
						if ($gNewAvr{$client} == 0) {  # if it's not a newer model or we don't know yet
							$i=0;
							foreach (@restorerModes) {
								if ($restorerModes[$i] eq $events[0])  {
									# call the restorer mode plugin routine to set the value
									$log->debug("Restorer Mode is: " . $restorerModes[$i] . "\n");
									$classPlugin->updateRestorer($client, $i);
									$iFound = 1;
									last;
								} # if
								$i++;
							} # foreach restorerModes
						}
						if ($iFound == 0) {   # not found or newer model - try the new restorer modes
							$i=0;
							foreach (@restorerModes_new) {
								if ($restorerModes_new[$i] eq $events[0])  {
									# call the restorer mode plugin routine to set the value
									$log->debug("Restorer Mode is: " . $restorerModes_new[$i] . "\n");
									$classPlugin->updateRestorer($client, $i);
									$iFound = 1;
									$gNewAvr{$client} = 1;  # this is a newer model AVR
									last;
								} # if
								$i++;
							} # foreach restorerModes_new
						}
					} elsif ($subEvent eq 'PSMDAX') { # Marantz restorer mode
						$i=0;
						foreach (@restorerModes_marantz) {
							if ($restorerModes_marantz[$i] eq $events[0])  {
								# call the restorer mode plugin routine to set the value
								$log->debug("Restorer Mode is: " . $restorerModes_marantz[$i] . "\n");
								$classPlugin->updateRestorer($client, $i);
								$iFound = 1;
								last;
							} # if
							$i++;
						} # foreach restorerModes_marantz

					} elsif ($subEvent eq 'PSREFL') { # reference level
						$i=0;
						foreach (@refLevelModes) {
							if ($refLevelModes[$i] eq $events[0])  {
								# call the refence level plugin routine to set the value
								$log->debug("Reference level is: " . $refLevelModes[$i] . "\n");
								$classPlugin->updateRefLevel($client, $i);
								$iFound = 1;
								last;
							} # if
							$i++;
						} # foreach refLevelModes
					} elsif ($subEvent eq 'PSSWR ') { #subwoofer power state
						$i=0;
						foreach (@sWPowerModes) {
							if ($sWPowerModes[$i] eq $events[0])  {
								# call the sw power plugin routine to set the value
								$log->debug("Subwoofer state is: " . $sWPowerModes[$i] . "\n");
								$classPlugin->updateSw($client, $i);
								$iFound = 1;
								last;
							} # if
							$i++;
						} # foreach sWPowerModes
					}
					$self->disconnect;
				}
				else {
					$self->disconnect;  # disconnect if nothing makes sense
				}
			} # foreach (@events)
		}

		# now see if we should loop the AVP settings
		if ($gGetPSModes{$client} !=0 ) {
			if ($iFound == 1) {  #if found, get the next one else retry the request
				$gGetPSModes{$client}++;
			}
			LoopGetAvpSettings($client, $url);
		}
	} else {  # nothing we recognize
		$self->disconnect;
	}
} # _read

1;