#!/bin/bash

# get version
function getversion()
{
	ver=`cat $MIRACL_HOME/version.txt`
	printf "MIRACL pipeline v. $ver \n"
}


# help/usage function
function usage()
{
    
    cat <<usage

	1) Segments neurons in cleared mouse brain of virus, cFOS, sparse or nuclear stains in 3D

	Runs a Fiji/ImageJ macro 
	
	Usage: `basename $0` 

	A GUI will open to choose your input clarity folder (with .tif files)

	The folder should contain data from one channel 


		----------

	For command-line / scripting


	Usage: `basename $0` -f <clarity folder> -t <channel type: virus or sparse or nuclear or cfos>

	Example: `basename $0` -f my_clarity_tifs -t virus -p Filter0001

		arguments (required):

			f. Input clarity folder/directory (including .tif images) [folder name without spaces]

			t. Channel type: virus or cFOS or sparse (like Thy1 YFP) or nuclear (like PI)  (default = virus)

		Optional arguments:

			p. Channel prefix & number if multiple channels (like Filter0001)


		----------

    Main Outputs


        segmentation_{type}/seg_{type}.tif (.mhd) : segmentation image with all labels (cells)

        segmentation_{type}/seg_bin_{type}.tif (.mhd) : binarized segmentation image


        Results can be opened in Fiji for visualization


        ----------

	Dependencies:
	
		- Fiji 

		- Fiji Plugins:
		
		1) 3D Segmentation plugins (3D ImageJ suite) 	
		http://imagejdocu.tudor.lu/doku.php?id=plugin:stacks:3d_ij_suite:start	

		2) Mathematical Morphology plugins 
		http://imagej.net/MorphoLibJ

	-----------------------------------
	
	(c) Maged Goubran @ Stanford University, 2016
	mgoubran@stanford.edu
	
	-----------------------------------

usage
getversion >&2

}

# Call help/usage function
if [[ "$1" == "-h" || "$1" == "--help" || "$1" == "-help" ]]; then
    
    usage >&2
    exit 1

fi

#----------

# check dependencies

fijidir=`which c3d`

if [[ -z "${fijidir// }" ]]; 
then
	printf "\n ERROR: Fiji not initialized .. please install it (& the required plugins) & rerun script \n"
	exit 1
else 
	printf "\n Fiji path check: OK...\n" 	
fi

#------------


# GUI for CLARITY input imgs

function choose_file_gui()
{
	local openstr=$1
	local _inpath=$2

    folderpath=$(${MIRACL_HOME}/io/miracl_io_file_folder_gui.py -f folder -s "$openstr")

	folderpath=`echo "${folderpath}" | cut -d ':' -f 2 | sed -e 's/^ "//' -e 's/"$//'`

#	folderpath=`cat path.txt`
	
	eval ${_inpath}="'$folderpath'"

#	rm path.txt

}


# Select Mode : GUI or script

if [[ "$#" -gt 1 ]]; then

	printf "\n Running in script mode \n"

	while getopts ":f:t:p:" opt; do
    
	    case "${opt}" in

	        f)
            	tifdir="${OPTARG}"
            	;;

            t)
            	type=${OPTARG}
            	;;

            p)
            	prefix=${OPTARG}
            	;;
        	
        	*)
            	usage            	
            	;;

		esac
	
	done    	


	# check required input arguments

	if [ -z "${tifdir}" ];
	then
		usage
		echo "ERROR: < -f => input clarity directory> not specified"
		exit 1
	fi

else

	# call gui

	printf "\n No inputs given ... running in GUI mode \n"

	printf "\n Reading input data \n"

	choose_file_gui "Open clarity dir (with .tif files)" tifdir
	
	# check required input arguments

	if [ -z "${tifdir}" ];
	then
		usage
		echo "ERROR: <input clarity directory> was not chosen"
		exit 1
	fi

	# options gui
	opts=$(${MIRACL_HOME}/io/miracl_io_gui_options.py -t "Seg options" -f "seg type (def = virus)" "channel prefix (ex = C001) "  -hf "`usage`")

	# populate array
	arr=()
	while read -r line; do
	   arr+=("$line")
	done <<< "$opts"

	type=`echo "${arr[0]}" | cut -d ':' -f 2 | sed -e 's/^ "//' -e 's/"$//'`

	printf "\n Chosen seg type: $type \n"

	prefix=`echo "${arr[1]}" | cut -d ':' -f 2 | sed -e 's/^ "//' -e 's/"$//'`

    printf "\n Chosen channel prefix: $prefix \n"

fi


# get time

START=$(date +%s)

# Default type to virus
if [ -z ${type} ];
then
    type=virus

fi

# get macro
macro=${MIRACL_HOME}/seg/miracl_seg_neurons_clarity_3D_${type}.ijm

motherdir=$(dirname "${tifdir}")
#inputdir=$(basename ${tifdir})

segdir="${motherdir}"/segmentation_${type}

# make seg dir
if [[ ! -d "${segdir}" ]];then

	printf "\n Creating Segmentation folder\n"
	mkdir -p "${segdir}"

fi

# # split filters -- later

# if [[ ! -d $tifdir/filter0 ]]; then
	
# 	mkdir $tifdir/filter0 $tifdir/filter1
# 	mv $tifdir/*Filter0000* $tifdir/filter0/.
# 	mv $tifdir/*Filter0001* $tifdir/filter1/.

# fi

# free up cached memory -- needs sudo permissions
# printf "\n Freeing up cached memory \n"

# echo "sync; echo 3 | sudo tee /proc/sys/vm/drop_caches"
#sync; echo 3 | sudo tee /proc/sys/vm/drop_caches 1>/dev/null

outseg="${tifdir}"/seg_${type}.mhd
log="${tifdir}"/Fiji_seg_${type}_log.txt
outnii="${segdir}"/seg_${type}.nii.gz

if [[ ! -f ${outseg} ]]; then

	printf "\n Performing Segmentation using Fiji \n"

    if [[ -z ${prefix} ]] ; then

        echo Fiji -macro ${macro} "${tifdir}"
	    Fiji -macro ${macro} "${PWD}/${tifdir}/" | tee "${log}"

    else

        echo Fiji -macro ${macro} ""${tifdir}" ${prefix}"
	    Fiji -macro ${macro} ""${PWD}/${tifdir}" ${prefix}" | tee "${log}"

    fi

else

	echo "Segmentation already computed ... skipping"

fi

# get script timing 
END=$(date +%s)
DIFF=$((END-START))
DIFF=$((DIFF/60))

echo "Segmentation done in $DIFF minutes. Have a good day!"