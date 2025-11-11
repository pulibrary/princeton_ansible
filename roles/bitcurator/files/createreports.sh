#! /bin/bash
directory=''
usage()
{
    	echo " "
    	echo "USAGE: [-h][-i] input [-b | -f]"
    	echo " "
    	echo "-i <arg>	input directory"
    	echo " "
    	echo "options:"
        echo "-h		print this message"
        echo "-b		run bulk extractor"
        echo "-f		run FITS"
        echo " "
}

timestamp()
{
	date
}

directoryName()
{
	realpath ${directory} 2>/dev/null | rev | cut -d'/' -f1 | rev
}

dirPath()
{
	realpath ${directory}
}

while getopts ':hi:bf' flag; do
  case "${flag}" in
    h)
		usage
    ;;
    i)  
    	directory="${OPTARG}"
		mkdir $(directoryName)_reports
		echo -e "\n******* Running ClamScan *******\n"
		clamscan -i -r $(dirPath) | tee $(directoryName)_reports/$(directoryName)_virusCheck.txt
		if [ $(grep -c "Infected files: 0" $(directoryName)_reports/$(directoryName)_virusCheck.txt) -eq 0 ];
		then
  			echo -e "\n******* Infection(s) Found *******\n"
  			while true; do
				read -p "Do you wish to exit CreateReports (y/n)?" yn
    			case $yn in
        			[Yy]* ) 
        				echo -e "\n******* Saving log in $(directoryName)_reports *******\r"
  						sleep 1
  						echo -e "Date Scanned: $(timestamp)" >> $(directoryName)_reports/$(directoryName)_virusCheck.txt
  						echo -e "\n******* Exiting *******\n"
  						sleep 1
  						exit 1
  						;;
        			[Nn]* ) 
        				break
        				;;
        			* ) echo "Please answer yes or no.";;
    			esac
			done
		else
			echo -e "Date Scanned: $(timestamp)" >> $(directoryName)_reports/$(directoryName)_virusCheck.txt
			echo -e "\n******* No Infections Found *******"
		fi
		
		echo -e "\n******* Creating Manifest, Counting & Validating Formats *******\n"
		echo -ne '#                         (10%)\r'
		sleep 1
		echo -ne '#####                     (33%)\r'
		sf -z -hash md5 -csv $(dirPath) >> $(directoryName)_reports/$(directoryName)_siegfried.csv
		echo -ne "******* Be Patient! *******\r"
		echo -e "Directories Count: $(find $(dirPath)/* -type d | wc -l)\nFiles Count: $(find $(dirPath) -type f | wc -l)\n$(ls -lh -R $(dirPath))\n\n" >> $(directoryName)_reports/$(directoryName)_manifest.txt
		echo -ne '#############             (66%)\r'
		sleep 1
	
		find $(dirPath) -type f | sed 's/.*\.//' | sort | uniq -c > $(directoryName)_reports/$(directoryName)_fileTypes.csv
		echo -e "$(sed 's/^[ \t]*//;s/ \{1,\}/,/g' $(directoryName)_reports/$(directoryName)_fileTypes.csv)" > $(directoryName)_reports/$(directoryName)_fileTypes.csv
		echo -ne '#######################   (100%)\r'
		echo -ne '\n'
    ;;
    b) 
    	echo -e "\n******* Initializing Bulk Extractor *******\n\r"
		sleep 1
		mkdir $(directoryName)_reports/bulk_extractor
		bulk_extractor -S ssn_mode=2 -o $(directoryName)_reports/$(directoryName)_BulkExt -R $(dirPath)

    ;;
    f) 
    	echo -e "\n******* Initializing FITS *******\n\r"
		sleep 1
		mkdir $(directoryName)_reports/fits
		fits -i $(dirPath) -r -xc -o $(directoryName)_reports/$(directoryName)_FITS
    ;;
    \?)
    	echo "Invalid option" >&2
    ;;
    :)
    	echo "Option -$OPTARG requires an argument." >&2
      	exit 1
    ;;
  esac
done

if [[ $# -eq 0 ]] ; then
    usage
    exit 0
fi

