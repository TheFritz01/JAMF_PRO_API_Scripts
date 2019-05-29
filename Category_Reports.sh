#!/bin/bash

##
## Script name:  Unused_Category_Report.sh
## Author:       Aaron Stovall
## Date:  	 05/29/2019
##
## Description:  Checks all JSS Categories that do not have any active Profiles, Scripts, Policies, or Packages
##		 associated with it. Outputs the Unused Categories to a txt file.
##
## Dependencies: - API Account with permissions to read categories.
##	   	 - A Base64 Encrypted username:password (https://www.base64encode.org) 
##		   (Example: "jamfapiuser:MySuperSecretPassword" would be "amFtZmFwaXVzZXI6TXlTdXBlclNlY3JldFBhc3N3b3Jk")
##
## Notes:        It is strongly advised to TEST, TEST, TEST this against a sandbox environment!
##		 This script is provided AS-IS. I am not responsible for any loss of data from the use of this script. 
##


## API information, and JSS base URL (leave off trailing slash in JSS URL)
# Make sure to update with your Base64 encoded password and JSS URL!
API_AUTH=$(echo `echo <Base64 Encoded Password> | base64 --decode`) #Do not include < > around your encoded password!
JSSURL="https://jss.yourserver.com"

## Location and Name of the completed report
REPORT="~/Desktop/All_Unused_Categories.txt"

##### Functions #####

getPackageCategory()
{
CATEGORY=$(curl -k -s \
	"Accept: text/xml" --user "$API_AUTH" \
	"${JSSURL}"/JSSResource/packages/id/"${1}" -X "GET" \
	| xmllint --format - | awk -F'>|<' '/<category>/{print $3}')
}

getProfileCategory()
{
CATEGORY=$(curl -k -s \
	"Accept: text/xml" --user "$API_AUTH" \
	"${JSSURL}"/JSSResource/osxconfigurationprofiles/id/"${1}"/subset/General -X "GET" \
	| xpath "//category/name/text()" 2>/dev/null)
}

getScriptCategory()
{
CATEGORY=$(curl -k -s \
	 "Accept: text/xml" --user "$API_AUTH" \
	"${JSSURL}"/JSSResource/scripts/id/"${1}" -X "GET" \
	| xmllint --format - | awk -F'>|<' '/<category>/{print $3}')
}

getPolicyCategory()
{
CATEGORY=$(curl -k -s \
	"Accept: text/xml" --user "$API_AUTH" \
	"${JSSURL}"/JSSResource/policies/name/"${1}"/subset/General -X "GET" \
	| xpath "//category/name/text()" 2>/dev/null)		
}

containsElement () {
	local e match="$1"
	shift
	for e; do [[ "$e" == "$match" ]] && return 0; done
	return 1
}

##### End Functions #####

##### Main Script ##### 

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
	
ALL_JSS_POLICIES=$(curl -k -s \
	"Accept: text/xml" --user "$API_AUTH" \
	${JSSURL}/JSSResource/policies -X GET \
	| xmllint --format - | awk -F'>|<' '/<name>/{print $3}' | sed '/|.*|.*/d')

	while true; do
		read line1 || break
		ALL_POLICY_NAMES+=("$line1")
	done < <(printf '%s\n' "$ALL_JSS_POLICIES")
	
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
	
##############################################

i=0
echo "Getting Package Categories"
echo " "
for ID in "${ALL_PACKAGE_IDS[@]}"; do
	NAME="${ALL_PACKAGE_NAMES[$i]}"
	getPackageCategory "${ID}"
	echo \"${NAME}\""," ${ID}"," ${CATEGORY}
	CATEGORIES+=("${CATEGORY}")
	let i=$((i+1))
done

echo " "

i=0
echo "Getting Profile Categories"
echo " "
for ID in "${ALL_PROFILE_IDS[@]}"; do
	NAME="${ALL_PROFILE_NAMES[$i]}"
	getProfileCategory "${ID}"
	echo \"${NAME}\""," ${ID}"," ${CATEGORY}
	CATEGORIES+=("${CATEGORY}")
	let i=$((i+1))
done

echo " "

echo "Getting Policy Categories"
echo " "
for NAME in "${ALL_POLICY_NAMES[@]}"; do
	getPolicyCategory "${NAME}"
	# Check to see if a Category is assigned, if not set to "No category assigned"
	if [ -z "$CATEGORY" ]; then
		{
			CATEGORY="No category assigned"
		}
	fi
	echo "${NAME}, ${CATEGORY}"
	CATEGORIES+=("${CATEGORY}")
done

echo " "	

i=0
echo "Getting Script Categories"
echo " "
for ID in "${ALL_SCRIPT_IDS[@]}"; do
	NAME="${ALL_SCRIPT_NAMES[$i]}"
	getScriptCategory "${ID}"
	echo \"${NAME}\""," ${ID}"," ${CATEGORY}
	CATEGORIES+=("${CATEGORY}")
	let i=$((i+1))
done

################################################

# Show only the Unique Values from all assigned Categories
eval CATEGORY_NAMES=($(for i in  "${CATEGORIES[@]}" ; do  echo "\"$i\"" ; done | sort -u))


###############################################

## Get all Categories currently available in the JSS
ALL_CATEGORY_NAMES=$(curl -k -s \
	"Accept: text/xml" --user "$API_AUTH" \
	${JSSURL}/JSSResource/categories -X GET \
	| xmllint --format - | awk -F'>|<' '/<name>/{print $3}')
	
	while true; do
		read line1 || break
		JSS_CATEGORY_NAMES+=("$line1")
	done < <(printf '%s\n' "$ALL_CATEGORY_NAMES")

################################################

## Compare the Assigned Categories to all JSS Categories to show which Categories are not currently used.
for i in "${JSS_CATEGORY_NAMES[@]}"; do
	containsElement "$i" "${CATEGORY_NAMES[@]}"
	if [[ "$?" == 1 ]]; then
#		echo "Not Found: $i"
		UNUSED_CATEGORIES+=("$i")
	fi
done

echo " "
echo "The following categories are not associated with any Policy, Profile, Script, or Package."
echo " "
printf '%s\n' "${UNUSED_CATEGORIES[@]}"
printf "%s\n" "${UNUSED_CATEGORIES[@]}" > "$REPORT"

exit 0

##### End Main Script ##### 
