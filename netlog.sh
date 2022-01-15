#!/bin/bash
############################################################
#  This script will automate the process of                #
#  Logging Calls on a Pi-Star Hotpot			   #
#  to assist with Net Logging                              #
#                                                          #
#  VE3RD                              Created 2021/07/05   #
############################################################
#set -o errexit 
#set -o pipefail 
set -eu 
#set -o errtrace
#set -E -o functrace

ver=2021123001

sudo mount -o remount,rw / 
#printf '\e[9;1t'

callstat="" 
callinfo="No Info" 
lastcall2="" 
lastcall1=""
netcont="none"
stat=""

#P1="$1"

#if [ ! -z "$P1" ]; then
#	netcont=$(echo "$P1" | tr '[:lower:]' '[:upper:]')
#fi
#if [ "$2" ]; then
#	P2="$2" 
#	P2S=${P2^^} 
#	stat=${P2^^}
#fi
#if [ "$3" ]; then
#	P3="$3" 
#	P3S=${P3^^} 
#fi
TG=""
#echo "$netcont"   "$stat" 
dur=$((0)) 
cnt=$((0)) 
lcnt=$((0)) 
cntd=0
cm=0 
lcm=0 
ber=0 
netcontdone=0 
nodupes=0 
rf=0 
clen=$((0))
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
call=""
line2=""
yat=""
keybd="no"
amode="no"
stripped=0

err_report() 
{ 
	echo "Error on line $1"
	echo "Last  Call = $call" 
	echo "Last TCall = $tcall" 
	./netlog.sh ReStart
}

trap 'err_report $LINENO' ERR


fnEXIT() {

  echo -e "${BOLD}${WHI}THANK YOU FOR USING NETLOG by VE3RD!${SGR0}${DEF}"
echo ""
  exit
  
}

trap fnEXIT SIGINT SIGTERM

function getinput()
{
	calli=" "
	echo -n "Type a Call Sign and press enter: ";
	read calli
	call=${calli^^} 
	echo ""
	stty sane
	cm=2
	keybd="yes"
	ProcessNewCall
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
	echo "0, Net Log Started $dates" | tee /home/pi-star/netlog.log > /dev/null
#	echo "0, Net Log Started $dates" > /home/pi-star/netlog.log
	echo "0" | tee ./count.val > /dev/null
	echo ""
	if [ ! "$netcont" ] || [ "$netcont" == "NEW" ]; then
		echo "No Net Controller Specified"
		netcont="N/A"
	else
		echo "Net Controller is $netcont"
		echo ""
	fi
}
#M: 2021-12-29 14:55:46.923 YSF, received network data from WB2FLX     to DG-ID 0 at FCS00390
function getysf(){
	ysfm=$(sed -n -r "/^\[Network\]/ { :l /^Startup[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/ysfgateway)
	server="$ysfm"
	tg=$(echo "$nline1" | cut -d " " -f 14)
	if [ "$ysfm" == "YSF2P25" ]; then
		server="YSF2P25"
		tg=$(sed -n -r "/^\[Network\]/ { :l /^Static[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/p25gateway)
	fi
}
function getnxdn(){
	nxdn=$(sed -n -r "/^\[Network\]/ { :l /^Startup[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/nxdngateway)
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
		
sudo mount -o remount,rw / 
echo "Get Server Data " >> /home/pi-star/netlog_debug.txt

}

function getuserinfo(){
stripped=0
	if [ "$cm" != 6 ] && [ ! -z  "$call" ] && [ "$call" != "to" ]; then
		call=$(echo "$call" | cut -d "/" -f 1)
		call=$(echo "$call" | cut -d "-" -f 1)
if [ $call ]; then
 		lines=$(sed -n '/'",$call"',/p' /usr/local/etc/stripped.csv | head -n 1)	
		
		if [ -z "$lines"  ]; then
	 		lines=$(sed -n '/'",$call"',/p' /usr/local/etc/stripped2.csv | head -n 1)	
		else
			stripped=1
		fi 
		if [ "$lines"  ]; then
			stripped=2
		fi
		line=$(echo "$lines" | head -n1)

		if [ ! -z line ] || [ stripped == 0 ]; then
			name=$(echo "$line" | cut -d "," -f 3 | cut -d " " -f 1)
#			name=$(echo "$line" | cut -d "," -f 3 )
			city=$(echo "$line"| cut -d "," -f 5)
			state=$(echo "$line" | cut -d "," -f 6)
			country=$(echo "$line" | cut -d "," -f 7)
		else
			callinfo="No Info"
			name="NA"
			city="NA"
			state="NA"
			country="NA"
		fi
	fi
fi
echo "End Get User Info " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
}

function checkcall(){ 
		if [ "$cm" != 6 ] && [ "$call" != "to" ]; then 
			logline=$(sed -n '/'"$call"',/p' /home/pi-star/netlog.log | head -n 1) 
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
	echo "$cnt, $mode, $Time, $call, $name, $city, $state, $country, $dur sec $server $tg " | tee -a /home/pi-star/netlog.log > /dev/null
	echo "$cnt" | tee ./count.val > /dev/null
}
function LogDup(){ 
	sudo mount -o remount,rw /
	## Write Duplicate Call to Log File
	echo " -- Dup $cntd, $mode, $Time, $call, $name, $city, $state, $country, $dur sec $server $tg " >> /home/pi-star/netlog.log 
}



function ProcessNewCall(){ 

RED="\e[31m"
GREEN="\e[32m"
LTMAG="\e[95m"
LTGREEN="\e[92m"
LTCYAN="\e[96m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"


#echo "Processing Call:$call Mode:$pmode"

if [ -z "$call" ]; then
   call="VE3ZRD"
fi
if [ "$keybd" == "yes" ]; then
	pmode="DMRT"    
  	keybd="no"
fi
echo "ProcessNewCall 1 $call " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
	getuserinfo 
	checkcall 
#	getserver 

	if [ "$mode" == "DMR" ]; then
		getserver
        fi

	if [ "$pmode" == "YSFA" ]; then
		getysf
		tg="$yat"
        fi

	if [ "$pmode" == "NXDNA" ]; then
		getnxdn
        fi

#echo "Process Mode - $pmode : Call:$call" >> /home/pi-star/netlog_debug.txt

sudo mount -o remount,rw / 

echo "ProcessNewCall - got mode info " | tee -a /home/pi-star/netlog_debug.txt > /dev/null

#	if [[ $nline1 =~ "header" ]]; then
	if [ "$pmode" == "DMRA" ] || [ "$pmode" == "YSFA" ] || [ "$pmode" == "P25A" ] || [ "$pmode" == "NXDNA" ]; then
                fdate=$(echo "$nline1" | cut -d " " -f2)
		amode="yes"

textstr=$(echo -en " ${YELLOW}   Active $mode QSO $Time from $call $name, $state, $country, $server : $tg ${ENDCOLOR}")
echo "$textstr"

echo -en "\033[1A\033"
sudo mount -o remount,rw / 

echo "ProcessNewCall echo Active QSO $pmode" | tee -a /home/pi-star/netlog_debug.txt > /dev/null
	fi

   	if [  "$pmode" == "DMRT" ] || [ "$pmode" == "YSFT" ] || [ "$pmode" == "P25T" ]  || [ "$pmode" == "NXDNT" ]; then
		amode="no"
sudo mount -o remount,rw / 

echo "ProcessNewCall Last Heard $pmode" | tee -a /home/pi-star/netlog_debug.txt > /dev/null
		if [ "$call" == "$netcont" ]; then
			sudo mount -o remount,rw /

			if [ "$rf" == 1 ]; then
				printf " ${LTMAG}-------------------- $mode $Time  Net Control $netcont $name BER:$ber  $tg,   $server ${ENDCOLOR}\n"
			else
				printf " ${LTMAG}-------------------- $mode $Time  Net Control $netcont $name, $city, $state, $country, $durt sec,  $tg,   $server ${ENDCOLOR}\n"
			fi	
			printf "--------------------- $mode $Time  Net Control $netcont $name, $city, $state, $country, $durt sec  \n" | tee -a  /home/pi-star/netlog.log > /dev/null

#			printf '\e[0m'
sudo mount -o remount,rw / 

echo "ProcessNewCall echo net control " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
		fi

		if [ "$call" != "$netcont" ]; then
			lastcall1=""
			call1=""
			netcontdone=0
#			lastcall1=""
#			if [ "$lastcall2" != "$call" ]; then
			#	dur=$(printf "%1.0f\n" $durt)
				if [ $dur -lt 2 ]; then

					if [ "$callstat" == "New" ]; then
						cnt=$((cnt+1))
printf "${LTCYAN} %-3s $mode New KeyUp %-8s -- %-6s %s, %s, %s, %s, %s, %s, TG:%s  %s ${ENDCOLOR} \n" "$cnt" "$Time" "$call" "$name" "$city" "$state" "$country" " Dur: $durt sec"  "PL: $pl" "$server" "$tg "
#						printf '\e[0m'
						Logit
sudo mount -o remount,rw / 

echo "ProcessNewCall Loged New Key Up" | tee -a /home/pi-star/netlog_debug.txt > /dev/null
					fi
				
					if [ "$callstat" == "Dup" ] && [ "$nodupes" == 0 ]; then
#						printf '\e[0;46m'
#						printf '\e[0;33m'


						cnt2ds=$(sed -n '/'"$call"'/p' /home/pi-star/netlog.log)
						if [ $? != 0 ]; then
 			 				echo "Sed Error on Line $LINENO"
						fi
						cnt2d=$(echo "$cnt2ds" | cut -d "," -f 1)

#printf "${LTGREEN}%3s SKU Dup $mode"
#printf " %4s %-8s %-6s " "$cnt2d" "$Time" "$call" 
#printf " %s, %s, %s, %s" "$name" "$city" "$state" "$country"
#printf " Dur:%s, Pl:%s, Svr:%s, TG:%s ${ENDCOLOR}\n" "$durt" "$pl" "$server" "$tg"

sudo mount -o remount,rw / 
LogDup

echo "ProcessNewCall Keyup Dupe " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
					fi

				#		echo "Dupe Callstat = $callstat $dur"
				else  # Real Call

					if [ "$callstat" == "New" ]; then
##						echo " Write New Call to Screen"
						cnt=$((cnt+1))
#						printf '\e[0;40m'
#						printf '\e[1;36m'

					    	if [ "$kbd" == true ]; then
printf "${LTCYAN} %-3s $mode New Call  %-8s -- %-6s %s, %s, %s, %s, %s  KeyBd, TG:%s %s ${ENDCOLOR}\n" "$cnt" "$Time" "$call" "$name" "$city" "$state" "$country" "$server" "$tg "	
					    	else
printf "${LTCYAN} %-3s $mode New Call  %-8s -- %-6s %s, %s, %s, %s,  Dur:%s Secs, PL:%s, TG:%s %s${ENDCOLOR}\n" "$cnt" "$Time" "$call" "$name" "$city" "$state" "$country" "$durt"  "$pl" "$server" "$tg "	
					    	
						fi
						Logit
sudo mount -o remount,rw / 

echo "ProcessNewCall Logged New Call " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
					fi

					if [ "$callstat" == "Dup" ] && [ "$nodupes" == 0 ]; then
							## Write Duplicate Info to Screen

				    		if [ "$kbd" == true ]; then
		#
printf "${LTGREEN}$mode KBd Dup %4s %-8s %-6s %s,%s, %s, %s %s %s${ENDCOLOR}\n" "$cnt2d" "$Time" "$call" "$name" "$city" "$state" "$country" "$server" "$tg"	
#printf "%s, %s, %s %s %s\n" "$city" "$state" "$country" "$server" "$tg"	
					    	else
printf "${LTGREEN}$mode Net Dup  %4s %-8s %-6s %s, %s, %s, %s, %s, %s %s %s${ENDCOLOR} \n" "$cnt2d" "$Time" "$call" "$name" "$city" "$state" "$country" " Dur: $durt sec"  "PL: $pl" "$server" "$tg"	
#printf "   %s, %s, %s %s %s \n" "$country" " Dur: $durt sec"  "PL: $pl" "$server" "$tg"	
					    	fi
#							printf '\e[0m'
#						fi
sudo mount -o remount,rw / 
LogDup
echo "ProcessNewCall echo Duplicate Call " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
					fi
printf "${ENDCOLOR}"
			
				fi  # end of keyup loop
		fi  #end of not netcont loop

		if [ active == 1 ]; then
			active=0
		fi
		lcm=0
	fi
sudo mount -o remount,rw / 

echo "ProcessNewCall End of Regular Data " | tee -a /home/pi-star/netlog_debug.txt > /dev/null

#Watchdog loop
	if [ "$pmode" == "Watchdog" ]; then
sudo mount -o remount,rw / 

echo "ProcessNewCall Processing Watchdog Line " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
#		printf '\e[0;40m'
#		printf '\e[1;31m'
#		checkcall
		if [ "$callstat" == "New" ]; then
			cnt=$((cnt+1))
			printf " ${LTCYAN} New %s %-15s - $mode Network Watchdog Timer has Expired for %-6s %s, %s, %s, %s, %s${ENDCOLOR}\n" "$cnt" "$Time" "$call" "$name" "Dur: $durt sec"  "PL: $pl"	
			Logit
		fi 
		if [ "$callstat" == "Dup" ]; then
			printf "${LTGREEN} Dup %s  %-15s - $mode Network Watchdog Timer has Expired for %-6s %s, %s, %s, %s, %s${ENDCOLOR}\n" "$cnt2d" "$Time" "$call" "$name" "Dur: $durt sec"  "PL: $pl"	
		fi	
	fi
sudo mount -o remount,rw / 

echo "ProcessNewCall End " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
#echo "ProcessNewCall End " 
	
}

function ParseLine(){
#	echo "Last Line : $nline1"
	tg=""
echo "ParseLine getting date/time " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
	fdate=$(echo "$nline1" | cut -d " " -f2 )    #| sed 's/ *$//g' 
	ftime=$(echo "$nline1" | cut -d " " -f3 )
#	mode=$(echo "$nline1" | cut -d " " -f 4 |  sed 's/,//g')

	if [ "$mode" == "DMR" ] || [ "$mode" == "YSF" ] || [ "$mode" == "P25" ] || [ "$mode" == "NXDN" ]; then
		if [[ "$nline1" =~ "from" ]]; then
echo "ParseLine $mode $pmode" | tee -a /home/pi-star/netlog_debug.txt > /dev/null

			if [ "$mode" == "DMR" ]; then 
				if [[ "$nline1" =~ "header" ]] || [[ "$nline1" =~ "late entry" ]]; then
#					call=$(echo "$nline1" | cut -d" " -f 12)
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
echo "ParseLine Mode DMR " | tee -a /home/pi-star/netlog_debug.txt > /dev/null

			fi
			if [ "$mode" == "YSF" ]; then 
				if [[ "$nline1" =~ "header from" ]] || [[ "$nline1" =~ "data from" ]]; then
#					call=$(echo "$nline1" | cut -d " " -f 9 | cut -d "/" -f 1)
					name=$(echo "$nline1" | cut -d " " -f 9 | cut -d "/" -f 2)
			#		echo "Call=$call"
					yat=$(echo "$nline1" | cut -d " " -f 14)
					tg="$yat"
					server=""
					pmode="YSFA"
				fi

				if [[ "$nline1" =~ "end of transmission" ]]; then
#					call=$(echo "$nline1" | cut -d " " -f 11)
					ber=$(echo "$nline1" | cut -d " " -f 18)
				#	pl=$(echo "$nline1" | cut -d " " -f 17)
					durt=$(echo "$nline1" | cut -d " " -f 15)
					dur=$(printf "%1.0f\n" $durt)
					pmode="YSFT"
				fi

				if [[ "$nline1" =~ "transmission lost" ]]; then
#					call=$(echo "$nline1" | cut -d " " -f 8)
					ber=$(echo "$nline1" | cut -d " " -f 15)
					durt=$(echo "$nline1" | cut -d " " -f 11)
					dur=$(printf "%1.0f\n" $durt)
					pmode="YSFW"
				fi
echo "ParseLine mode YSF " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
			fi


			if [ "$mode" == "P25" ]; then 

				if [[ "$nline1" =~ "received network" ]]; then
					call=$(echo "$nline1" | cut -d " " -f 9)
					tg=$(echo "$nline1" | cut -d " " -f 12)
					pmode="P25A"
				fi
				if [[ "$nline1" =~ "end of transmission" ]]; then
					call=$(echo "$nline1" | cut -d " " -f 10)
					tg=$(echo "$nline1" | cut -d " " -f 13)
					pl=$(echo "$nline1" | cut -d " " -f 16)
					ber=$(echo "$nline1" | cut -d " " -f 23)
					durt=$(echo "$nline1" | cut -d " " -f 14)
					dur=$(printf "%1.0f\n" $durt)
					pmode="P25T"
				fi

echo "ParseLine mode P25 " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
			fi


			if [ "$mode" == "NXDN" ]; then 
				if [[ "$nline1" =~ "network transmission" ]]; then
					call=$(echo "$nline1" | cut -d " " -f 9)
					tg=$(echo "$nline1" | cut -d " " -f 12)
					pmode="NXDNA"
				fi
				if [[ "$nline1" =~ "end of transmission" ]]; then
					call=$(echo "$nline1" | cut -d " " -f 11)
					tg=$(echo "$nline1" | cut -d " " -f 14)
					durt=$(echo "$nline1" | cut -d " " -f 15)
					dur=$(printf "%1.0f\n" $durt)
					pmode="NXDNT"
				fi
echo "ParseLine mode NXDN " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
			fi
		fi
		if [[ "$nline1" =~ "watchdog" ]] && [ "$mode" == "YSF" ]; then
					pl=$(echo "$nline1" | cut -d " " -f 11)
					ber=$(echo "$nline1" | cut -d " " -f 15)
					durt=$(echo "$nline1" | cut -d " " -f 9)
					dur=$(printf "%1.0f\n" $durt)
					pmode="Watchdog"
		fi
		if [[ "$nline1" =~ "watchdog" ]] && [ "$mode" == "P25" ]; then
					pl=$(echo "$nline1" | cut -d " " -f 11)
					ber="0"
					durt=$(echo "$nline1" | cut -d " " -f 9)
					dur=$(printf "%1.0f\n" $durt)
					pmode="Watchdog"
		fi

#M: 2022-01-04 13:34:41.991 DMR Slot 2, network watchdog has expired, 24.1 seconds, 38% packet loss, BER: 0.0%

		if [[ "$nline1" =~ "watchdog" ]] && [ "$mode" == "DMR" ]; then
					pl=$(echo "$nline1" | cut -d" " -f 13)
					pmode="DMRW"
					durt=$(echo "$nline1" | cut -d" " -f 11)
					dur=$(printf "%1.0f\n" $durt)
					cnt=$((cnt+1))
					pmode="Watchdog"
  		fi
	fi
echo "ParseLine End Function " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
   
}

function GetLastLine(){
	ok=false
        f1=$(ls -tv /var/log/pi-star/MMDVM* | tail -n 1 )
        line1=$(tail -n 1 "$f1" | tr -s \ |  sed -n -e 's/^.*to //p')
#	nline1=$(tail -n 1 "$f1" | tr -s \ |  sed 's/ *$//g' | sed 's/%//g' | sed 's/,//g' )
	nline1=$(tail -n 1 "$f1" | tr -s \ )
	tcall=$(echo "$nline1" |  grep -oP '(?<=from )\w+(?= to)' | tr "/" " " | tr "-" " ")
	if [[ "$nline1" =~ "from" ]]; then
		ok=true
	fi
        newline="$nline1"
#echo "$oldline"
#echo "$newline"
        mode=$(echo "$nline1" | cut -d " " -f 4 |  sed 's/-ND//' | sed 's/,//g' )

        if [ "$oldline" != "$newline" ] && [ "$ok" == true ]; then
#      tail -n 1 "$f1" | tr -s \ | cut -d " " -f2
#      tail -n 1 "$f1" | tr -s \ | cut -d " " -f3
		dt=$(date --rfc-3339=ns)

		sudo mount -o remount,rw / 

		 echo "GetLastLine - Got New Line $dt" | tee /home/pi-star/netlog_debug.txt > /dev/null
#      tail -n 1 "$f1" | tr -s \ | cut -d " " -f2
#      tail -n 1 "$f1" | tr -s \ | cut -d " " -f3

	          if [ "$mode" == "DMR" ] || [ "$mode" == "YSF" ] || [ "$mode" == "P25" ] || [ "$mode" == "NXDN" ]; then

	#		tcall=$(echo "$nline1" |  grep -oP '(?<=from )\w+(?= to)')
 
			 clen=$(echo $tcall | wc -c)
			if [ ! -z "$tcall" ] && [ "$clen" -ge 4 ] && [ "$clen" -le 7 ]; then
				call="$tcall"

#echo "Mode3:|$mode|    Call:$tcall"
#echo "$nline1"
				ParseLine
                        	ProcessNewCall
			fi
                fi
		dt=$(date --rfc-3339=ns)
#echo "Get dt"
		echo "End of GetLastLine Loop  $dt "| tee -a /home/pi-star/netlog_debug.txt > /dev/null
#echo "Get 11"
	
#		echo "echo 1 > /proc/sys/vm/drop_caches" > /dev/null

        oldline="$newline"
#	echo "End of Loop: wait for next line"
        fi

}

function StartUp()
{
        f1=$(ls -tv /var/log/pi-star/MMDVM* | tail -n 1 )
#        line1=$(tail -n 1 "$f1" | tr -s \ |  sed -n -e 's/^.*to //p')
	nline1=$(tail -n 1 "$f1" | tr -s \ |  sed 's/ *$//g' | sed 's/%//g' | sed 's/,//g' )   #sed 's/h//g'
        newline="$nline1"
	oldline="$nline1"

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

		cntt=$(cat ./count.val)
                cnt=$((cntt))

                        echo "Restart Program Ver:$ver - Counter = $cnt"
                      #  cat /home/pi-star/netlog.log 
			grep -v '^ --' /home/pi-star/netlog.log
   #             fi

		
	fi

fi
}

######## Start of Main Program
###LoopKeys

StartUp

#getnewcall
callstat=""

######### Main Loop Starts Here
#echo "Starting Loop"

while true
do 
kbd=false
	cm=0	
 	Time=$(date '+%T')  
	GetLastLine


#	sync
#	sleep 1.0

	while read -t1  
  	do 
		kbd=true
		getinput
	done
done
echo "No Longer True"
