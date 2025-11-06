#!/bin/sh

OLD_UMASK="$(umask)"
umask 0022

cleanupAndExit(){
#rm -rf /tmp/appx
exit
}

process_install_list(){

	if [ ! -d "$1" ]; then
		echo "Argv1 to process_install_list is WINEHOME, this has not been found, so exiting."
		cleanupAndExit
	fi

	if [ ! -d "$1/drive_c/Program Files/WindowsApps" ]; then
		mkdir -p "$1/drive_c/Program Files/WindowsApps"
	fi

	cat /tmp/appx/install_list.txt | while read line; do
		if [ ! -d "$1/drive_c/Program Files/WindowsApps/$(basename "$line")" ]; then
			appxmanifest=""
			appxmanifest="$(find "$line" -type f -name AppxManifest.xml | head -n 1)"

			if ! [ -f "$appxmanifest" ]; then
				appxmanifest="$(find "$line" -type f -name "AppxBundleManifest.xml" | head -n 1)"
				if ! [ -f "$appxmanifest" ]; then
					printf "Could not find AppxManifest.xml or AppxBundleManifest.xml within archive, exiting.\n"
					cleanupAndExit
				fi
			fi

			packageBlock="$(printTag "$(cat "$appxmanifest")" "Package" "")"
			identityTag="$(printTag "${packageBlock}" "Identity")"
			nameTag="$(printf "%s" "${identityTag}" | grep -o "Name=\".*" | cut -d '"' -f 2)"
			publisherTag="$(printf "%s" "${identityTag}" | grep -o "Publisher=\".*" | cut -d '"' -f 2)"
			architectureTag="$(printf "%s" "${identityTag}" | grep -o "ProcessorArchitecture=\".*" | cut -d '"' -f 2)"

			if [ "$nameTag" != "" ]; then

				versionTag="$(printf "%s" "${identityTag}" | grep -o "Version=\".*" | cut -d '"' -f 2)"
	
				if [ "$versionTag" != "" ]; then
	
	
					old_IFS="$IFS"
					IFS='<'
					readIndex=0
					appxFilename=""
					appxScale=""
					appxLanguage=""
					printf "%s\n" "$packageBlock" | while read lineTwo; do

						#read packages tag if it exists
						if [ "$(printf "%s\n" "$lineTwo" | grep "<.*Package.*>")" != "" ] && [ "$readIndex" = "0" ]; then
							#check packages tag is of Type "Application"
							if [ "$(printf "%s\n" "$lineTwo" | grep "<.* Type=\"Application\" .*>")" != "" ]; then
								#check packages architecture is the same as theArch
								if [ "$(printf "%s\n" "$lineTwo" | grep "<.* Architecture=\"${theArch}\" .*>")" != "" ]; then
									appxFilename="$(printf "%s\n" "$lineTwo" | grep -Po "FileName=\".*?\"")"
								fi
							fi

							readIndex="1"
						elif [ "$(printf "%s\n" "$lineTwo" | grep "<\s*Resources.*>")" != "" ] && ( [ "$readIndex" = 1 ] || [ "$readIndex" = 3 ] ); then
							#if [ "$appxFilename" != "" ]; then
								readIndex=2
							#fi
						elif [ "$(printf "%s\n" "$lineTwo" | grep "<\s*/\s*Resources.*>")" != "" ] && [ "$readIndex" = 2 ]; then
							#end tag
							readIndex=1
						elif [ "$(printf "%s\n" "$lineTwo" | grep "<\s*Resource.*>")" != "" ] && [ "$readIndex" = 2 ]; then
							#if [ "$appxFilename" != "" ]; then

								if [ "${appxLanguage}" = "en-US" ]; then
									foundLang="en-US"
								elif [ "${appxLanguage}" = "" ]; then
									appxLanguage="$(printf "%s\n" "$lineTwo" | grep -Po "Language=\"${theLanguage}\"")"
								fi
								#default to 'merica packages if our lang is not found
								if [ "$appxLanguage" = "" ] && [ "$foundLang" = "" ]; then
									appxLanguage="$(printf "%s\n" "$lineTwo" | grep -Po "Language=\"en-US\"")"
								elif [ "$foundLang" = "en-US" ]; then
									appxLanguage="en-US"
								fi

								readScale="$(printf "%s\n" "$lineTwo" | grep -o "Scale=\".*\"")"
								if [ "$readScale" != "" ]; then
									appxScale="$(printf "%s" "$readScale" | cut -d '"' -f 2)"
								fi
							#fi
						elif [ "$(printf "%s\n" "$lineTwo" | grep "<\s*/\s*Package.*>")" != "" ] && [ "$readIndex" = "1" ]; then
echo $appxLanguage MMM $nameTag
							if [ "$appxLanguage" != "" ] && [ "$nameTag" != "" ]; then
								echo "Installing $nameTag ..."
								if [ "$publisherTag" = "" ]; then 
									cp -a "$line" "$1/drive_c/Program Files/WindowsApps/${nameTag}_${versionTag}_${architectureTag}_${appxScale}"
								else
									pubhash="$(printf "%s" "$(python3 "${2}/deps/pubid.py" "${publisherTag}")")"

									cp -a "$line" "$1/drive_c/Program Files/WindowsApps/${nameTag}_${versionTag}_${architectureTag}_${appxScale}_${pubhash}"
								fi
							fi

							readIndex=0
							appxFilename=""
							appxScale=""
							appxLanguage=""
						fi	
					done
					IFS="$old_IFS"
				fi
			fi

		fi
	done
}

findTag(){
#1 texttosearch
#2 before
#3 after

thetag="$(printf "%s" "${1}" | grep -Poba "<\s*?${2}.*?${3}.*?>" | head -n 1)"

if [ "$thetag" = "" ]; then
return
fi

notrighttaglen="$(printf "%s" "${thetag}" | cut -d ':' -f 2- | wc -c)"

startindex="$(printf "%s" "$thetag" | cut -d ':' -f 1)"

thetag="$(printf "%s" "$thetag" | grep -Po "<[^<]*$" )"
thetaglen="$(printf "%s" "$thetag" | wc -c)"

endindex="$(expr $startindex + $notrighttaglen)"
startindex="$(expr $endindex - $thetaglen)"

endindex="$(expr $endindex - 1)"
#printf "%s" "$thetag"

thetag="-1"
i=1
aorb=""
thetagA=""
thetagB=""
thetagAidx=""
thetagBidx=""
while true; do
#printf "%s<<\n" "$endindex"
	tosearch="$(printf "%s" "${1}" | cut -z -c ${endindex}- | sed "s/\x0$//g")"
#printf "%d\n" "$i"

	thetagA="$(printf "%s" "${tosearch}" | grep -Poba "<\s*?/${2}.*?\>" | head -n 1)"
	thetagB="$(printf "%s" "${tosearch}" | grep -Poba "<\s*?${2}.*?\>" | head -n 1)"
#printf ">>>>%s\n" "$thetagB"
	if [ "$thetagA" != "" ]; then
		thetagAidx="$(printf "%s" "${thetagA}" | cut -d ':' -f 1)"
		notrighttaglen="$(printf "%s" "${thetagA}" | cut -d ':' -f 2- | wc -c)"
		thetagAstartidx="$(printf "%s" "$thetagA" | cut -d ':' -f 1)"
		thetagA="$(printf "%s" "$thetagA" | grep -Po "<[^<]*$" )"
		thetagAlen="$(printf "%s" "$thetagA" | wc -c)"
		thetagAendidx="$(expr $thetagAstartidx + $notrighttaglen)"
		thetagAidx="$(expr $thetagAendidx - $thetagAlen)"
	else
		thetagAidx=""
	fi

	if [ "$thetagB" != "" ]; then
		thetagBidx="$(printf "%s" "${thetagB}" | cut -d ':' -f 1)"
		notrighttaglen="$(printf "%s" "${thetagB}" | cut -d ':' -f 2- | wc -c)"
		thetagBstartidx="$(printf "%s" "$thetagB" | cut -d ':' -f 1)"
		thetagB="$(printf "%s" "$thetagB" | grep -Po "<[^<]*$" )"
		thetagBlen="$(printf "%s" "$thetagB" | wc -c)"
		thetagBendidx="$(expr $thetagBstartidx + $notrighttaglen)"
		thetagBidx="$(expr $thetagBendidx - $thetagBlen)"
	else
		thetagBidx=""
	fi
	if [ "$thetagAidx" = "" ] && [ "$thetagBidx" = "" ]; then
		aorb=""
		break
	elif [ "$thetagAidx" = "" ]; then
		thetagidx=$thetagBidx
		aorb="B"
		i="$(expr $i + 1)"
	elif [ "$thetagBidx" = "" ]; then
		thetagidx=$thetagAidx
		aorb="A"
		i="$(expr $i - 1)"
	elif [ $thetagAidx -lt $thetagBidx ]; then
		thetag=$thetagAidx
		aorb="A"
		i="$(expr $i - 1)"
	else
		thetag=$thetagBidx
		aorb="B"
		i="$(expr $i + 1)"
	fi


	if [ "${aorb}" = "A" ]; then
		endindex="$(expr $endindex + $thetagAidx)"
		endindex="$(expr $endindex + $(printf "%s" "$thetagA" | cut -d ":" -f 2- | wc -c))"
		endindex="$(expr $endindex - 2)"
#printf "%s\n" "$endindex"
	else
		endindex="$(expr $endindex + $thetagBidx)"
		endindex="$(expr $endindex + $(printf "%s" "$thetagB" | cut -d ":" -f 2- | wc -c))"
		endindex="$(expr $endindex - 2)"
	fi

#printf "%s %d" "$aorb" "$i"

	if [ $i -eq 0 ]; then
		break
	fi

	if [ "$thetag" = "" ]; then
		break
	fi
done

printf "%d:%d" "${startindex}" "${endindex}"

}

checkDependency()
{
	foundDependencyAlready="0"

	lengthName="$(expr length "$4")"
	lengthName="$(expr $lengthName + 1)"

	old_IFS="$IFS"
export IFS='
'

	#check to see if we have the dependency already installed in the WindowsApps folder

	for candidatePath in $(find "$1/drive_c/Program Files/WindowsApps" -maxdepth 1 -type d -iname "${4}_*") ; do

		candidate="$(printf "%s" "$(basename "$candidatePath")" | cut -c ${lengthName}-)"
		candidateArch="$(printf "%s" "$(basename "$candidatePath")" | cut -d '_' -f 3)"
		#if the candidate arch is not the 3rd field, use the second
		if [ "$candidateArch" = "" ]; then
			candidateArch="$(printf "%s" "$(basename "$candidate")" | cut -d '_' -f 2)"
		fi

		if [ "$candidateArch" = "neutral" ] || [ "$candidateArch" = "$3" ]; then
			foundDependencyAlready=1
			break
		fi


		if [ "$candidateArch" = "neutral" ] || [ "$candidateArch" = "$3" ]; then
			candidateVersion="$(printf "%s" "$(basename "$candidate")" | cut -d '_' -f 1)"
			#check candidate version is between max and min exclusive
			if { echo "$candidateVersion"; echo "$6"; } | sort --version-sort --check; then
				if { echo "$candidateVersion"; echo "$versionToCheck"; } | sort --version-sort --check; then
					echo "$candidate is already installed."
					foundDependencyAlready=1
					break
				fi
			fi
		fi

	done

	#check the dependency isn't inside an extracted appx/msix dir
	if [ "$foundDependencyAlready" = "0" ]; then
		for candidatePath in $(find "/tmp/appx" -type d -maxdepth 1 -mindepth 1 -name "$4_*") ; do
			candidate="$(printf "%s" "$(basename "$candidatePath")" | cut -c ${lengthName}-)"
			candidateArch="$(printf "%s" "$(basename "$candidatePath")" | cut -d '_' -f 3)"

			#if the candidate arch is not the 3rd field, use the second
			if [ "$candidateArch" = "" ]; then
				candidateArch="$(printf "%s" "$(basename "$candidatePath")" | cut -d '_' -f 2)"
			fi
			if [ "$candidateArch" = "neutral" ] || [ "$candidateArch" = "$3" ]; then
				echo "$candidatePath" >> /tmp/appx/install_list.txt
				foundDependencyAlready=1
				break
			fi
			if [ "$candidateArch" = "neutral" ] || [ "$candidateArch" = "$3" ]; then
				candidateVersion="$(printf "%s" "$(basename "$candidatePath")" | cut -d '_' -f 1)"
				#check candidate version is between max and min exclusive
				if { echo "$candidateVersion"; echo "$6"; } | sort --version-sort --check; then
					if { echo "$candidateVersion"; echo "$versionToCheck"; } | sort --version-sort --check; then
						echo "$candidatePath" >> /tmp/appx/install_list.txt
						foundDependencyAlready=1
						break
					fi
				fi
			fi	
		done
	fi

	#check the dependency isn't inside an appx file which is inside a dir
	if [ "$foundDependencyAlready" = "0" ]; then
		find "/tmp/appx" -type f -name "$4_*.msix" -o -name "$4_*.appx" | while read candidatePath; do
			candidate="$(printf "%s" "$(basename $candidatePath)" | cut -c ${lengthName}-)"
			candidateArch="$(printf "%s" "$(basename "$candidatePath")" | cut -d '_' -f 3)"
			if [ "$candidateArch" = "" ]; then
				candidateArch="$(printf "%s" "$(basename "$candidatePath")" | cut -d '_' -f 2)"
			fi
			if [ "$candidateArch" = "neutral" ] || [ "$candidateArch" = "$3" ]; then
				echo "$candidatePath" >> /tmp/appx/install_list.txt
				foundDependencyAlready=1
				break
			fi

			if [ "$candidateArch" = "neutral" ] || [ "$candidateArch" = "$3" ]; then
				candidateVersion="$(printf "%s" "$(basename "$candidatePath")" | cut -d '_' -f 1)"
				#check candidate version is between max and min exclusive
				if { echo "$candidateVersion"; echo "$6"; } | sort --version-sort --check; then
					if { echo "$candidateVersion"; echo "$versionToCheck"; } | sort --version-sort --check; then
						echo "$candidatePath" >> /tmp/appx/install_list.txt
						foundDependencyAlready=1
						break
					fi
				fi
			fi	
		done
	fi

	export IFS="${old_IFS}"

	if [ "$foundDependencyAlready" = "0" ]; then
		echo "===Dependency not satisfied exiting!==="
		echo "DEPENDENCY: $4"
		echo "DEP_ARCH: $3"
		echo "VERSION: $5"
		echo "SCALE: $6"
		echo "WINEHOME: $1"
		echo "APPX: $2" 
		echo
		cleanupAndExit
	fi
}

printTag()
{
	positions="$(findTag "${1}" "${2}" "${3}")"
	printf "%s" "${1}" | cut -z -c $(printf "%s" "${positions}" | sed "s/\x0$//g" | cut -d ':' -f 1)-$(printf "%s" "${positions}" | cut -d ':' -f 2)
}

processappx()
{
	cp -a "$PWD" "${1}/drive_c/Program Files/WindowsApps"
}

#argv[1] appx file or directory of appx files

if [ -d "/tmp/appx" ]; then
	rm -rf /tmp/appx
fi

if [ "$WINEHOME" = "" ]; then
	WINEHOME="${HOME}/.wine"
fi
mkdir -p "${WINEHOME}/drive_c/Program Files/WindowsApps"


thepwd="$(dirname "$(realpath "$0")")"

theArch="x64"
theLanguage="EN-GB"

if [ -f "$1" ]; then

	pathofarchive="$(realpath "$1")"
echo $1

	if [ "$(printf "$1" "%s" | rev | cut -d '.' -f 1)" != "xppa" ] && [ "$(printf "$1" "%s" | rev | cut -d '.' -f 1)" != "xism" ]; then
		printf "Not an appx or msix file, exiting.\n"
		exit
	fi

	if ! [ -d "/tmp/appx" ]; then
		mkdir /tmp/appx
	fi

	mkdir "/tmp/appx/$(basename $1)"

	cd "/tmp/appx/$(basename $1)"

	if [ "$(printf "$1" "%s" | rev | cut -d '.' -f 1)" = "xppa" ]; then
		7z e "$pathofarchive"
	elif [ "$(printf "$1" "%s" | rev | cut -d '.' -f 1)" = "xism" ]; then
		unzip "$pathofarchive"
	fi

	appxbundlemanifest=""
	appxmanifest="$(find "$PWD" -type f -name AppxManifest.xml | head -n 1)"

	if ! [ -f "$appxmanifest" ]; then
		appxbundlemanifest="$(find "$PWD" -type f -name "AppxBundleManifest.xml" | head -n 1)"
		if ! [ -f "$appxbundlemanifest" ]; then
			printf "Could not find AppxManifest.xml or AppxBundleManifest.xml within archive, exiting.\n"
			exit
		else
			#appxbundlemanifest

			packageBlock="$(printTag "$(cat "$appxmanifest")" "Package" "")"
			identityTag="$(printTag "${packageBlock}" "Identity")"
			nameTag="$(printf "%s" "${identityTag}" | grep -o "Name=\".*" | cut -d '"' -f 2)"

			if [ "$nameTag" != "" ]; then
	
				versionTag="$(printf "%s" "${identityTag}" | grep -o "Version=\".*" | cut -d '"' -f 2)"

				if [ "$versionTag" != "" ]; then


					old_IFS="$IFS"
					IFS='<'
					readIndex=0
					appxFilename=""
					appxScale=""
					passLanguage=1
					printf "%s" packageBlock | while read line; do
						#read packages tag if it exists
						if [ "$(printf "%s\n" "$line" | grep "<\s*Package.*>")" != "" ] && [ "$readIndex" = "0" ]; then
							#check packages tag is of Type "Application"
							if [ "$(printf "%s\n" "$line" | grep "<.*\s*Type=\"Application\" .*>")" != "" ]; then
								#check packages architecture is the same as theArch
								if [ "$(printf "%s\n" "$line" | grep "<.*\s*Architecture=\"${theArch}\" .*>")" != "" ]; then
									appxFilename="$(printf "%s\n" "$line" | grep -Po "FileName=\".*?\"")"
									readIndex="1"
								fi
							fi
						elif [ "$(printf "%s\n" "$line" | grep "<\s*Resources.*>")" != "" ] && ( [ "$readIndex" = 1 ] || [ "$readIndex" = 3 ] ); then
							if [ "$appxFilename" != "" ]; then
								readIndex=2
							fi
						elif [ "$(printf "%s\n" "$line" | grep "<\s*Resource.*>")" != "" ] && [ "$readIndex" = 2 ]; then
							if [ "$appxFilename" != "" ]; then
								appxLanguage="$(printf "%s\n" "$line" | grep -Po "Language=\"${theLanguage}\"")"
								if [ "$passLanguage" = "1" ] && [ "$appxLanguage" = "" ]; then
									passLanguage=0
								elif [ "$appxLanguage" != "" ]; then
									passLanguage=2
								fi
	
								readScale="$(printf "%s\n" "$line" | grep -Po "Scale=\".?*\"")"
								if [ "$readScale" != "" ]; then
									appxScale="$(printf "%s" "$readScale" | cut -d '"' -f 2)"
								fi
							fi
						elif [ "$(printf "%s\n" "$line" | grep "<\s*Dependencies.*>")" != "" ] && ( [ "$readIndex" = 2 ] || [ "$readIndex" = 1 ] ); then
							if [ "$passLanguage" -gt 0 ] && [ "$appxFilename" != "" ]; then
								readIndex=3
							fi
						elif [ "$(printf "%s\n" "$line" | grep "<\s*PackageDependency.*>")" != "" ] && [ "$readIndex" = 3 ]; then
							if [ "$passLanguage" -gt 0 ] && [ "$appxFilename" != "" ]; then
								dependencyMinVer="$(printf "%s\n" "$line" | grep -Po "MinVersion=\".*?\"")"
								if [ "$dependencyMinVer" != "" ]; then
									dependencyMinVer="$(printf "%s" "$dependencyMinVer" | cut -d '"' -f 2)"
								fi
	
								dependencyMaxVer="$(printf "%s\n" "$line" | grep -Po "MaxVersion=\".*?\"")"
								if [ "$dependencyMaxVer" != "" ]; then
									dependencyMaxVer="$(printf "%s" "$dependencyMaxVer" | cut -d '"' -f 2)"
								fi
	
								dependencyName="$(printf "%s\n" "$line" | grep -Po "Name=\".*?\"")"
								if [ "$dependencyName" != "" ]; then
									dependencyName="$(printf "%s" "$dependencyName" | cut -d '"' -f 2)"
									if [ "$dependencyName" != "" ]; then
										echo "checkDependency "$WINEHOME" "$1" "$theArch" "$dependencyName" "$dependencyMinVer" "$dependencyMaxVer""
										checkDependency "$WINEHOME" "$1" "$theArch" "$dependencyName" "$dependencyMinVer" "$dependencyMaxVer" 
									fi
								fi
							fi
						elif [ "$(printf "%s\n" "$line" | grep "<\s*/\s*Dependencies.*>")" != "" ] && [ "$readIndex" = 3 ]; then
							#end tag
							readIndex=1
						elif [ "$(printf "%s\n" "$line" | grep "<\s*/\s*Resources.*>")" != "" ] && [ "$readIndex" = 2 ]; then
							#end tag
							readIndex=1
						elif [ "$(printf "%s\n" "$line" | grep "<\s*/\s*Package.*>")" != "" ] && [ "$readIndex" = "1" ]; then
							if [ "$passLanguage" -gt 0 ] && [ "$appxFilename" != "" ]; then
								echo "TODO: process appx"
								echo "processappx "$WINEHOME" "$PWD" "$appxFilename" "$nameTag" "$versionTag" "$appxScale""
							fi
							readIndex=0
							appxFilename=""
							appxScale=""
							passLanguage=1
						fi

					done
					IFS="$old_IFS"
				fi
			fi
		fi

		echo "/tmp/appx/$(basename "$1")" >> /tmp/appx/install_list.txt

		#TODO: process install_list.txt
	else
	#appxmanifest

		packageBlock="$(printTag "$(cat "$appxmanifest")" "Package" "")"
		identityTag="$(printTag "${packageBlock}" "Identity")"
		nameTag="$(printf "%s" "${identityTag}" | grep -o "Name=\".*" | cut -d '"' -f 2)"
		if [ "$nameTag" != "" ]; then

			versionTag="$(printf "%s" "${identityTag}" | grep -o "Version=\".*" | cut -d '"' -f 2)"

			if [ "$versionTag" != "" ]; then


				dependenciesBlock="$(printTag "$packageBlock" "Dependencies" "")"

				old_IFS="$IFS"
				IFS='<'
				printf "%s" "${dependenciesBlock}" | while read line; do
					if [ "$(printf "%s\n" "$line" | grep "<\s*PackageDependency.*>")" != "" ]; then

						dependencyMinVer="$(printf "%s\n" "$line" | grep -Po "MinVersion=\".*?\"")"
						if [ "$dependencyMinVer" != "" ]; then
							dependencyMinVer="$(printf "%s" "$dependencyMinVer" | cut -d '"' -f 2)"
						fi
	
						dependencyMaxVer="$(printf "%s\n" "$line" | grep -Po "MaxVersion=\".*?\"")"
						if [ "$dependencyMaxVer" != "" ]; then
							dependencyMaxVer="$(printf "%s" "$dependencyMaxVer" | cut -d '"' -f 2)"
						fi
	
						dependencyName="$(printf "%s\n" "$line" | grep -Po "Name=\".*?\"")"
						if [ "$dependencyName" != "" ]; then
							dependencyName="$(printf "%s" "$dependencyName" | cut -d '"' -f 2)"
							if [ "$dependencyName" != "" ]; then
								echo "checkDependency "$WINEHOME" "$1" "$theArch" "$dependencyName" "$dependencyMinVer" "$dependencyMaxVer""
								checkDependency "$WINEHOME" "$1" "$theArch" "$dependencyName" "$dependencyMinVer" "$dependencyMaxVer" 
							fi
						fi
					fi
				done

				IFS="$old_IFS"
			fi
		fi
		echo "/tmp/appx/$(basename "$1")" >> /tmp/appx/install_list.txt

		#TODO: process install_list.txt

	fi

	process_install_list "$WINEHOME" "${thepwd}"

elif [ -d "$1" ]; then
	echo
	process_install_list "$WINEHOME" "${thepwd}"

else
	printf "argv[1]: appx file to install or directory of appx files\n"
fi

umask "${OLD_UMASK}"

cleanupAndExit
