#!/bin/bash
# name          : postfix_mail_test
# desciption    : postfix testmail script
# autor         : speefak ( itoss@gmx.de )
# licence       : (CC) BY-NC-SA
# version 	: 0.3
# notice 	:
# infosource	: 
#
#------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

 DefaultMailAddress="foo@bar.com"
 SystemUsers="$USER root fail2ban www-data"
 PostfixLogFile="/var/log/mail.log" #daemon.log"

 RequiredPackets="bash sed awk mail "
 Date=$(date "+%F %H:%M:%S")
 HostIP=$(hostname -I | tr " " "\n" | sort -u | sed '/^$/d')

 Version=$(cat $(readlink -f $(which $0)) | grep "# version" | head -n1 | awk -F ":" '{print $2}' | sed 's/ //g')
 ScriptFile=$(readlink -f $(which $0))
 ScriptName=$(basename $ScriptFile)

#------------------------------------------------------------------------------------------------------------
############################################################################################################
###########################################   define functions   ###########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------
load_color_codes () {
	# parse required colours for echo/printf usage: printf "%s\n" "Text in ${Red}red${Reset}, white and ${Blue}blue${Reset}."
	Black='\033[0;30m'	&&	DGray='\033[1;30m'
	LRed='\033[0;31m'	&&	Red='\033[1;31m'
	LGreen='\033[0;32m'	&&	Green='\033[1;32m'
	LYellow='\033[0;33m'	&&	Yellow='\033[1;33m'
	LBlue='\033[0;34m'	&&	Blue='\033[1;34m'
	LPurple='\033[0;35m'	&&	Purple='\033[1;35m'
	LCyan='\033[0;36m'	&&	Cyan='\033[1;36m'
	LLGrey='\033[0;37m'	&&	White='\033[1;37m'
	Reset='\033[0m'

	BG='\033[47m'
	FG='\033[0;30m'

	# parse required colours for sed usage: sed 's/status=sent/'${Green}'status=sent'${Reset}'/g' |\
	if [[ $1 == sed ]]; then
		for ColorCode in $(cat $0 | sed -n '/^load_color_codes/,/FG/p' | tr "&" "\n" | grep "='"); do
			eval $(sed 's|\\|\\\\|g' <<< $ColorCode)						# sed parser '\033[1;31m' => '\\033[1;31m'
		done
	fi
}
#------------------------------------------------------------------------------------------------------------
usage() {
	printf "\n"
	printf " Usage: $(basename $0) <options> "
	printf "\n\n"
	printf " default		=> check default address list ($SystemUsers)\n"
	printf " <foo@bar.com>		=> check entered mail address\n"
	printf " -h			=> help dialog \n"
	printf " -m			=> monochrome output \n"
	printf " -i			=> show script information \n"
	printf " -cfrp			=> check for required packets \n"
	printf "\n"
	printf  "\n${LRed} $1 ${Reset}\n"
	printf "\n"
	exit
}
#------------------------------------------------------------------------------------------------------------
script_information () {
	printf "\n"
	printf " Scriptname: $ScriptName\n"
	printf " Version:    $Version \n"
	printf " Location:   $(pwd)/$ScriptName\n"
	printf " Filesize:   $(ls -lh $0 | cut -d " " -f5)\n"
	printf "\n"
	exit 0
}
#------------------------------------------------------------------------------------------------------------
check_for_required_packages () {

	InstalledPacketList=$(dpkg -l | grep ii)

	for Packet in $RequiredPackets ; do
		if [[ -z $(grep -w $Packet <<< $InstalledPacketList) ]]; then
			MissingPackets="$MissingPackets $Packet"
   		fi
	done

	# print status message / install dialog
	if [[ -n $MissingPackets ]]; then
		printf  "missing packets: ${LRed}  $MissingPackets ${Reset} \n"
		read -e -p "install required packets ? (Y/N) "	-i "Y" 	InstallMissingPackets
		if   [[ $InstallMissingPackets == [Yy] ]]; then

			# install software packets
			sudo apt update
			sudo apt install -y $MissingPackets
			if [[ ! $? == 0 ]]; then
				exit
			fi
		else
			printf  "programm error: ${LRed} missing packets : $MissingPackets ${Reset} \n"
			exit 1
		fi

	else
		printf "${LGreen} all required packets detected ${Reset}\n"
	fi
}
#------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   start script   #############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

	# check help dialog
	if [[ $1 == -[hH] ]]; then usage "usage $0 <user@domain>" ; fi

#------------------------------------------------------------------------------------------------------------

	# check for script information
	if [[ -n $(grep -w "\-i" <<< $@ ) ]]; then script_information ; fi

#------------------------------------------------------------------------------------------------------------

	# check for cronjob execution and cronjob options
	CronExecution=
	if [ -z $(grep "/" <<< "$(tty)") ]; then
		CronExecution=true
		Monochrome=true
	fi

#------------------------------------------------------------------------------------------------------------

	# check for monochrome output
	Reset='\033[0m'
	if [[ -z $Monochrome ]]; then
		load_color_codes
	fi

#------------------------------------------------------------------------------------------------------------

	# check for required packages
	if [[ -n $(grep -w "\-cfrp" <<< $@ ) ]]; then 

		# check for root permission
		if [ "$(whoami)" = "root" ]; then echo "";else echo "Are You Root ?";exit 1;fi

		# check for packages
		check_for_required_packages

		exit 0
	fi

#------------------------------------------------------------------------------------------------------------

	# override default vars for mail address input
	if [[ -n $@ ]] ;then
		DefaultMailAddress=
		SystemUsers=
	fi

#------------------------------------------------------------------------------------------------------------

	# send mail for various systemusers
	for Mailaddress in $( echo "$DefaultMailAddress $SystemUsers $@" | tr " " "\n" | sort -u ) ; do

		# disable dialog for first run
		if [[ $FirstRun == false ]]; then			
			printf "\n"
			read -n 1 -p " press any key for next mailaddress test ( $Mailaddress ) / press c to cancel testing" Exit
			printf "\n\n"
			if [[ $Exit == [cC] ]] ;
				then break
			fi			
		fi
		FirstRun=false

		# create mail content
		if [[ "$Mailaddress" == "$DefaultMailAddress" ]] ; then
			SubjectLine="Testmail from $(hostname) | $Date | address: $Mailaddress"
		else
			SubjectLine="Testmail from $(hostname) | $Date | systemuser: $Mailaddress"
		fi
		MailBody="This is a test mail from $(hostname) ($HostIP) | $Date"

		# send mail via postfix
		printf "\n sending mail via postfix: $Mailaddress\n\n"
		echo "$MailBody" | mail -s "$SubjectLine" "$Mailaddress"

		# wait for log entry
		sleep 1

		# get postfix mail/proccess ID
		#PostfixMailID=$(sudo journalctl --since "2 minutes ago" | grep postfix | tail -n 10  | grep $Mailaddress | awk -F "]: " '{print $2}' | cut -d ":" -f1 | tail -n1)
		PostfixMailID=$(cat $PostfixLogFile | grep postfix 2>/dev/null | tail -n 10  | grep $Mailaddress | awk -F "]: " '{print $2}' | cut -d ":" -f1 | tail -n1)

		# get values from logfile
		LogContent=$(sudo cat $PostfixLogFile | grep $PostfixMailID 2>/dev/null)
		MailFromSystemuser=$(echo "$LogContent" | grep -m1 " from=" 2>/dev/null | awk -F " from=<" '{printf $2}' | cut -d ">" -f1)
		MailFromAddress=$(echo "$LogContent" | head -n3 | tail -n1 | grep -m1 " from=" 2>/dev/null | awk -F " from=<" '{printf $2}' | cut -d ">" -f1)
		MailToAddress=$(echo "$LogContent" | grep -m1 " to=<" 2>/dev/null | awk -F " to=<" '{printf $2}' | cut -d ">" -f1)

		# check for log entry
		if [[ -z $PostfixMailID ]]; then
			MissingMailAddress=$(echo "$MissingMailAddress" "$PostfixMailID")
			printf " mail ID for ${Red}$Mailaddress${Reset} in $PostfixLogFile not found \n\n"
			continue
		fi

		# parse colored output
		load_color_codes sed
		printf "$(echo "$LogContent" |\
			sed 's/status=sent/'${Green}'status=sent'${Reset}'/g' |\
			sed 's/status=bounced/'${Red}'status=bounced'${Reset}'/g' )\n\n"

		# printf status message
		load_color_codes
		printf " from:   $MailFromAddress ($MailFromSystemuser)\n"	#TODO doesn work corectly
		printf " to:     $MailToAddress\n"	#TODO doesn work corectly

		if [[ -n $(grep "$status=sent" <<< "$LogContent") ]]; then
			printf " status: ${Green}sent${Reset}\n"			
		else
		#elif [[ -n $(grep "$status=sent" <<< "$LogContent") ]]; then
			printf " mailstatus => ${Red}ERROR${Reset}\n"			
		fi
	done


#------------------------------------------------------------------------------------------------------------

 exit 0

