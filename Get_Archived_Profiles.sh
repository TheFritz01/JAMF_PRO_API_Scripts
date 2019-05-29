#!/bin/bash

##
## Script name:  Get_Archived_Profiless.sh
## Author:       Aaron Stovall
## Date:  	 05/29/2019
##
## Description:  Checks for all Configuration Profiles that are associated with the "zArchived Profiles" Category
## 		 and will prompt to confirm deletion. 
##
## Dependencies: - API Account with permissions to read and delete profiles
##		 - A category called "zArchived Profiles" (This can be changed to any category of your choosing)
##		 - A Base64 Encrypted username:password (https://www.base64encode.org) 
##		   (Example: "jamfapiuser:MySuperSecretPassword" would be "amFtZmFwaXVzZXI6TXlTdXBlclNlY3JldFBhc3N3b3Jk")
##
## Notes: 	 It is strongly advised to TEST, TEST, TEST this against a sandbox environment!
##		 This script is provided AS-IS. I am not responsible for any loss of data from the use of this script. 
##

## API information, and JSS base URL (leave off trailing slash in JSS URL)
# Make sure to update with your Base64 encoded password and JSS URL!
API_AUTH=$(echo `echo <Base64 Encoded Password> | base64 --decode`) #Do not include < > around your encoded password!
JSSURL="https://jss.yourserver.com"

## Archive Category to check (Default is zArchived Scripts" but you can change this to one of your choosing)
ARCHIVE="zArchived Profiles"

##### Functions #####

getCategory()
{
CATEGORY=$(curl -k -s \
	"Accept: text/xml" --user "$API_AUTH" \
	"${JSSURL}"/JSSResource/osxconfigurationprofiles/id/"${1}"/subset/General -X "GET" \
	| xpath "//category/name/text()" 2>/dev/null)
}

deleteProfile()
{
	curl -k -s \
	"Accept: text/xml" --user "$API_AUTH"  \
	"${JSSURL}"/JSSResource/osxconfigurationprofiles/id/"${1}" -X DELETE
		
	echo " "
	echo " "
	echo "Profile ID $1 has been deleted"
	echo " "
}

##### End Functions #####

##### Main Script ##### 

## Prompt User to proceed with script
read -p "Would you like to proceed with searching for and deleting Archived Profiles? Please Enter y/n:  " yn

if [[ "$yn" == [Nn]* ]]; then
	echo "User chose not to continue. Exiting Script"
	exit 0
fi
echo " "
echo "User chose to continue.."
echo " "
echo "This process may take several minutes to run."
echo "You will be prompted at the end of the script to confirm you want to delete the identified Profiles."
echo " "


## Single API pull for all JSS Script data. This pulls both the JSS IDs and Names
ALL_JSS_PROFILES=$(curl -k -s \
	"Accept: text/xml" --user "$API_AUTH" \
	${JSSURL}/JSSResource/osxconfigurationprofiles -X GET \
	| xmllint --format - | awk -F'>|<' '/<id>/,/<name>/{print $3}')

	while true; do
		read line1 || break
		read line2 || break
		ALL_PROFILE_IDS+=("$line1")
		ALL_PROFILE_NAMES+=("$line2")
	done < <(printf '%s\n' "$ALL_JSS_PROFILES")

echo "The following Profiles have been identified as being archived."	

i=0
for ID in "${ALL_PROFILE_IDS[@]}"; do
	NAME="${ALL_PROFILE_NAMES[$i]}"
	getCategory "${ID}"
	if [[ $CATEGORY == "${ARCHIVE}" ]]; then
		echo \"${NAME}\"
		ARCHIVED_PROFILE_ID+=($ID)
	fi
	let i=$((i+1))
done

if [ -z "$ARCHIVED_PROFILE_ID" ]; then
	echo " "
	echo "No Archived Profiles Found. Exiting script.."
	exit 0
fi

echo " "
	
read -p "Would you like to delete all archived profiles? WARNING: This cannot be undone! Please Enter y/n:  " yn

echo " "

if [[ "$yn" == [Yy]* ]]; then
	echo "User chose to delete Profiles"
	echo " "
	for ID in "${ARCHIVED_PROFILE_ID[@]}"; do
		echo " "
		deleteProfile "${ID}"
	done
else
	echo "User chose not to delete the archived profiles."
	echo " "
fi

echo "Script Completed."
exit 0

##### Main Script ##### 
