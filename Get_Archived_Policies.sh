#!/bin/bash

##
## Script name:  Get_Archived_Policies.sh
## Author:       Aaron Stovall
## Date:  	 05/29/2019
##
## Description:  Checks for all Policies that are associated with the "zArchived Policies" Category
## 		 and will prompt to confirm to if you want to disable the policy and also gives the 
##		 option to delete the policy. 
##
## Dependencies: - API Account with permissions to read and delete policies
##		 - A category called "zArchived Policies" (This can be changed to any category of your choosing)
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
ARCHIVE="zArchived Policies"

##### Functions #####

deletePolicy()
{
	curl -k -s \
	"Accept: text/xml" \
	"${JSSURL}"/JSSResource/policies/id/"${1}" -X DELETE --user "$API_AUTH" 
		
	echo " "
	echo " "
	echo "Policy ID $1 has been deleted"
	echo " "
}

disablePolicy()
{
	curl -k -H \
	"Content-Type: application/xml" \
	-d '<policy><general><enabled>false</enabled></general></policy>' -X PUT \
	"${JSSURL}"/JSSResource/policies/id/"${ID}" --user "$API_AUTH"  
	
	echo " "
	echo " "
	echo "Policy ID $1 has been disabled"
	echo " "
}

##### End Functions #####

##### Main Script #####

## Prompt User to proceed with script
read -p "Would you like to proceed with searching for and disabling Archived Policies? Please Enter y/n:  " yn

if [[ "$yn" == [Nn]* ]]; then
	echo "User chose not to continue. Exiting Script"
	exit 0
fi
echo " "
echo "User chose to continue the script.."
echo " "
echo "This process may take several minutes to run."
echo "You will be prompted at the end of the script to confirm you want to disable the identified Policies."
echo " "


## Single API pull for all JSS Script data. This pulls both the JSS IDs and Names
ALL_JSS_POLICIES=$(curl -k -s \
	"Accept: text/xml" --user "$API_AUTH" \
	${JSSURL}/JSSResource/policies/category/"${ARCHIVE}" -X GET \
	| xmllint --format - | awk -F'>|<' '/<id>/,/<name>/{print $3}')

	while true; do
		read line1 || break
		read line2 || break
		ALL_POLICY_IDS+=("$line1")
		ALL_POLICY_NAMES+=("$line2")
	done < <(printf '%s\n' "$ALL_JSS_POLICIES")

echo "The following Policies have been identified as being archived."	

i=0
for ID in "${ALL_POLICY_IDS[@]}"; do
	NAME="${ALL_POLICY_NAMES[$i]}"
	echo \"${NAME}\""," ${ID}
	ARCHIVED_POLICY_ID+=($ID)
	let i=$((i+1))
done

if [ -z "$ARCHIVED_POLICY_ID" ]; then
	echo " "
	echo "No Archived Policies Found. Exiting script.."
	exit 0
fi

echo " "
	
read -p "Are you sure you want to disable all Archived Policies? Please Enter y/n:  " yn

echo " "

if [[ "$yn" == [Yy*] ]]; then
	echo "User chose to disable policies"
	echo " "
	for ID in "${ARCHIVED_POLICY_ID[@]}"; do
		echo "Now Disabling all Archived Policies"
		echo " "
		disablePolicy "${ID}"
	done
else
	echo "User chose not to disable policies"
	echo " "
fi

read -p "Would you like to delete all archived policies? WARNING: This cannot be undone! Please Enter y/n:  " yn

echo " "

if [[ "$yn" == [Yy]* ]]; then
	echo "User chose to delete policies"
	echo " "
	for ID in "${ARCHIVED_POLICY_ID[@]}"; do
		echo "Now Deleting All Archived Policies"
		echo " "
		deletePolicy "${ID}"
	done
else
	echo "User chose not to delete policies"
	echo " "
fi

echo " "
echo "Exiting Script.."

exit 0
##### Main Script #####
