#!/bin/bash

gist_url_base="gist.github.com"

echo
echo "gist_url: ${gist_url}"

# Validate gist_url
if [ "${gist_url}" != "" ]; then
	if [[ "${gist_url}" != "http://$gist_url_base"* ]] && [[ "${gist_url}" != "https://$gist_url_base"* ]];then
		echo
		echo "gist_url must be a valid Gist URL (containing '$gist_url_base'). Terminating..."
		echo
		exit 1
	fi
else
	echo
	echo "No gist_url was provided to the step. Terminating..."
	echo
	exit 1
fi

echo
echo "---------------------------------------------------"
echo "--- Fetching \"raw\" Gist URL(s) from: ${gist_url}"
echo
echo "--- Warning messages from tidy command (disregard):"

# construct an XHTML doc to contain the extracted raw URL anchor tags
temp_doc=$(curl -sSL "${gist_url}" | grep -Eoi '<a [^>]+>Raw</a>' | tidy -quiet)

# count the number of raw URL anchor tags (and Gist files, by association)
file_count=$(echo $temp_doc | xmllint --html --xpath "count(//a/@href)" -)

echo
echo "--- Number of files found in Gist: $file_count"
echo "---------------------------------------------------"

# declare an array to contain the raw URL strings
declare -a raw_urls

# extract each raw URL from the anchor tags and place in the array
for (( i=1; i <= $file_count; i++ )); do 
    raw_urls[$i]="$(echo $temp_doc | xmllint --html --xpath 'string(//a['$i']/@href)' -)"
done

# A var to hold the current Gist file number, since i below is an iterator, not an index.
j=1

# iterate over the array or raw urls
for i in "${raw_urls[@]}"
do

	# construct the complete raw URL, since the urls from the anshors are relative URLs
	raw_url="https://$gist_url_base$i"

	echo
	echo "---------------------------------------------------"
	echo "--- Executing remote script #$j: $raw_url"
	echo

	# retireve the contents of the file at the raw URL and execute as a bash script
	bash -c "$(curl -sSL "${raw_url}")"

	# get the exit code
	res_code=$?

	# if the exit code is not 0, then something failed, so let's report it
	if [ ${res_code} -ne 0 ] ; then
		echo
		echo "--- [!] Script #$j returned with an error code: ${res_code}"
		echo "---------------------------------------------------"
		if [[ ${exit_on_failure} == "true" ]]; then
			echo "--- Since the exit_on_failure value is set to true in the remote gist bash runner step, we're terminating, and none of the subsequent files in the given gist will be run..."
			exit 1
		fi
		j=$(($j+1))
	# the script completed without an error code
	else
		echo
		echo "--- Script #$j returned with a success code - OK"
		echo "---------------------------------------------------"
		echo
		j=$(($j+1))
	fi

done

exit 0