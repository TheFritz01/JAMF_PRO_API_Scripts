#!/bin/bash

##
## Script name:  Get_Archived_Packages.sh
## Author:       Aaron Stovall
## Date:  	 05/29/2019
##
## Description:  Checks for all Packages that are associated with the "zArchived Packages" Category
## 		 and will prompt to confirm deletion. 
##
## Dependencies: - API Account with permissions to read and delete packages
##		 - A JAMF Cloud Distribution Point as your Master. This will not delete packages from on-prem
##		   distribution points or Cloud distribution points that are not set as master.
##		 - A category called "zArchived Packages" (This can be changed to any category of your choosing)
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

## Archive Category to check (Default is "zArchived Packages" but you can change this to one of your choosing)
ARCHIVE="zArchived Packages"

##### Functions #####

getCategory()
{
CATEGORY=$(curl -k -s \
	"Accept: text/xml" --user "$API_AUTH" \
	"${JSSURL}"/JSSResource/packages/id/"${1}" -X "GET" \
	| xmllint --format - | awk -F'>|<' '/<category>/{print $3}')
}

deletePackage()
{
	curl -k -s \
	"Accept: text/xml" --user "$API_AUTH"  \
	"${JSSURL}"/JSSResource/packages/id/"${1}" -X DELETE
		
	echo " "
	echo " "
	echo "Package ID $1 has been deleted"
	echo " "
}

##### End Functions #####

##### Main Script ##### 

## Prompt User to proceed with script
read -p "Would you like to proceed with searching for and deleting Archived Packages? Please Enter y/n:  " yn

if [[ "$yn" == [Nn]* ]]; then
	echo "User chose not to continue. Exiting Script"
	exit 0
fi
echo " "
echo "User chose to continue.."
echo " "
echo "This process may take several minutes to run."
echo "You will be prompted at the end of the script to confirm you want to delete the identified Packages."
echo " "


### Single API pull for all JSS Script data. This pulls both the JSS IDs and Names
ALL_JSS_PACKAGES=$(curl -k -s \
	"Accept: text/xml" --user "$API_AUTH" \
	${JSSURL}/JSSResource/packages -X GET \
	| xmllint --format - | awk -F'>|<' '/<id>/,/<name>/{print $3}')

	while true; do
		read line1 || break
		read line2 || break
		ALL_PACKAGE_IDS+=("$line1")
		ALL_PACKAGE_NAMES+=("$line2")
	done < <(printf '%s\n' "$ALL_JSS_PACKAGES")
	
echo "The following Profiles have been identified as being archived."

i=0
for ID in "${ALL_PACKAGE_IDS[@]}"; do
	NAME="${ALL_PACKAGE_NAMES[$i]}"
	getCategory "${ID}"
	if [[ $CATEGORY == "${ARCHIVE}" ]]; then
		echo \"${NAME}\""," ${ID}"," ${CATEGORY}
		ARCHIVED_PACKAGE_ID+=($ID)
	fi
	let i=$((i+1))
done

if [ -z "$ARCHIVED_PACKAGE_ID" ]; then
	echo " "
	echo "No Archived Paclages Found. Exiting script.."
	exit 0
fi

echo " "
	
read -p "Would you like to delete all archived packages? WARNING: This cannot be undone! Please Enter y/n:  " yn

echo " "

if [[ "$yn" == [Yy]* ]]; then
	echo "User chose to delete Packages"
	echo " "
	for ID in "${ARCHIVED_PACKAGE_ID[@]}"; do
		echo " "
		deletePackage "${ID}"
	done
else
	echo "User chose not to delete the archived packages."
	echo " "
fi

echo "Script Completed."
exit 0

##### End Main Script ##### 
