#!/bin/bash

##
## Script name:  Get_Archived_Scripts.sh
## Author:       Aaron Stovall
## Date:  	 05/29/2019
##
## Description:  Checks for all Scripts that are associated with the "zArchived Scripts" Category
## 		 and will prompt to confirm deletion. 
##
## Dependencies: - API Account with permissions to read and delete scripts
##		 - A category called "zArchived Scripts" (This can be changed to any category of your choosing)
##		 - A Base64 Encrypted username:password (https://www.base64encode.org) 
##		   (Example: "jamfapiuser:MySuperSecretPassword" would be "amFtZmFwaXVzZXI6TXlTdXBlclNlY3JldFBhc3N3b3Jk")
##
## Notes: 	  It is strongly advised to TEST, TEST, TEST this against a sandbox environment!
##		  This script is provided AS-IS. I am not responsible for any loss of data from the use of this script. 
##

## API information, and JSS base URL (leave off trailing slash in JSS URL)
API_AUTH=$(echo `echo <Base64 Encoded Password> | base64 --decode`) # Make sure to update with your Base64 encoded password!
#JSSURL="https://jss.yourserver.com"

## Archive Category to check (Default is zArchived Scripts" but you can change this to one of your choosing)
ARCHIVE="zArchived Scripts"

##### Functions #####

getCategory()
{
CATEGORY=$(curl -k -s \
	"Accept: text/xml" --user "$API_AUTH" \ \
	"${JSSURL}"/JSSResource/scripts/id/"${1}" -X GET \
	| xmllint --format - | awk -F'>|<' '/<category>/{print $3}')
}

deleteScript()
{
	echo " "
	echo "Now Deleting Script ID $1"
	echo " "
	curl -k -s \
	"Accept: text/xml" --user "$API_AUTH" \
	"${JSSURL}"/JSSResource/scripts/id/"${1}" -X DELETE 
	
	echo " "
	echo "Script ID $1 has been deleted"
}

##### End Functions #####

##### Main Script ##### 

## Prompt User to proceed with script
while true; do
	read -p "Would you like to proceed with searching for and deleting Archived Scripts? Please Enter y/n:  " yn
	case $yn in
		[Yy]* ) CONTINUE="True"; break;;
		[Nn]* ) exit;;
		* ) echo "Please answer yes or no.";;
	esac
done

if [[ "$CONTINUE" != "True" ]]; then
	echo "User chose not to continue. Exiting Script"
	exit 0
fi
echo " "
echo "User chose to continue the script.."
echo " "
echo "This process may take several minutes to run."
echo "You will be prompted at the end of the script to confirm you want to delete the identified Scripts."
echo " "

## Single API pull for all JSS Script data. This pulls both the JSS IDs and Names
ALL_JSS_SCRIPTS=$(curl -k -s \
	"Accept: text/xml" --user "$API_AUTH" \
	${JSSURL}/JSSResource/scripts -X GET \
	| xmllint --format - | awk -F'>|<' '/<id>/,/<name>/{print $3}')

	while true; do
		read line1 || break
		read line2 || break
		ALL_SCRIPT_IDS+=("$line1")
		ALL_SCRIPT_NAMES+=("$line2")
	done < <(printf '%s\n' "$ALL_JSS_SCRIPTS")
	
echo "The following scripts have been identified as being archived."

i=0
for ID in "${ALL_SCRIPT_IDS[@]}"; do
	NAME="${ALL_SCRIPT_NAMES[$i]}"
	getCategory "${ID}"
	if [[ $CATEGORY == "$ARCHIVE" ]]; then
		echo \"${NAME}\""," ${ID}"," ${CATEGORY}
		ARCHIVED_SCRIPT_ID+=($ID)
	fi
	let i=$((i+1))
done

if [ -z "$ARCHIVED_SCRIPT_ID" ]; then
	echo " "
	echo "No Archived Scripts Found. Exiting script.."
	exit 0
fi

echo " "

while true; do
	read -p "Are you sure you want to delete all Archived Scripts? This cannot be undone! Please Enter y/n:  " yn
	case $yn in
		[Yy]* ) DELETE="True"; break;;
		[Nn]* ) exit;;
		* ) echo "Please answer yes or no.";;
	esac
done

echo " "

if [[ "$DELETE" == "True" ]]; then
	echo "User chose to continue script.."
	echo " "
	for ID in "${ARCHIVED_SCRIPT_ID[@]}"; do
		echo "Deleting all Archived Scripts"
		deleteScript "${ID}"
	done
else
	echo "User chose to abort"
fi

echo " "
echo "Exiting Script.."

exit 0

##### End Main Script ##### 
