package Plugins::DenonAvpControl::Settings;

# SqueezeCenter Copyright (c) 2001-2009 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

#	Author:	Chris Couper <chris(dot)c(dot)couper(at)gmail(dot)com>
#
#	Copyright (c) 2008-2025 Chris Couper


use strict;
use base qw(Slim::Web::Settings); #driven by the web UI

use Slim::Utils::Strings qw(string); #we want to use text from the strings file
use Slim::Utils::Log; #we want to use the log methods
use Slim::Utils::Prefs; #we want access to the preferences methods

# ----------------------------------------------------------------------------
# Global variables
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# References to other classes
# ----------------------------------------------------------------------------
my $classPlugin		= undef;

# ----------------------------------------------------------------------------
my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.denonavpcontrol',
	'defaultLevel' => 'ERROR',
	'description'  => 'PLUGIN_DENONAVPCONTROL_MODULE_NAME',
});

# ----------------------------------------------------------------------------
my $prefs = preferences('plugin.denonavpcontrol'); #name of preferences

# ----------------------------------------------------------------------------
# Define own constructor
# - to save references to Plugin.pm
# ----------------------------------------------------------------------------
sub new {
	my $class = shift;

	$classPlugin = shift;

	$log->debug( "*** DenonAvpControl::Settings::new() " . $classPlugin . "\n");

	$class->SUPER::new();

	return $class;
}

# ----------------------------------------------------------------------------
# Name in the settings dropdown
# ----------------------------------------------------------------------------
sub name { #this is what is shown in the players menu on the web gui
	return 'PLUGIN_DENONAVPCONTROL_MODULE_NAME';
}

# ----------------------------------------------------------------------------
# Webpage served for settings
# ----------------------------------------------------------------------------
sub page { #tells which file to use as the web page
	return 'plugins/DenonAvpControl/settings/basic.html';
}

# ----------------------------------------------------------------------------
# Settings are per player
# ----------------------------------------------------------------------------
sub needsClient {
	return 1; #this means this is for a particular squeezebox, not the system
}

# ----------------------------------------------------------------------------
# Only show plugin for Squeezebox 3 or Receiver players
# ----------------------------------------------------------------------------
sub validFor {
	my $class = shift;
	my $client = shift;
	# Receiver and Squeezebox2 also means SB3
	return $client->isPlayer && ($client->isa('Slim::Player::Receiver') ||
		$client->isa('Slim::Player::Squeezebox2') ||
		$client->isa('Slim::Player::SqueezeSlave'));
}

# ----------------------------------------------------------------------------
# Handler for settings page
# ----------------------------------------------------------------------------
sub handler {
	my ($class, $client, $params) = @_;
	#passes the class and client objects along with the parameters

	# $client is the client that is selected on the right side of the web interface!!!
	# We need the client identified by 'playerid'

	# Find player that fits the mac address supplied in $params->{'playerid'}
	my @playerItems = Slim::Player::Client::clients();
	foreach my $play (@playerItems) {
		if( $params->{'playerid'} eq $play->macaddress()) {
			$client = $play; #this particular player
			last;
		}
	}
	if( !defined( $client)) {
		#set the class object with the particular player
		return $class->SUPER::handler($client, $params);
		$log->debug( "Found player: " . $client . "\n");
	}


	# Fill in name of player
	if( !$params->{'playername'}) {
		#get the player name but I don't use it
		$params->{'playername'} = $client->name();
		$log->debug( "Player name: " . $params->{'playername'} . "\n");
	}

	# set a few defaults for the first time
	if ($prefs->client($client)->get('maxVol') eq '') {
		$prefs->client($client)->set('maxVol', '-10');
	}
	if ($prefs->client($client)->get('delayQuick') eq '') {
		$prefs->client($client)->set('delayQuick', '1');
	}

	# When "Save" is pressed on the settings page, this function gets called.
	if ($params->{'saveSettings'}) {
		#store the enabled value in the client prefs
		if ($params->{'pref_Enabled'}){ #save the enabled state
			$prefs->client($client)->set('pref_Enabled', 1);
		} else {
			$prefs->client($client)->set('pref_Enabled', 0);
		}
		if ($params->{'pref_PowerOnPlay'}){ #save the power on play state
			$prefs->client($client)->set('pref_PowerOnPlay', 1);
		} else {
			$prefs->client($client)->set('pref_PowerOnPlay', 0);
		}
		if ($params->{'pref_PowerSynch'}){ #save the power synch state
			$prefs->client($client)->set('pref_PowerSynch', 1);
		} else {
			$prefs->client($client)->set('pref_PowerSynch', 0);
			# Set the default polling interval when power sync is off
			$prefs->client($client)->set('powerPoll', 60);
		}
		if ($params->{'pref_VolSynch'}){ #save the volume synch state
			$prefs->client($client)->set('pref_VolSynch', 1);
		} else {
			$prefs->client($client)->set('pref_VolSynch', 0);
			# Set the default polling interval when volume sync is off
			$prefs->client($client)->set('volPoll', 0);
		}
		if ($params->{'pref_AudioMenu'}){ #save the audio menu state
			$prefs->client($client)->set('pref_AudioMenu', 1);
		} else {
			$prefs->client($client)->set('pref_AudioMenu', 0);
		}
		if ($params->{'pref_MultiZone'}){ #save the multi-zone state
			$prefs->client($client)->set('pref_MultiZone', 1);
		} else {
			$prefs->client($client)->set('pref_MultiZone', 0);
		}
		if ($params->{'avpAddress'}) { #save the AVP Address
			my $avpAddress = $params->{'avpAddress'};
			# get rid of leading spaces if any since one is always added.
			$avpAddress =~ s/^\s+(.*)\s+/\1/;
			#save the AVP address in the client prefs
			$prefs->client($client)->set('avpAddress', "$avpAddress");
		}
		if ($params->{'inputSource'}) { #save the input Source
			my $inputSource = $params->{'inputSource'};
			# get rid of leading spaces if any since one is always added.
			$inputSource =~ s/^\s+(.*)\s+/\1/;
#			$log->debug("Settings::: Input source is: |" . $inputSource  . "|\n");
			#save the input source in the client prefs
			if ( $inputSource eq "NONE") {
				$prefs->client($client)->set('inputSource', "");
			} else {
				$prefs->client($client)->set('inputSource', "$inputSource");
			}
		}
#		if ($params->{'delayOn'} =~ /^-?\d/) { #save the delay on time
#			my $delayOn = $params->{'delayOn'};
#			# get rid of leading spaces if any since one is always added.
#			$delayOn =~ s/^\s+(.*)\s+/\1/;
#			#save the delay on time in the client prefs
#			$prefs->client($client)->set('delayOn', "$delayOn");
#		}
#		if ($params->{'delayOff'} =~ /^-?\d/) { #save the delay off time
#			my $delayOff = $params->{'delayOff'};
#			# get rid of leading spaces if any since one is always added.
#			$delayOff =~ s/^\s+(.*)\s+/\1/;
#			#save the delay off time in the client prefs
#			$prefs->client($client)->set('delayOff', "$delayOff");
#		}
		if ($params->{'delayQuick'} =~ /^-?\d/) { #save the delay quick time
			my $delayQuick = $params->{'delayQuick'};
			# get rid of leading spaces if any since one is always added.
			$delayQuick =~ s/^\s+(.*)\s+/\1/;
			#save the delay quick time in the client prefs
			$prefs->client($client)->set('delayQuick', "$delayQuick");
		}
		if ($params->{'maxVol'} =~ /^-?\d/) { #save the maximum volume
			my $maxVol = $params->{'maxVol'};
			# get rid of leading spaces if any since one is always added.
			$maxVol =~ s/^\s+(.*)\s+/\1/;
			#save the maxVol in the client prefs
			$prefs->client($client)->set('maxVol', "$maxVol");
		}
		if ($params->{'powerPoll'} =~ /^-?\d/) { #save the power polling interval
			my $powerPoll = $params->{'powerPoll'};
			#save the power polling interval in the client prefs
			$prefs->client($client)->set('powerPoll', "$powerPoll");
		}
		if ($params->{'volPoll'} =~ /^-?\d/) { #save the volume polling interval
			my $volPoll = $params->{'volPoll'};
			#save the volume polling interval in the client prefs
			$prefs->client($client)->set('volPoll', "$volPoll");
		}
		$prefs->client($client)->set('quickSelect', "$params->{'quickSelect'}");
		$prefs->client($client)->set('zone', "$params->{'zone'}");
		$prefs->client($client)->set('speakers', "$params->{'speakers'}");
		$prefs->client($client)->set('pref_Avp', "$params->{'pref_Avp'}");

	}

	# Puts the values on the webpage.
	#next line takes the stored plugin pref value and puts it on the web page
	#set the enabled checkbox on the web page
	if ($prefs->client($client)->get('pref_Enabled') == '1') {
		$params->{'prefs'}->{'pref_Enabled'} = 1;
	}
	if ($prefs->client($client)->get('pref_PowerOnPlay') == '1') {
		$params->{'prefs'}->{'pref_PowerOnPlay'} = 1;
	}
	if ($prefs->client($client)->get('pref_PowerSynch') == '1') {
		$params->{'prefs'}->{'pref_PowerSynch'} = 1;
	}
	if ($prefs->client($client)->get('pref_VolSynch') == '1') {
		$params->{'prefs'}->{'pref_VolSynch'} = 1;
	}
	if ($prefs->client($client)->get('pref_AudioMenu') == '1') {
		$params->{'prefs'}->{'pref_AudioMenu'} = 1;
	}
	if ($prefs->client($client)->get('pref_MultiZone') == '1') {
		$params->{'prefs'}->{'pref_MultiZone'} = 1;
	}
	# this puts the text fields in the web page
	$params->{'prefs'}->{'avpAddress'} = $prefs->client($client)->get('avpAddress');
	$params->{'prefs'}->{'inputSource'} = $prefs->client($client)->get('inputSource');
#	$params->{'prefs'}->{'delayOn'} = $prefs->client($client)->get('delayOn');
#	$params->{'prefs'}->{'delayOff'} = $prefs->client($client)->get('delayOff');
	$params->{'prefs'}->{'delayQuick'} = $prefs->client($client)->get('delayQuick');
	$params->{'prefs'}->{'powerPoll'} = $prefs->client($client)->get('powerPoll');
	$params->{'prefs'}->{'volPoll'} = $prefs->client($client)->get('volPoll');
	$params->{'prefs'}->{'maxVol'} = $prefs->client($client)->get('maxVol');
	# set the quick select setting on the web page
	$params->{'prefs'}->{'quickSelect'} = $prefs->client($client)->get('quickSelect');
	$params->{'prefs'}->{'zone'} = $prefs->client($client)->get('zone');
	$params->{'prefs'}->{'speakers'} = $prefs->client($client)->get('speakers');
	$params->{'prefs'}->{'pref_Avp'} = $prefs->client($client)->get('pref_Avp');

	#set the plugin class variables
#	$classPlugin->setAvpAddress($prefs->client($client)->get('avpAddress'));
#	$classPlugin->setPowerDelay($prefs->client($client)->get('delayOn') ,
#	$prefs->client($client)->get('delayOff'));
#	$prefs->client($client)->get('delayQuick'));
#	$classPlugin->setMaxVolume($prefs->client($client)->get('maxVol'));

	return $class->SUPER::handler($client, $params);
}

1;

__END__

pref_Enabled