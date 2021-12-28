#!/bin/bash
############################################################
#  This script will automate the process of                #
#  Logging Calls on a Pi-Star Hotpot			   #
#  to assist with Net Logging                              #
#                                                          #
#  VE3RD                              Created 2021/07/05   #
############################################################
set -o errexit 
set -o pipefail 
set -e 
set -o errtrace
set -E -o functrace

ver=2021122701

sudo mount -o remount,rw / 
printf '\e[9;1t'

callstat="" 
callinfo="No Info" 
lastcall2="" 
lastcall1=""
netcont="none"
if [ "$1" ]; then
	P1="$1" 
	P1S=${P1^^} 
	netcont=${P1^^} 
fi
if [ "$2" ]; then
	P2="$2" 
	P2S=${P2^^} 
	stat=${P2^^}
fi
if [ "$3" ]; then
	P3="$3" 
	P3S=${P3^^} 
fi
TG=""
#echo "$netcont"   "$stat" 
dur=$((0)) 
cnt=$((0)) 
lcnt=$((0)) 
cm=0 
lcm=0 
ber=0 
netcontdone=0 
nodupes=0 
rf=0 
lfdts="" 
dts="" 
nline1=""
calli=""
src="RF"  #"NET"
active=0
sline="                                                                                                                       "
oldline=""
newline=""
pmode=""
mode=""
server=""

err_report() { echo "Error on line $1 for call: $call" ./netlog.sh ReStart
}

trap 'err_report $LINENO' ERR


fnEXIT() {

 tput cuu1
 tput el
 tput el1 
  echo -e "${BOLD}${WHI}THANK YOU FOR USING NETLOG by VE3RD!${SGR0}${DEF}"
echo ""
  exit
  
}

trap fnEXIT SIGINT SIGTERM


function getinput()
{
	tput el
	tput el1
	calli=" "
	echo -n "Type a Call Sign and press enter: ";
	read calli
	call=${calli^^} 
	echo ""
	tput cuu 2
	stty sane
	cm=2
	ProcessNewCall K
}


function help(){
	#echo "Syntax : \./netlog.sh Param1 Param2 Param3"
	echo "All Parameters are optional"
	echo "Param1 can be  any one of three things "
	echo "1) Net Controller Call Sign.  If used This must be Param 1"
	echo "2) The word 'NEW' This will initalize the Log File"
	echo "3) The word 'NODUPES' This will stop the display from showing Dupes"
	echo "Param 2 and 3 may be any cobination of items 2 and 3 above"
echo ""
	echo "You can manually enter a call sign."
	echo "1) Press ENTER"
	echo "2) Enter a Call Sign"
	echo "3) Press ENTEE"
}


function header(){
	clear
	set -e sudo mount -o remount,rw / 
	echo ""
	echo "NET Logging Program by VE3RD Version $ver"
#	echo ""
	echo "Dates and Times Shown are Local to your hotspot"
#	echo ""
	echo "Net Log Started $dates"
	echo "000, Net Log Started $dates" > /home/pi-star/netlog.log
	echo ""

	if [ ! "$netcont" ] || [ "$netcont" == "NEW" ]; then
		echo "No Net Controller Specified"
		netcont="N/A"
	else
		echo "Net Controller is $netcont"
		echo ""
	fi
}

function getysf(){
	ysfm=$(sed -n -r "/^\[Network\]/ { :l /^Startup[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/ysfgateway)
	if [ "$ysfm" == "YSF2P25" ]; then
		server="YSF2P25"
		tg=$(sed -n -r "/^\[Network\]/ { :l /^Static[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/p25gateway)
	fi
}

function getserver(){
	Addr=$(sed -n -r "/^\[DMR Network\]/ { :l /^Address[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/mmdvmhost)
	DMRen=$(sed -n -r "/^\[DMR\]/ { :l /^Enabled[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/mmdvmhost)

	if [ $Addr = "127.0.0.1" ] && [ "$DMRen" = "1" ]; then
		fg=$(ls /var/log/pi-star/DMRGateway* | tail -n1)
		NetNum=$(tail -n1 "$fg" | cut -d " " -f 6)
		server=$(sed -n -r "/^\[DMR Network "${NetNum##*( )}"\]/ { :l /^Name[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/dmrgateway)
         else	
		ms=$(sudo sed -n '/^[^#]*'"$Addr"'/p' /usr/local/etc/DMR_Hosts.txt | head -n1 | sed -E "s/[[:space:]]+/|/g" | cut -d'|' -f1)
 		server=$(echo "$ms" | cut -d " " -f1)
	fi
}

function getuserinfo(){
	if [ "$cm" != 6 ] && [ ! -z  "$call" ]; then
 		lines=$(sed -n '/'",$call"',/p' /usr/local/etc/stripped.csv)	
		if [ $? != 0 ]; then
  			echo "Sed Error on Line $LINENO" 
		fi 
		line=$(echo "$lines" | head -n1)

		if [ line ]; then
			name=$(echo "$line" | cut -d "," -f 3 | cut -d " " -f 1)
#			name=$(echo "$line" | cut -d "," -f 3 )
			city=$(echo "$line"| cut -d "," -f 5)
			state=$(echo "$line" | cut -d "," -f 6)
			country=$(echo "$line" | cut -d "," -f 7)
		else
			callinfo="No Info"
			name=""
			city=""
			state=""
			country=""
		fi
	fi
}

function checkcall(){ 
		if [ "$cm" != 6 ]; then 
			logline=$(sed -n '/'"$call"',/p' /home/pi-star/netlog.log) 
			if [ $? != 0 ]; then
  				echo "Sed Error on Line $LINENO"
			fi
			
			if [ -z "$logline" ]; then 
     				callstat="New"
			else 
				callstat="Dup"
				cnt2da=$(echo "$logline" | cut -d "," -f 1) 
	
				cnt2d=$(printf "%1.0f\n" $cnt2da) 
	#			ck=$(echo "$logline" | cut -d "," -f 3) #call 
	#			ckt=$(echo "$logline" | cut -d "," -f 2) # time
			fi
		fi
}

function Logit(){ 
	sudo mount -o remount,rw /
	## Write New Call to Log File
	echo "$cnt, $mode $Time, $call, $name, $city, $state, $country, $dur sec $server $tg " >> /home/pi-star/netlog.log
}



function ProcessNewCall(){ 
#echo "Processing Call $call  Mode $pmode"
	getuserinfo 
	checkcall 
	getserver 
#	if [[ $nline1 =~ "header" ]]; then
	if [ "$pmode" == "DMRA" ] || [ "$pmode" == "YSFA" ] || [ "$pmode" == "P25A" ]; then
                fdate=$(echo "$nline1" | cut -d " " -f2)

                printf '\e[1;32m'

		echo -en "    Active $mode QSO from $call $name, $country, $tg,  $server\r"
 
	fi

	if [ "$pmode" == "DMRA" ]; then
		getserver
        fi

	if [ "$pmode" == "YSFA" ]; then
		getysf
        fi


   	if [  "$pmode" == "DMRT" ] || [ "$pmode" == "YSFT" ] || [ "$pmode" == "P25T" ]; then

		if [ "$call" == "$netcont" ]; then
			sudo mount -o remount,rw /

			tput rmam
			printf '\e[1;34m'		
			if [ "$rf" == 1 ]; then
				printf " -------------------- $mode $Time  Net Control $netcont $name BER:$ber  $tg,   $server\n"
			else
				printf " -------------------- $mode $Time  Net Control $netcont $name, $city, $state, $country, $durt sec,  $tg,   $server\n"
			fi	
			printf "00,--------------------- $mode $Time  Net Control $netcont $name, $city, $state, $country, $durt sec  \n" >> /home/pi-star/netlog.log

			printf '\e[0m'
		fi

		if [ "$call" != "$netcont" ]; then
			lastcall1=""
			call1=""
			netcontdone=0
			lastcall1=""
			if [ "$lastcall2" != "$call" ]; then
			#	dur=$(printf "%1.0f\n" $durt)
				if [ $dur -lt 2 ]; then

					if [ "$callstat" == "New" ]; then
						printf '\e[0;40m'
						printf '\e[1;36m'
						cnt=$((cnt+1))
#						if [ "$rf" == 1 ]; then
#printf "%-3s $mode New KeyUp %-8s -- %-6s %s, %s, %s, %s, %s, %s, TG:%s  %s\n" "$cnt" "$Time" "$call" "$name" "$city" "$state" "$country" "Dur: $durt sec"  "BER: $ber" "RF: " "$server" "$tg"		
#						else
printf "%-3s $mode New KeyUp %-8s -- %-6s %s, %s, %s, %s, %s, %s, TG:%s  %s\n" "$cnt" "$Time" "$call" "$name" "$city" "$state" "$country" " Dur: $durt sec"  "PL: $pl" "$server" "$tg"
#						fi
						printf '\e[0m'
						Logit
					fi
				
					if [ "$callstat" == "Dup" ] && [ "$nodupes" == 0 ]; then
						printf '\e[0;46m'
						printf '\e[0;33m'


						cnt2ds=$(sed -n '/'"$call"'/p' /home/pi-star/netlog.log)
						if [ $? != 0 ]; then
 			 				echo "Sed Error on Line $LINENO"
						fi
						cnt2d=$(echo "$cnt2ds" | head -n1 | cut -d "," -f 1)

#						if [ "$rf" == 1 ]; then
#printf "$mode KeyUp Dupe %-3s %-8s %-6s %s, %s, %s, %s, %s, %s\n" "$cnt2d" "$Time" "$call" "$name" "$city" "$state" "$country" "Dur:$durt sec"  "RF: BER:$ber" "$server" "$tg"	
#						else
printf "$mode KeyUp Dupe %-3s %-8s %-6s %s, %s, %s, %s, %s, %s\n" "$cnt2d" "$Time" "$call" "$name" "$city" "$state" "$country" " Dur:$durt sec" "PL:$pl" "$server" "$tg"	
#						fi	
						printf '\e[0m'
					fi

				#		echo "Dupe Callstat = $callstat $dur"
				else  # Real Call

					if [ "$callstat" == "New" ]; then
##						echo " Write New Call to Screen"
						cnt=$((cnt+1))
						printf '\e[0;40m'
						printf '\e[1;36m'
						if [ active == 1 ]; then
							tput cuu 1
						fi
#						tput el 1
#						tput el
#						tput rmam

						if [ "$rf" == 1 ]; then
printf "%-3s $mode New Call  %-8s -- %-6s %s, %s, %s, %s, $s  Dur:%s Secs, BER:%s RF: TG:%s %s\n" "$cnt" "$Time" "$call" "$name" "$city" "$state" "$country" "$durt"  "$ber" "$server" "$tg"	
						else
					    		if [ "$1" ]; then
				#				tput cuu 2
printf "%-3s $mode New Call  %-8s -- %-6s %s, %s, %s, %s, %s  KeyBd, TG:%s %s\n" "$cnt" "$Time" "$call" "$name" "$city" "$state" "$country" "$server" "$tg"	
					    		else
printf "%-3s $mode New Call  %-8s -- %-6s %s, %s, %s, %s,  Dur:%s Secs, PL:%s, TG:%s %s\n" "$cnt" "$Time" "$call" "$name" "$city" "$state" "$country" "$durt"  "$pl" "$server" "$tg"	
					    		fi
						fi
						printf '\e[0m'
				#		tput smam
						#lcm=0
						Logit
					fi

					if [ "$callstat" == "Dup" ] && [ "$nodupes" == 0 ]; then
							## Write Duplicate Info to Screen

						if [ active == 1 ]; then
							tput cuu 2
		#				echo "Dup cuu 2 active 1"
						fi
						tput el 1
						tput el
						printf '\e[0;46m'

						printf '\e[0;33m'
						tput rmam
						if [ "$rf" == 1 ]; then
							printf " $mode RF %-3s %-15s %-6s %s, %s, %s, %s, %s, %s\n" "$cnt2d" "$Time" "$call" "$name" "$city" "$state" "$country" " Dur: $durt sec"  "RF: BER: $ber"	
						else			
					    		if [ "$1" ]; then
		#						tput cuu 2
printf " KeyBd Dup %-3s %-8s %-6s %s,%s, %s, %s %s %s\n" "$cnt2d" "$Time" "$call" "$name" "$city" "$state" "$country" "$server" "$tg"	
#printf "%s, %s, %s %s %s\n" "$city" "$state" "$country" "$server" "$tg"	
					    		else
printf "  $mode Net Dupe %-3s %-8s %-6s %s, %s, %s, %s, %s, %s %s %s \n" "$cnt2d" "$Time" "$call" "$name" "$city" "$state" "$country" " Dur: $durt sec"  "PL: $pl" "$server" "$tg"	
#printf "   %s, %s, %s %s %s \n" "$country" " Dur: $durt sec"  "PL: $pl" "$server" "$tg"	
					    		fi
							printf '\e[0m'
						fi
						tput smam
						
					fi
			
				fi  # end of keyup loop
			fi   #end of lastcall2 loop
				lastcall2="$call"
		fi  #end of not netcont loop

		if [ active == 1 ]; then
			tput cuu 1
			active=0
		fi
		lcm=0
	fi

#Watchdog loop
	if [ "$pmode" == "Watchdog" ]; then
		printf '\e[0;40m'
		printf '\e[1;31m'
#		checkcall
		if [ "$callstat" == "New" ]; then
			cnt=$((cnt+1))
			printf "00 - %-15s - $mode Network Watchdog Timer has Expired for %-6s %s, %s, %s, %s, %s\n" "$Time" "$call" "$name" "Dur: $durt sec"  "PL: $pl"	
		fi	
		if [ "$callstat" == "Dup" ]; then
			printf "00 - New %-15s - $mode Network Watchdog Timer has Expired for %-6s %s, %s, %s, %s, %s\n" "$Time" "$call" "$name" "Dur: $durt sec"  "PL: $pl"	
		fi	
	fi
}

function ParseLine(){
#	echo "Last Line : $nline1"
	fdate=$(echo "$nline1" | cut -d " " -f2 |  sed 's/ *$//g')
	ftime=$(echo "$nline1" | cut -d " " -f3 |  sed 's/ *$//g')
	mode=$(echo "$nline1" | cut -d " " -f 4 | cut -c1-3)

	if [ "$mode" == "DMR" ] || [ "$mode" == "YSF" ] || [ "$mode" == "P25" ]; then
		if [[ "$nline1" =~ "from" ]]; then
			if [ "$mode" == "DMR" ]; then 
				getserver
				if [[ "$nline1" =~ "header" ]]; then
					call=$(echo "$nline1" | cut -d" " -f 12)
					tg=$(echo "$nline1" | cut -d" " -f 15)
					pmode="DMRA"
				fi
				if [[ "$nline1" =~ "transmission" ]]; then
					call=$(echo "$nline1" | cut -d" " -f 14)
					tg=$(echo "$nline1" | cut -d" " -f 17)
					pl=$(echo "$nline1" | cut -d" " -f 20)
					ber=$(echo "$nline1" | cut -d" " -f 24)
					durt=$(echo "$nline1" | cut -d" " -f 18)
					dur=$(printf "%1.0f\n" $durt)
					pmode="DMRT"
				fi
				if [[ "$nline1" =~ "watchdog" ]]; then
					pl=$(echo "$nline1" | cut -d" " -f 13)
					pmode="DMRW"
					durt=$(echo "$nline1" | cut -d" " -f 11)
					dur=$(printf "%1.0f\n" $durt)
					cnt=$((cnt+1))
					pmode="DMRW"
					cm=5
					Logit
  				fi
			fi
			if [ "$mode" == "YSF" ]; then 
				if [[ "$nline1" =~ "data from" ]]; then
					call=$(echo "$nline1" | cut -d " " -f 9)
			#		echo "Call=$call"
					tg="n/a"
					pmode="YSFA"
				fi

				if [[ "$nline1" =~ "end of transmission" ]]; then
					ber=$(echo "$nline1" | cut -d " " -f 21)
					pl=$(echo "$nline1" | cut -d " " -f 17)
					durt=$(echo "$nline1" | cut -d " " -f 15)
					dur=$(printf "%1.0f\n" $durt)
					pmode="YSFT"
				fi
				if [[ "$nline1" =~ "watchdog" ]]; then
					pl=$(echo "$nline1" | cut -d " " -f 11)
					ber=$(echo "$nline1" | cut -d " " -f 15)
					durt=$(echo "$nline1" | cut -d " " -f 9)
					dur=$(printf "%1.0f\n" $durt)
					pmode="Watchdog"
				fi
			fi
			if [ "$mode" == "P25" ]; then 
				if [[ "$nline1" =~ "received network" ]]; then
					call=$(echo "$nline1" | cut -d " " -f 9)
					tg=$(echo "$nline1" | cut -d " " -f 12)
					pmode="P25A"
				fi
				if [[ "$nline1" =~ "end of transmission" ]]; then
	#				call=$(echo "$nline1" | cut -d " " -f 10)
					tg=$(echo "$nline1" | cut -d " " -f 13)
					pl=$(echo "$nline1" | cut -d " " -f 16)
					ber=$(echo "$nline1" | cut -d " " -f 23)
					durt=$(echo "$nline1" | cut -d " " -f 14)
					dur=$(printf "%1.0f\n" $durt)
					pmode="P25T"
				fi
				if [[ "$nline1" =~ "watchdog" ]]; then
					pl=$(echo "$nline1" | cut -d " " -f 12)
					ber=$(echo "$nline1" | cut -d " " -f 16)
					durt=$(echo "$nline1" | cut -d " " -f 10)
					dur=$(printf "%1.0f\n" $durt)
					pmode="Watchdog"
				fi

			fi
		fi

	fi
}

function GetLastLine(){
        f1=$(ls -tv /var/log/pi-star/MMDVM* | tail -n 1 )
        nline1=$(tail -n 1 "$f1" | tr -s \ )
        newline="$nline1"
        mode=$(echo "$nline1" | cut -d " " -f 4 | cut -c1-3 )

        if [ "$oldline" != "$newline" ]; then
                if [ "$mode" == "DMR" ] || [ "$mode" == "YSF" ] || [ "$mode" == "P25" ]; then
                        ParseLine
                        ProcessNewCall
                fi
        fi
        oldline="$newline"
}

function StartUp()
{

if [ "$netcont" != "ReStart" ]; then

	if [ "$netcont" == "HELP" ]; then
		help
		exit
	fi

	if [ "$netcont" == "NEW" ] || [ "$stat" == "NEW" ] || [ ! -f /home/pi-star/netlog.log ]; then
		## Delete and start a new data file starting with date line
		dates=$(date '+%A %Y-%m-%d %T')

        	header 

	elif [ "$netcont" != "ReStart" ]; then
                lcnt=$( wc -l /home/pi-star/netlog.log | cut -d " " -f1 )

               if [[ lcnt -eq 1 ]]; then
			cnt=0
		fi
               if [[ lcnt -gt 1 ]]; then
                        cntt=$(grep "^[^00;]" /home/pi-star/netlog.log | tail -n 1 | cut -d "," -f 1)
                        cnt=$((cntt))

                        echo "Restart Program Ver:$ver - Counter = $cnt"
                        cat /home/pi-star/netlog.log
                fi
	fi
fi

}

######## Start of Main Program

StartUp
#getnewcall
callstat=""

######### Main Loop Starts Here
#echo "Starting Loop"

while true
do 
	cm=0	
 	Time=$(date '+%T')  
	GetLastLine

	sleep 1.0
while read -t1  
  do getinput
done


done

