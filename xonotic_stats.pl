#!/usr/bin/perl

use strict;
use warnings;
use POSIX;
use File::Basename;
use Data::Dumper;
use Getopt::Long qw(:config gnu_getopt require_order no_auto_abbrev);

# Function prototypes
sub main();
sub processLine($);
sub getWeaponName($$);
sub logPlayerKill($$$;$);
sub logWeaponSuicide($);
sub initPlayer($);
sub output();
sub outputStatsByPlayer(); 
sub outputPlayerStats();
sub getPlayerClass($);
sub getStatHash();
sub calcAggregateData();
sub getName($;$);
sub parseArgs();
sub sortNames($$);
sub slurpFile($);
sub usage(;$);

# Globals
my $defaultLogFile = "./server.log";
my $defaultOutFile = "/var/www/html/xonotic_stats/index.html";
my $scriptDirname = dirname($0);
my $logFile = "";
my $outFile = "";
my %players = ();
my @ourNames = ('Bmor', 'MidnightReaper', 'Zach', 'Zach2', 'Zach3');

main();

###############################################################################
# Main
###############################################################################
sub main() {
	parseArgs();

	open(OUT, ">$outFile") or die ("Cant open $outFile: $!\n");

	my $fileType = `/usr/bin/file -bi $logFile`;
	if ($fileType =~ /application\/x-gzip; charset=binary/) {
		print "gzip input file\n";
		open(LOGFILE, "/bin/zcat $logFile |") or die("Cant open $logFile as gzip: $!\n");
	}
	else {
		print "text input file\n";
		open(LOGFILE, "<$logFile") or die("Cant open $logFile: $!\n");
	}
	my $line;
	while (($line = <LOGFILE>)) {
		processLine($line);
		#print "$line";
	}
	close(LOGFILE);

	output();

	print "ok\n";

	exit(0);
}


###############################################################################
# Parses each line of the server log
# Returns: Nothing
###############################################################################
sub processLine($) {
	my $line = shift;

	# log kills/deaths
	
	# Telefrag
	if ($line =~ /\^1(.+?)\^1 tried to occupy ([^']+)^1's teleport destination space/ ||
		$line =~ /\^1(.+?)\^1 was telefragged by ([^']+)/) {
			logPlayerKill($1, $2, 'Telefrag', 1);
	}
	# Water?
	elsif ($line =~ /\^1(.+?)\^1 was drowned by ([^']+)/) {
		logPlayerKill($1, $2, 'Drowning', 1);
	}
	# Slime
	elsif ($line =~ /\^1(.+?)\^1 was slimed by ([^']+)/) {
		logPlayerKill($1, $2, 'Slime', 1);
	}
	# Lava
	elsif ($line =~ /\^1(.+?)\^1 was cooked by ([^']+)/) {
		logPlayerKill($1, $2, 'Lava', 1);
	}
	# Falling
	elsif ($line =~ /\^1(.+?)\^1 was grounded by ([^']+)/) {
		logPlayerKill($1, $2, 'Falling', 1);
	}
	# Sky
	elsif ($line =~ /\^1(.+?)\^1 was shot into space by ([^']+)/) {
		logPlayerKill($1, $2, 'Sky', 1);
	}
	# Crushed
	elsif ($line =~ /\^1(.+?)\^1 was crushed by ([^']+)/) {
		logPlayerKill($1, $2, 'Crushed', 1);
	}
	# Swamp
	elsif ($line =~ /\^1(.+?)\^1 was conserved by ([^']+)/) {
		logPlayerKill($1, $2, 'Swamp', 1);
	}
	# Generic
	elsif ($line =~ /\^1(.+?)\^1 got shredded by ([^']+)/ ||
	       $line =~ /\^1(.+?)\^1 was blasted to bits by ([^']+)/ ||
	       $line =~ /\^1(.+?)\^1 got caught in the destruction of ([^']+)/ ||
	       $line =~ /\^1(.+?)\^1 was bolted down by ([^']+)/ ||
	       $line =~ /\^1(.+?)\^1 could find no shelter from ([^']+)/ ||
	       $line =~ /\^1(.+?)\^1 was pushed into the line of fire by ([^']+)/ ||
	       $line =~ /\^1(.+?)\^1 was pushed into an accident by ([^']+)/ ||
	       $line =~ /\^1(.+?)\^1 was unfairly eliminated by ([^']+)/ ||
	       $line =~ /\^1(.+?)\^1 was burnt to death by ([^']+)/ ||
	       $line =~ /\^1(.+?)\^1 was fragged by ([^']+)/) {
		logPlayerKill($1, $2, 'Generic', 1);
	}
	# Hurt
	elsif ($line =~ /\^1(.+?)\^1 was thrown into a world of hurt by ([^']+)/) {
		logPlayerKill($1, $2, 'Hurt', 1);
	}
	# Crylink
	elsif ($line =~ /\^1(.+?)\^1 could not hide from ([^']+)'s Crylink/ ||
        $line =~ /\^1(.+?)\^1 was too close to ([^']+)'s Crylink/ ||
        $line =~ /\^1(.+?)\^1 took a close look at ([^']+)'s Crylink/) {
			logPlayerKill($1, $2, 'Crylink');
	}
	# Electro
	elsif ($line =~ /\^1(.+?)\^1 just noticed ([^']+)'s blue ball/ ||
           $line =~ /\^1(.+?)\^1 got in touch with ([^']+)'s blue ball/ ||
           $line =~ /\^1(.+?)\^1 felt the electrifying air of ([^']+)'s combo/ ||
           $line =~ /\^1(.+?)\^1 got too close to ([^']+)'s blue beam/ ||
           $line =~ /\^1(.+?)\^1 was blasted by ([^']+)'s blue beam/) {
			logPlayerKill($1, $2, 'Electro');
	}
	# Fireball
	elsif ($line =~ /\^1(.+?)\^1 tried to catch ([^']+)'s firemine/ ||
           $line =~ /\^1(.+?)\^1 fatefully ignored ([^']+)'s firemine/ ||
           $line =~ /\^1(.+?)\^1 could not hide from ([^']+)'s fireball/ ||
           $line =~ /\^1(.+?)\^1 saw the pretty lights of ([^']+)'s fireball/ ||
           $line =~ /\^1(.+?)\^1 got too close to ([^']+)'s fireball/ ||
           $line =~ /\^1(.+?)\^1 tasted ([^']+)'s fireball/) {
			logPlayerKill($1, $2, 'Fireball');
	}
	# Hagar
	elsif ($line =~ /\^1(.+?)\^1 hoped ([^']+)'s missiles wouldn't bounce/ ||
           $line =~ /\^1(.+?)\^1 was pummeled by ([^']+)/) {
			logPlayerKill($1, $2, 'Hagar');
	}
	# HLAC
	elsif ($line =~ /\^1(.+?)\^1 was cut down by ([^']+)/) {
			logPlayerKill($1, $2, 'HLAC');
	}
	# Hook
	elsif ($line =~ /\^1(.+?)\^1 has run into ([^']+)'s gravity bomb/) {
			logPlayerKill($1, $2, 'Grappling Hook');
	}
	# Laser
	elsif ($line =~ /\^1(.+?)\^1 was cut in half by ([^']+)'s gauntlet/ ||
           $line =~ /\^1(.+?)\^1 was lasered to death by ([^']+)/) {
			logPlayerKill($1, $2, 'Laser');
	}
	# Machine Gun
	elsif ($line =~ /\^1(.+?)\^1 was sniped by ([^']+)/ ||
           $line =~ /\^1(.+?)\^1 was riddled full of holes by ([^']+)/) {
			logPlayerKill($1, $2, 'Machine Gun');
	}
	# Minelayer
	elsif ($line =~ /\^1(.+?)\^1 got too close to ([^']+)'s mine/ ||
           $line =~ /\^1(.+?)\^1 almost dodged ([^']+)'s mine/ ||
           $line =~ /\^1(.+?)\^1 stepped on ([^']+)'s mine/) {
			logPlayerKill($1, $2, 'Mine Layer');
	}
	# Minstanex
	elsif ($line =~ /\^1(.+?)\^1 has been vaporized by ([^']+)/) {
			logPlayerKill($1, $2, 'MinstaNex');
	}
	# Mortar
	elsif ($line =~ /\^1(.+?)\^1 didn't see ([^']+)'s grenade/ ||
           $line =~ /\^1(.+?)\^1 almost dodged ([^']+)'s grenade/ ||
           $line =~ /\^1(.+?)\^1 ate ([^']+)'s grenade/) {
			logPlayerKill($1, $2, 'Mortar');
	}
	# Nex
	elsif ($line =~ /\^1(.+?)\^1 has been vaporized by ([^']+)/) {
			logPlayerKill($1, $2, 'Nex');
	}
	# Rocketlauncher
	elsif ($line =~ /\^1(.+?)\^1 got too close to ([^']+)'s rocket/ ||
           $line =~ /\^1(.+?)\^1 almost dodged ([^']+)'s rocket/ ||
           $line =~ /\^1(.+?)\^1 ate ([^']+)'s rocket/) {
			logPlayerKill($1, $2, 'Rocket Launcher');
	}
	# TAG Seeker
	elsif ($line =~ /\^1(.+?)\^1 ran into ([^']+)'s flac/ ||
           $line =~ /\^1(.+?)\^1 was tagged by ([^']+)/ ||
           $line =~ /\^1(.+?)\^1 was pummeled by ([^']+)/) {
			logPlayerKill($1, $2, 'T.A.G. Seeker');
	}
	# Shotgun
	elsif ($line =~ /\^1(.+?)\^1 \^7slapped ([^']+) ^7around a bit with a large ^2shotgun/ ||
           $line =~ /\^1(.+?)\^1 was gunned by ([^']+)/) {
			logPlayerKill($1, $2, 'Shotgun');
	}
	# Sniper Rifle
	elsif ($line =~ /\^1(.+?)\^1 failed to hide from ([^']+)'s bullet hail/ ||
           $line =~ /\^1(.+?)\^1 died in ([^']+)'s bullet hail/ ||
           $line =~ /\^1(.+?)\^1 failed to hide from ([^']+)'s rifle/ ||
           $line =~ /\^1(.+?)\^1 got hit in the head by ([^']+)/ ||
           $line =~ /\^1(.+?)\^1 was sniped by ([^']+)/) {
			logPlayerKill($1, $2, 'Sniper Rifle');
	}
	elsif ($line =~ /\^1(.+?)\^1 died of ([^']+)'s great playing on the @!#%'n Tuba/) {
		logPlayerKill($1, $2, 'Tuba');
	}
	elsif (
		#grenadelauncher: %s almost dodged %s's grenade
		#minelayer: %s almost dodged %s's mine
		#rocketlauncher: %s almost dodged %s's rocket
		$line =~ /\^1(.+?)\^1 almost dodged ([^']+)/ || 
		#grenadelauncher: %s ate %s's grenade
		#rocketlauncher: %s ate %s's rocket
		$line =~ /\^1(.+?)\^1 ate ([^']+)/ || 
		#crylink: %s could not hide from %s's Crylink
		#fireball: %s could not hide from %s's fireball
	    $line =~ /\^1(.+?)\^1 could not hide from ([^']+)/ || 
		#grenadelauncher: %s didn't see %s's grenade
		$line =~ /\^1(.+?)\^1 didn't see ([^']+)/ ||  
		#sniperrifle: %s died in %s's bullet hail
		$line =~ /\^1(.+?)\^1 died in ([^']+)/ ||
		# ??? dont know what this message is...
		$line =~ /\^1(.+?)\^1 died of ([^']+)/ ||
		#sniperrifle: %s failed to hide from %s's bullet hail
		$line =~ /\^1(.+?)\^1 failed to hide from ([^']+)/ ||
		#fireball: %s fatefully ignored %s's firemine
		$line =~ /\^1(.+?)\^1 fatefully ignored ([^']+)/ ||
		#electro: %s felt the electrifying air of %s's combo
		$line =~ /\^1(.+?)\^1 felt the electrifying air of ([^']+)/ ||
		$line =~ /\^1(.+?)\^1 got hit in the head by ([^']+)/ ||
		#electro: %s got in touch with %s's blue ball
		$line =~ /\^1(.+?)\^1 got in touch with ([^']+)/ || 
		#electro: %s got too close to %s's blue beam
		#fireball: %s got too close to %s's fireball
		#minelayer: %s got too close to %s's mine
		#rocketlauncher: %s got too close to %s's rocket
		($line =~ /\^1(.+?)\^1 got too close to ([^']+)/ && $line !~ /the reaction/) || 
		#minstanix: %s has been vaporized by %s
		#nex: %s has been vaporized by %s
		$line =~ /\^1(.+?)\^1 has been vaporized by ([^']+)/ ||
		#hook: %s has run into %s's gravity bomb
		$line =~ /\^1(.+?)\^1 has run into ([^']+)/ ||
		#hagar: %s hoped %s's missiles wouldn't bounce
		$line =~ /\^1(.+?)\^1 hoped ([^']+)/ ||
		#electro: %s just noticed %s's blue ball
		$line =~ /\^1(.+?)\^1 just noticed ([^']+)/ || 
		#flac: %s ran into %s
		$line =~ /\^1(.+?)\^1 ran into ([^']+)/ ||
		#fireball: %s saw the pretty lights of %s's fireball
		$line =~ /\^1(.+?)\^1 saw the pretty lights of ([^']+)/ || 
		#minelayer: %s stepped on %s's mine
		$line =~ /\^1(.+?)\^1 stepped on ([^']+)/ ||
		#fireball: %s tasted %s's fireball
		$line =~ /\^1(.+?)\^1 tasted ([^']+)/ || 
		#crylink: %s took a close at %s's Crylink
		$line =~ /\^1(.+?)\^1 took a close look at ([^']+)/ ||
		#fireball: %s tried to catch %s's firemine
		$line =~ /\^1(.+?)\^1 tried to catch ([^']+)/ ||
		#crylink: %s was too close to %s's Crylink
		$line =~ /\^1(.+?)\^1 was too close to ([^']+)/ ||
		#tuba: %s died of %s's great playing on the @!#%%'n Tuba
		$line =~ /\^1(.+?)\^1 died of ([^']+)'s great playing on the @!#%'n Tuba/ ||
		##electro: %s was blasted by %s's blue beam
		#hagar: %s was pummeled by %s
		#hlac: %s was cut down by %s
		#laser: %s was cut in half by %s's gauntlet
		#laser: %s was lasered to death by %s
		#flac: %s was tagged by %s
		#shotgun: %s was gunned by %s
		#uzi: %s was sniped by %s
		#uzi: %s was riddled full of holes by %s
		($line =~ /\^1(.+?)\^1 was .+ by ([^']+)/ && $line !~ /spree/)
	) {
		print "$line";
		logPlayerKill($1, $2, 'Unkown Weapon');
	}
	# log weapon suicides
	elsif (
		$line =~ /\^1(.+?)\^1 burned to death/ ||
		$line =~ /\^1(.+?)\^1 could not remember where (?:they|he) put plasma/ || #electro
		$line =~ /\^1(.+?)\^1 couldn't resist the urge to self-destruct/ ||
		$line =~ /\^1(.+?)\^1 couldn't take it anymore/ ||
		$line =~ /\^1(.+?)\^1 detonated/ || #mortar
		$line =~ /\^1(.+?)\^1 did the impossible/ || #minstanex || nex || shotgun || uzi/machinegun
		$line =~ /\^1(.+?)\^1 died/ || #generic
		$line =~ /\^1(.+?)\^1 exploded/ || #rocket launcher || minelayer
		$line =~ /\^1(.+?)\^1 forgot about some firemine/ || #fireball
		$line =~ /\^1(.+?)\^1 hurt his own ears/ || #tuba
		$line =~ /\^1(.+?)\^1 lasered themself to hell/ || #laser
		$line =~ /\^1(.+?)\^1 played with plasma/ || #electro
		$line =~ /\^1(.+?)\^1 played with tiny rockets/ || #hagar || seeker
		$line =~ /\^1(.+?)\^1 shot (?:them|him)self automatically/ || #rifle
		$line =~ /\^1(.+?)\^1 should have used a smaller gun/ || #fireball || hlac
		$line =~ /\^1(.+?)\^1 sniped (?:them|him)self somehow/ || #rifle
		$line =~ /\^1(.+?)\^1 succeeded at self-destructing (?:them|him)self with the Crylink/ || #crylink
		$line =~ /\^1(.+?)\^1 thought they found a nice camping ground/ || #camping
		$line =~ /\^1(.+?)\^1 tried out his own grenade/ || #mortar
		$line =~ /\^1(.+?)\^1 unfairly eliminated (?:them|him)self/ ||
		$line =~ /\^1(.+?)\^1 will be reinserted into the game due to his own actions/ 
	) {
		logWeaponSuicide($1);
	}
	# log other deaths.  Most of these are defined inside custom maps
	elsif (
		$line =~ /\^1(.+?)\^1\s+didn't want to play any more/ ||
		$line =~ /\^1(.+?)\^1\s+had nothing to breathe/ ||
		$line =~ /\^1(.+?)\^1\s+floated into space/ ||
		$line =~ /\^1(.+?)\^1\s+got too close to the reaction/ ||
		$line =~ /\^1(.+?)\^1\s+got some falling to do/ ||
		$line =~ /\^1(.+?)\^1\s+was impaled/ ||
		$line =~ /\^1(.+?)\^1\s+was terminated in a fall/ ||
		$line =~ /\^1(.+?)\^1\s+fell down from heaven/ ||
		$line =~ /\^1(.+?)\^1\s+took the high ground/ ||
		$line =~ /\^1(.+?)\^1\s+hit the ground with a crunch/ ||
		$line =~ /\^1(.+?)\^1\s+drowned/ ||
		$line =~ /\^1(.+?)\^1\s+was slimed/ ||
		$line =~ /\^1(.+?)\^1\s+turned into hot slag/ ||
		$line =~ /\^1(.+?)\^1\s+became a shooting star/ ||
		$line =~ /\^1(.+?)\^1\s+is now conserved for centuries to come/ ||
		$line =~ /\^1(.+?)\^1\s+died in an accident/ ||
		$line =~ /\^1(.+?)\^1\s+was unfairly eliminated/ ||
		$line =~ /\^1(.+?)\^1\s+burnt to death/
	) {
		my $player = getName($1);
		$players{$player}{'otherSuicides'}++;
	}
	# log the first kill
	elsif ($line =~ /\^1(.+?)\^1 drew first blood/ || $line =~ /\^1(.+?)\^1 was the first to score/) {
		my $player = getName($1);
		$players{$player}{'firstKills'}++;
	}
	# log teammate kills
	elsif (
		$line =~ /\^1(.+?)\^1 didn't become friends with the Lord of Teamplay/ ||
		$line =~ /\^1(.+?)\^1 mows down a team mate/ ||
		$line =~ /\^1(.+?)\^1 took action against a team mate/
	) {
		my $player = getName($1);
		$players{$player}{'teammateKills'}++;
	}
	# log match wins
	elsif ($line =~ /(?:\|\^7)(.+?) \^7wins./) {
		my $player = getName($1);
		$players{$player}{'totalWins'}++;
	}
	# log player joins
	elsif ($line =~ /\^4(.+?)\^4 is playing now/) {
		my $player = getName($1, 0); #don't initialize player hash, just get name
		
		if (!defined($players{$player})) {
			# Initialize the player hash, with 1 game played.
			# if the player name is not defined at this point, it is because the player just joined the game after the 
			# 	player who is logging
			getName($player);
		}
		else {
			# This will happen either when a player first joins (after the logging player) or at the start of subsequent rounds
			$players{$player}{'gamesPlayed'}++;
		}
	}
	# log picking-up of keys
	elsif ($line =~ /(?:\|\^7)(.+?)\^7 picked up the \^\d([^ ]+?) key/) {
		my $player = getName($1);
		my $keyColor = getName($2, 0);
		$players{$player}{'keyPickups'}++;
		$players{$player}{'tempKeycount'}++;
	}
	# log losing of keys
	elsif ($line =~ /(?:\|\^7)(.+?)\^7 died and lost the \^\d([^ ]+?) key/) {
		my $player = getName($1);
		my $keyColor = getName($2, 0);
		$players{$player}{'keyLosses'}++;
		$players{$player}{'tempKeycount'} = 0;
	}
	# log key captures
	elsif ($line =~ /(?:\|\^7)(.+?)\^7 captured the keys for the (.*?) Team\^7/) {
		my @playerList = split(/, /, $1);
		@playerList = map {getName($_)} @playerList;
		my $team = getName($2, 0);

		# add keys each play has
		foreach my $player (@playerList) {
			$players{$player}{'keyCaptures'} += $players{$player}{'tempKeycount'};
		}
		# clear all temp key counts... shouldnt be needed
		my $keyCount = 0;
		foreach my $player (keys %players) {
			$keyCount += $players{$player}{'tempKeycount'};
			$players{$player}{'tempKeycount'} = 0;
		}
		print "keycount $keyCount > 4\n" if ($keyCount > 4);
	}
	# clear keys when player pushed
	elsif ($line =~ /The (.*?)\^7 could not take care of the (\^\d[^ ]+) key/) {
		foreach my $player (keys %players) {
			$players{$player}{'tempKeycount'} = 0;
		}
	}
	# clear temp counters at end of map
	elsif ($line =~ /done!$/ || $line =~ /^\^7\/) {
		foreach my $player (keys %players) {
			$players{$player}{'tempKeycount'} = 0;
			if ($players{$player}{'tempHighestKills'} > $players{$player}{'highestKills'}) {
				$players{$player}{'highestKills'} = $players{$player}{'tempHighestKills'};
			}
			$players{$player}{'tempHighestKills'} = 0;
			$players{$player}{'curWeapon'} = '';
		}
	}
	# clear tempHighestKills when players (dis)connect
	elsif ($line =~ /\^4(.+?)\^4 connected/ || $line =~ /\^4(.+?)\^4 disconnected/) {
		my $player = getName($1);
		if ($players{$player}{'tempHighestKills'} > $players{$player}{'highestKills'}) {
			$players{$player}{'highestKills'} = $players{$player}{'tempHighestKills'};
		}
		$players{$player}{'tempHighestKills'} = 0;
		$players{$player}{'curWeapon'} = '';
	}
	# log weapon assignments
	elsif ($line =~ /^\^7(.+?)\^7 was assigned the \^3(.+?)$/) {
		my $player = getName($1);
		my $weaponName = $2;
		$weaponName =~ s/Heavy Laser Assault Cannon/HLAC/;
		$weaponName = getName($weaponName, 0);
		$players{$player}{'curWeapon'} = $weaponName;
		$players{$player}{'weaponAssignments'}{$weaponName}++;
	}
}


###############################################################################
# Gets weapon name from $players hash or passed var
# Param $player: Name of player
# Param $defaultWeaponName: Name of weapon used for kill, if not defined in $player hash
# Returns: Weapon name based on current player, or $defaultWeaponName
###############################################################################
sub getWeaponName($$) {
	my $player = shift;
	my $defaultWeaponName = shift;
	
	if ($players{$player}{'curWeapon'}) {
		return $players{$player}{'curWeapon'};
	}
	
	return $defaultWeaponName;
}

###############################################################################
# Logs a player kill
# Param $victim: Name of the victim
# Param $killer: Name of the killer
# Param $weapon: Name of weapon used for kill
# Param $weaponAsIs: Use weaponName as it is passed in, instead of from $players array
# Returns: Nothing
###############################################################################
sub logPlayerKill($$$;$) {
	my $victim = getName(shift);
	my $killer = getName(shift);
	my $weapon = getName(shift, 0);
	my $weaponNameAsIs = shift || 0;
	
	if (!$weaponNameAsIs) {
		$weapon = getWeaponName($killer, $weapon);
	}

	# record total kills and deaths
	$players{$killer}{'totalKills'}++;
	$players{$killer}{'tempHighestKills'}++;
	$players{$victim}{'totalDeaths'}++;

	# bot kills bot
	if ($killer =~ /\[BOT\]/ && $victim =~ /\[BOT\]/) {
		$players{$killer}{'botKills'}++;
		$players{$victim}{'botDeaths'}++;
	}
	# bot kills player
	elsif ($killer =~ /\[BOT\]/ && $victim !~ /\[BOT\]/) {
		$players{$killer}{'nonbotKills'}++;
		$players{$victim}{'botDeaths'}++;
	}
	# player kills bot
	elsif ($killer !~ /\[BOT\]/ && $victim =~ /\[BOT\]/) {
		$players{$killer}{'botKills'}++;
		$players{$victim}{'nonbotDeaths'}++;
	}
	# player kills player
	elsif ($killer !~ /\[BOT\]/ && $victim !~ /\[BOT\]/) {
		$players{$killer}{'nonbotKills'}++;
		$players{$victim}{'nonbotDeaths'}++;
	}

	# record kills/deaths per killer/victim
	$players{$killer}{'playersKilled'}{$victim}++;
	$players{$victim}{'killedByPlayers'}{$killer}++;
	$players{$killer}{'weaponKills'}{$weapon}++;
	$players{$victim}{'weaponDeaths'}{$weapon}++;
}


###############################################################################
# Logs a player suicide
# Param $victim: Name of the player
# Param $weapon: Name of weapon used for kill
# Returns: Nothing
###############################################################################
sub logWeaponSuicide($) {
	my $player = getName(shift);
	#my $weapon = getName(shift, 0);
	my $weapon = getWeaponName($player, "Unknown Weapon");

	$players{$player}{'allWeaponSuicides'}++;
	$players{$player}{'weaponSuicides'}{$weapon}++;
}

###############################################################################
# Initializes player hash if not defined
# Param $name: Name of the player
# Returns: Nothing
###############################################################################
sub initPlayer($) {
	my $name = shift;

	if (!defined($players{$name})) {
		#print "Player $name is not yet defined\n";
		$players{$name} = {
			'playerName'=>$name,
			'totalKills'=>0,
			'totalDeaths'=>0,
			'totalRatio'=>0,
			'nonbotKills'=>0,
			'nonbotDeaths'=>0,
			'nonbotRatio'=>0,
			'botKills'=>0,
			'botDeaths'=>0,
			'botRatio'=>0,
			'highestKills'=>0,
			'tempHighestKills'=>0,
			'teammateKills'=>0,
			'firstKills'=>0,
			'allWeaponSuicides'=>0,
			'otherSuicides'=>0,
			'gamesPlayed'=>1, #start at 1 because the player could join before the player who is logging
			'keyPickups'=>0,
			'keyLosses'=>0,
			'keyCaptures'=>0,
			'tempKeycount'=>0,
			'totalWins'=>0,
			'WinPercent'=>0,
			'playersKilled'=>{},
			'killedByPlayers'=>{},
			'curWeapon'=>'',
			'weaponAssignments'=>{},
			'weaponKills'=>{},
			'weaponDeaths'=>{},
			'weaponSuicides'=>{}
		};
	}
}


###############################################################################
# Outputs stats to HTML
# Returns: Nothing
###############################################################################
sub output() {
	my $outputDirname = dirname($outFile);
	`cp "$scriptDirname/stats.css" "$outputDirname/"` if ( -e "$scriptDirname/stats.css");
	`cp "$scriptDirname/jquery.js" "$outputDirname/"` if ( -e "$scriptDirname/jquery.js");

	my $template = slurpFile("$scriptDirname/template.html");

	my $time = strftime("%m-%d-%Y %H:%M:%S", localtime);
	$template =~ s/#date_time#/$time/;

	calcAggregateData();
	my $statTable = outputStatsByPlayer();
	my $playerStats = outputPlayerStats();

	$template =~ s/#total_stat_table#/$statTable/;
	$template =~ s/#player_stats#/$playerStats/;

	print OUT $template;
}


###############################################################################
# Outputs StatByPlayer table
# Returns: Nothing
###############################################################################
sub outputStatsByPlayer() {
	my @colNames = getStatHash();

	my $statTable = "";
	my $rowId = 1;
	my $colId = 1;

	$statTable .= "\t<table border='1'>\n";

	$statTable .= "\t\t<tr class='Row01'>\n";
	foreach my $headers (@colNames) {
		my $ci = sprintf("%02i", $colId);
		my $header = $headers->{title};
		$header =~ s/ /<br\/>/g if ($colId > 1);
		$statTable .= "\t\t\t<td class='Col$ci Title'>$header</td>\n";
		$colId++;
	}
	$statTable .= "\t\t</tr>\n";
	$rowId++;

	foreach my $player (sort sortNames keys %players) {
		my $ri = sprintf("%02i", $rowId);
		my $playerType = getPlayerClass($player);

		$statTable .= "\t\t<tr class='Row$ri $playerType'>\n";
		$colId = 1;
		foreach my $stat (@colNames) {
			my $ci = sprintf("%02i", $colId);
			my $value = $players{$player}{$stat->{value}};

			if ($colId == 1) {
				$statTable .= "\t\t\t<td class='Col$ci Title'><a href='#PlayerStats_$value'>$value</a></td>\n";
			}
			else {
				$statTable .= "\t\t\t<td class='Col$ci'>$value</td>\n";
			}
			$colId++;
		}
		$statTable .= "\t\t</tr>\n";
		$rowId++;
	}

	$statTable .= "\t</table>\n";

	return $statTable;
}


###############################################################################
# Outputs div per player
###############################################################################
sub outputPlayerStats() {
	my @colNames = getStatHash();
	my $playerStats = "";
	my $tabs = (" " x 4) x 4;
	my $playerStatTemplate = slurpFile("$scriptDirname/player_stat_template.html");

	foreach my $playerName (sort sortNames keys %players) {
		my %playerData = %{$players{$playerName}};

		my $totalKills = $playerData{'totalKills'};
		my $totalDeaths = $playerData{'totalDeaths'};
		my $totalRatio = $playerData{'totalRatio'};
		my $nonbotKills = $playerData{'nonbotKills'};
		my $nonbotDeaths = $playerData{'nonbotDeaths'};
		my $nonbotRatio = $playerData{'nonbotRatio'};
		my $botKills = $playerData{'botKills'};
		my $botDeaths = $playerData{'botDeaths'};
		my $botRatio = $playerData{'botRatio'};
		my $highestKills = $playerData{'highestKills'};
		my $teamKills = $playerData{'teammateKills'};
		my $firstKills = $playerData{'firstKills'};
		my $allWeaponSuicides = $playerData{'allWeaponSuicides'};
		my $otherSuicides = $playerData{'otherSuicides'};
		my $keyPickups = $playerData{'keyPickups'};
		my $keyLosses = $playerData{'keyLosses'};
		my $keyCaptures = $playerData{'keyCaptures'};
		my $gamesPlayed = $playerData{'gamesPlayed'};
		my $totalWins = $playerData{'totalWins'};
		my $winPercent = $playerData{'WinPercent'};

		my $playerType = getPlayerClass($playerName);

		my $playerKills = '';
		foreach my $otherPlayerName (sort sortNames keys %{$playerData{'playersKilled'}}) {
			my $playerClass = getPlayerClass($otherPlayerName);
			$playerKills .= "$tabs<tr class='$playerClass'><th><a href='#PlayerStats_$otherPlayerName'>$otherPlayerName</a></th><td>$playerData{'playersKilled'}{$otherPlayerName}</td></tr>\n";
		}

		my $playerDeaths = '';
		foreach my $otherPlayerName (sort sortNames keys %{$playerData{'killedByPlayers'}}) {
			my $playerClass = getPlayerClass($otherPlayerName);
			$playerDeaths .= "$tabs<tr class='$playerClass'><th><a href='#PlayerStats_$otherPlayerName'>$otherPlayerName</a></th><td>$playerData{'killedByPlayers'}{$otherPlayerName}</td></tr>\n";
		}

		my $weaponAssignments = '';
		foreach my $weaponName (sort keys %{$playerData{'weaponAssignments'}}) {
			$weaponAssignments .= "$tabs<tr><th>$weaponName</th><td>$playerData{'weaponAssignments'}{$weaponName}</td></tr>\n";
		}

		my $weaponKills = '';
		foreach my $weaponName (sort keys %{$playerData{'weaponKills'}}) {
			$weaponKills .= "$tabs<tr><th>$weaponName</th><td>$playerData{'weaponKills'}{$weaponName}</td></tr>\n";
		}

		my $weaponDeaths = '';
		foreach my $weaponName (sort keys %{$playerData{'weaponDeaths'}}) {
			$weaponDeaths .= "$tabs<tr><th>$weaponName</th><td>$playerData{'weaponDeaths'}{$weaponName}</td></tr>\n";
		}

		my $weaponSuicides = '';
		foreach my $weaponName (sort keys %{$playerData{'weaponSuicides'}}) {
			#print $weaponName."\n";
			$weaponSuicides .= "$tabs<tr><th>$weaponName</th><td>$playerData{'weaponSuicides'}{$weaponName}</td></tr>\n";
		}

		$playerStats .= eval qq/"$playerStatTemplate"/;
	}

	return $playerStats;
}

###############################################################################
# Get CSS class name from player name
# Returns: CSS class name
###############################################################################
sub getPlayerClass($) {
	my $playerName = shift;
	my $playerType;

	if ($playerName =~ /^\[BOT\]/i) {
		$playerType = "PTypeBot";
	}
	elsif (grep {lc $playerName eq lc $_} @ourNames) {
		$playerType = "PTypePlayerUs";
	}
	else {
		$playerType = "PTypePlayerOther";
	}

	return $playerType;
}


###############################################################################
# All stats
# Returns: Array of hashes of all stats
###############################################################################
sub getStatHash() {
	my @playerStats = (
		{title=>'Player Name',      value=>'playerName'},
		{title=>'Total Kills',      value=>'totalKills'},
		{title=>'Total Deaths',     value=>'totalDeaths'},
		{title=>'Total Ratio',      value=>'totalRatio'},
		{title=>'Nonbot Kills',     value=>'nonbotKills'},
		{title=>'Nonbot Deaths',    value=>'nonbotDeaths'},
		{title=>'Nonbot Ratio',     value=>'nonbotRatio'},
		{title=>'Bot Kills',        value=>'botKills'},
		{title=>'Bot Deaths',       value=>'botDeaths'},
		{title=>'Bot Ratio',        value=>'botRatio'},
		{title=>'Highest Kills',    value=>'highestKills'},
		{title=>'Team Kills',       value=>'teammateKills'},
		{title=>'First Kills',      value=>'firstKills'},
		{title=>'Weapon Suicides',  value=>'allWeaponSuicides'},
		{title=>'Other Suicides',   value=>'otherSuicides'},
		{title=>'Key Pickups',      value=>'keyPickups'},
		{title=>'Key Losses',       value=>'keyLosses'},
		{title=>'Key Captures',     value=>'keyCaptures'},
		{title=>'Games Played',     value=>'gamesPlayed'},
		{title=>'Total Wins',       value=>'totalWins'},
		{title=>'Win Percent',      value=>'WinPercent'}
	);

	return @playerStats;
}


###############################################################################
# Calculates aggregate (kill/death ratios, etc) data for each player
# Returns: Nothing
###############################################################################
sub calcAggregateData() {
	foreach my $playerName (sort keys %players) {
		my $playerData = $players{$playerName};
		$playerData->{'totalRatio'} = $playerData->{'totalDeaths'} == 0 ? 0 :
			sprintf('%.3f', $playerData->{'totalKills'} / $playerData->{'totalDeaths'});
		$playerData->{'botRatio'} = $playerData->{'botDeaths'} == 0 ? 0 :
			sprintf('%.3f', $playerData->{'botKills'} / $playerData->{'botDeaths'});
		$playerData->{'nonbotRatio'} = $playerData->{'nonbotDeaths'} == 0 ? 0 :
			sprintf('%.3f', $playerData->{'nonbotKills'} / $playerData->{'nonbotDeaths'});
		$playerData->{'WinPercent'} = $playerData->{'gamesPlayed'} == 0 ? '0%' :
			sprintf('%.2f%%', $playerData->{'totalWins'} / $playerData->{'gamesPlayed'} * 100);
	}
}


###############################################################################
# Gets a name without special chars and encodes html entities
# Param $name: The string to clean up
# Param $init: Whether to init name as a player
# Returns: Name without special chars and encoded html entities
###############################################################################
sub getName($;$) {
    my $name = shift;
    my $init = shift // 1; #$_[0] // 1; #init name by default

    $name =~ s/\^x[\da-fA-F]{3}//g; #strip color codes
    $name =~ s/`/&lsquo;/g;
    $name =~ s/&/&amp;/g;
    $name =~ s/'/&apos;/g;
    $name =~ s/"/&quot;/g;
    $name =~ s/</&lt;/g;
    $name =~ s/>/&gt;/g;
    $name =~ s/( |\t)/&nbsp;/g;
    $name =~ s/[^a-zA-Z0-9!#%&\(\)\*\+,.\/:;=\?@\[\]\^_\{\}\|~-]//g;
    $name =~ s/\^\d//g;

    initPlayer($name) if ($init);

    return $name;
}


###############################################################################
# Parse commandline params and exit if anything is wrong
# Returns: Nothing
###############################################################################
sub parseArgs() {
	my $optionHelp = 0;
	GetOptions("h|?|help" => \$optionHelp);
	usage() if ($optionHelp);

	$logFile = $ARGV[0] // $defaultLogFile;
	usage("'$logFile' is not a file or is not readable") if (! -e $logFile || ! -r $logFile);

	$outFile = $ARGV[1] // $defaultOutFile;
	usage("'$outFile' must end in .html") if ($outFile !~ /\.html$/);
	usage("'".dirname($outFile)."' is not a directory or is not writable") if (! -d dirname($outFile) || ! -w dirname($outFile));
	usage("'$outFile' exists, but is not writable") if ( -e $outFile && ! -w $outFile);
}


###############################################################################
# Sorts player names.  Our names come first, then other players, then bots
###############################################################################
sub sortNames($$) {
	my $a = lc shift;
	my $b = lc shift;

	my $aUs = grep {$a eq lc $_} @ourNames;
	my $bUs = grep {$b eq lc $_} @ourNames;
	my $aBot = ($a =~ /^\[bot\]/);
	my $bBot = ($b =~ /^\[bot\]/);

	if ($aUs && $bUs) { #Us vs Us
		return $a cmp $b;
	}
	elsif ($aUs && !$bUs) { #Us vs not Us
		return -1;
	}
	elsif (!$aUs && $bUs) { #Not Us vs Us
		return 1;
	}
	elsif (!$aBot && !$bBot) { #Non-bot vs non-bot
		return $a cmp $b;
	}
	elsif ($aBot && !$bBot) { #Bot vs non-bot
		return 1;
	}
	elsif (!$aBot && $bBot) { #Non-bot vs bot
		return -1;
	}
	else {
		return $a cmp $b;
	}
}


###############################################################################
# Reads entire file into a variable
# Param $filename: The name of the file to read
# Returns: The contents of the file
###############################################################################
sub slurpFile($) {
	my $filename = shift;
	local $/;

	open(FILE, "<$filename") or die("cant open file '$filename' for slurping: $!\n\n");
	my $str = <FILE>;
	close(FILE);

	return $str;
}

###############################################################################
# Prints usage message and then exits
# Param $message: An optional message to print along with the usage
# Returns: Nothing, exits script
###############################################################################
sub usage(;$) {
	my $message = shift;

	print "\n$message\n" if (defined($message));
	print "\nUsage: $0 [log_file] [output_file]\n";
	print "\t\tlog_file defaults to '$defaultLogFile'\n";
	print "\t\toutput_file defaults to '$defaultOutFile'\n";

	exit(1);
}
