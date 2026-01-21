#!/usr/bin/env bash
########################################################################################################################
# Usage: ./generate_docs.sh [token]
#
# Description: Generates minimal HTML and PDF files in an output directory using GitHubs markdown API.
# 	The markdown files are first converted to HTML then the HTML files are converted to PDF.               
#
# Note: GitHub's API is rate limited (60 requests per hour). Using an access token from the
# 	following URL, this rate is increased considerably: https://github.com/settings/tokens/new?scopes=
# 	More info here: https://github.com/joeyespo/grip#access
########################################################################################################################

OUT_DIR_HTML=html/
OUT_DIR_PDF=pdf/

# check if grip installed
which grip > /dev/null 2> /dev/null
rc=$?
if [ ${rc} != 0 ]; then
	echo "The command 'grip' is not available. Install it with pip:"
	echo "sudo pip install grip"
	exit 1
fi

# check if chromium installed
which chromium-browser > /dev/null 2> /dev/null
rc=$?
if [ ${rc} != 0 ]; then
	echo "The command 'chromium-browser' is not available. Install it with apt:"
	echo "sudo apt install chromium-browser"
	exit 1
fi

# make sure output directories exists
mkdir -p ${OUT_DIR_HTML}
mkdir -p ${OUT_DIR_PDF}

# check if GitHub access token provided
if [ -n "$1" ]; then
	token_argument="--pass $1"
fi

# generate html
echo -n "Generating html in ${OUT_DIR_HTML} ... "
for tut in tutorial-*; do
	grip \
 		"${tut}/README.md" ${token_argument} --quiet --export --no-inline ${OUT_DIR_HTML}${tut}.html
done
echo "done"

# generate pdf
echo -n "Generating pdf in ${OUT_DIR_PDF} ... "
for tut in $(ls ${OUT_DIR_HTML}); do
	chromium-browser --headless --disable-gpu --print-to-pdf=${OUT_DIR_PDF}${tut}.pdf "${OUT_DIR_HTML}${tut}"
done
echo "done"


