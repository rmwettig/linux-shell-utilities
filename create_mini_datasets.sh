#!/bin/bash
set -e

usage() {
  echo -e "Usage:\n" \
        "-d  data root directory\n" \
        "-s  pid sample size\n" \
        "-m  meta data root directory\n" \
        "-D  mini data output directory\n" \
        "-M  mini meta output directory\n" \
        "\n" \
        "Hint: Subfolders for databases and datasets are automatically created within root folders."
  exit 1
}

elementExists() {

    local array_elements=${1}[@]
    local needle=${2}

    for i in ${!array_elements} ; do
        if [[ $i == ${needle} ]] ; then
            return 0
        fi
    done
    return 1
}


declare -a DataBases=( "ADB" "FDB" )
declare -a DataSets=( "Bosch" "Energie-BKK"  "Mhplus" "Novitas" "1M_benchmark" )

if [[ $# -eq 0 ]]; then
  usage
fi

while getopts d:D:m:M:s: option 2> /dev/null
do
  case $option in
    d) dataRoot=($OPTARG);;
    s) sampleSize=($OPTARG);;
    m) metaDataDirectory=($OPTARG);;
    D) miniDataOutput=($OPTARG);;
    M) miniMetaOutput=($OPTARG);;
    ?) usage
  esac
done

# input paths must exist
[[ ! -d "$dataRoot" ]] && echo "Data root: $dataRoot does not exist" && exit 1
[[ ! -d "$metaDataDirectory" ]] && echo "Meta data root: $metaDataDirectory does not exist" && exit 1

[[ $sampleSize -lt 1 ]] && echo "Sample size must be a positive, non-zero value." && exit 1

# prepare output directories
[[ ! -d $miniDataOutput ]] && echo "Creating $miniDataOutput" && mkdir -p $miniDataOutput
[[ ! -d $miniMetaOutput ]] && echo "Creating $miniMetaOutput" && mkdir -p $miniMetaOutput

# for all databases
for db in $(ls $dataRoot); do
  dbRoot=$dataRoot/$db
  if ! elementExists DataBases ${db}; then
      echo "Not found: $dbRoot"
      continue
  fi
  if [[  ! -d $dbRoot ]]; then
      continue
  fi
  echo "Processing $dbRoot"
  # only process regular datasets, i.e. full size data
  datasets=$(ls $dbRoot | grep -v mini)
  for dataset in $datasets; do
    datasetDirectory="$dbRoot/$dataset"
    if ! elementExists DataSets ${dataset}; then
        echo -e "\tNot Found: $dataset"
        continue
    fi
    if [[ ! -d $datasetDirectory ]]; then
        continue
    fi
    echo -e "\tProcessing $dataset"
    pidListPath="$miniMetaOutput/pidlist.txt"
    echo -e "\t\tSampling $sampleSize pids"
    # extract the pid column
    cut -f 3 -d";" $datasetDirectory/ACC_${db}_AVK_${db}_T_Vers_Stamm.csv |
      # remove column header
      tail -n +2 |
      # take unique pids
      uniq |
      # sample the specified number of pids
      shuf -n $sampleSize > $pidListPath

    # create mini dataset directory
    miniDirectory="$miniDataOutput/$db/${dataset}_mini"
    [[ ! -d $miniDirectory ]] && mkdir -p $miniDirectory

    echo -e "\t\tExtracting data for selected pids"
    for f in $(ls $datasetDirectory | grep csv); do
      input="$datasetDirectory/$f"
      output="$miniDirectory/$f"
      head -n 1 $input > $output
      grep -f $pidListPath $input >> $output ||
        (echo -e "\t\t\tFailed to minify file: ${input}. Using whole file instead." &&
          tail -n +2 $input >> $output)
    done

    # FDB has no decoding file
    [[ "$db" == "FDB" ]] && continue

    # create a minified decoding file
    echo -e "\t\tExtracting mini decoding"
    miniMetaOut="$miniMetaOutput/$db/${dataset}_mini"
    # prepare preprocess output directory
    [[ ! -d $miniMetaOut ]] && mkdir -p "$miniMetaOut/bin_files"
    fullMetaData="$metaDataDirectory/$db/$dataset"
    fullDecoding=$(ls "$fullMetaData" | grep -e "^decoding_.*\.csv$")
    # go on if a dataset does not have a decoding file
    [[ ! -f "$fullMetaData/$fullDecoding" ]] &&
      echo -e "\t\t\tCould not find $fullMetaData/$fullDecoding. Skip decoding minification." &&
      continue
    miniDecoding="$miniMetaOut/$fullDecoding"
    head -n 1 "$fullMetaData/$fullDecoding" > "$miniDecoding"
    grep -f "$pidListPath" "$fullMetaData/$fullDecoding" >> "$miniDecoding"

    rm $pidListPath
  done
done
