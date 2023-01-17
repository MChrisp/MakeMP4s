#!/bin/bash

# Function for transcoding. Argument position: 1: Original File location 2: Directory for transcoded movie 3: resolution width in pixel (e.g. 1920 or 3840) 4: resolution string (e.g. 1080p)
transcode(){
  #Prep Transcode
    #LOGS
    trans_log="${log_dir_movie_date}/${title}${teststring} - ${4}_transcode.log"
    touch "${trans_log}"
    echo "Title: ${title}" >> "${trans_log}"
    echo "Log for: ${current_date_time}" >> "${trans_log}"

    #Outputpath
    trans_movie="${2}/${title}${teststring} - ${4}.mp4"

    if [[ ${trans_movie} ]]; then
      tr_mov_existed="true"
      echo -e "${ORANGE}Transcoded movie in resolution ${3}x${4} found, scipping.${NOCOLOR}"
    else
      tr_mov_existed="false"
    fi
  #Transcode
  if [[ $tr_mov_existed == "false" ]] || [[ ${overwrite} == "true" ]]; then

    echo -e "${ORANGE}Transcoding starts now.${NOCOLOR}"
    HandBrakeCLI -i "${1}" --stop-at "${stop_at_f}" -o "${trans_movie}" -m -O -e nvenc_h265_10bit --encoder-preset "${enc_speed}" -q "${enc_q}" --width ${3} --audio-lang-list "deu,eng" --all-audio -E aac -6 "7point1" -Q 5 --loose-anamorphic --modulus 2 2>&1 | tee -a "${trans_log}"
  fi

  # Set transcoded DV Movie string for Dolby Vision Extraction in next step
  trans_movie_DV="${target_dir_movie}/${title}${teststring} - DV${4}.mp4"

  if [[ $(grep "Encode done!" "${trans_log}") ]] || [[ ${tr_mov_existed} == "true" ]]; then
    if [[ $(grep "Encode done!" "${trans_log}") ]]; then
      echo -e "${ORANGE}Transcoding in resolution ${3}x${4}  is done.${NOCOLOR}"
      echo "Transcoding in resolution ${3}x${4} is done." >> "${gen_log}"
    elif [[ ${tr_mov_existed} == "true" ]]; then
      echo -e "${ORANGE}Movie in resolution ${3}x${4} was already present. If you have trouble, delete this ${trans_log} and try again. Or try config overwrite='true'${NOCOLOR}"
      echo "Movie in resolution ${3}x${4}  was already present. If you have trouble, delete this ${trans_log} and try again. Or try config overwrite='true'" >> "${gen_log}"
    fi
    if [[ ${3} == "1920" ]] && [[ ${only_orig_res} == "true" ]]; then
      succ_str="${succ_str:0:2}1${succ_str:3}"
      succ_str="${succ_str:0:3}3${succ_str:4}"
    elif [[ ! ${3} == "1920" ]] && [[ ${only_orig_res} == "true" ]] ; then
      succ_str="${succ_str:0:2}3${succ_str:3}"
      succ_str="${succ_str:0:3}1${succ_str:4}"
    elif [[ ! ${3} == "1920" ]] && [[ ! ${only_orig_res} == "true" ]] ; then
      succ_str="${succ_str:0:3}1${succ_str:4}"
    else
      succ_str="${succ_str:0:2}1${succ_str:3}"
    fi
  else
    echo -e "${ORANGE}Transcoding in resolution ${3}x${4} failed. Check logs in ${trans_log}${NOCOLOR}"
    echo "Transcoding in resolution ${3}x${4} failed. Check logs in ${trans_log}" >> "${gen_log}"
    if [[ ${3} == "1920" ]] && [[ ${only_orig_res} == "true" ]]; then
      succ_str="${succ_str:0:2}2${succ_str:3}"
      succ_str="${succ_str:0:3}3${succ_str:4}"
    elif [[ ! ${3} == "1920" ]] && [[ ${only_orig_res} == "true" ]] ; then
      succ_str="${succ_str:0:2}3${succ_str:3}"
      succ_str="${succ_str:0:3}2${succ_str:4}"
    elif [[ ! ${3} == "1920" ]] && [[ ! ${only_orig_res} == "true" ]] ; then
      succ_str="${succ_str:0:3}2${succ_str:4}"
    else
      succ_str="${succ_str:0:2}2${succ_str:3}"
    fi
  fi
}
# Function for extracting RPU. Argument position: 1. Original MKV File with DV metadata 2. Target resolution width in pixel
extract_RPU(){
if [[ ${doDV} == "true" ]]; then
echo -e "${ORANGE}Dolby Vision detected.${NOCOLOR}"

# Get the Dolby Vision Type. Is not actually necessary to make it work.
DV_Meta_String=$(mediainfo --Output=Video\;%HDR_Format% "$1")

# Set path for RPU.bin
rpu_file="${working_dir_movie}/${title}${teststring}_RPU.bin"
  if [[ -f ${rpu_file} ]]; then
    rpu_existed="true"
  else
    rpu_existed="false"
  fi

  if [[ -f ${trans_movie_DV} ]]; then
    trans_movie_DV_existed="true"
  else
    trans_movie_DV_existed="false"
  fi

  if ([[ ${trans_movie_DV_existed} == "false" ]] && [[ ${rpu_existed} == "false" ]]) || [[ ${overwrite} == "true" ]]; then
      # Set path for original.hevc
      orig_video_stream="${working_dir_movie}/${title}${teststring}_raw.hevc"
      # Prepare log
      DV_dovi_extract_log="${log_dir_movie_date}/${title}_RPU_extract.log"
      touch "${DV_dovi_extract_log}"
      echo "Title: ${title}" >> "${DV_dovi_extract_log}"
      echo "Log for: ${current_date_time}" >> "${DV_dovi_extract_log}"
      DV_ffmpeg_extract_log="${log_dir_movie_date}/${title}_orig_extract.log"
      touch "${DV_ffmpeg_extract_log}"
      echo "Title: ${title}" >> "${DV_ffmpeg_extract_log}"
      echo "Log for: ${current_date_time}" >> "${DV_ffmpeg_extract_log}"

      # Extract RPU
      ffmpeg -y -i "${orig_file}" -c:v:0 copy -frames:v:0 "${stop_at_ffmpeg_f}" -vbsf hevc_mp4toannexb -f hevc - 2> "${DV_ffmpeg_extract_log}" | dovi_tool  -m 2 -c --drop-hdr10plus extract-rpu - -o "${rpu_file}" 2>&1 | tee -a "${DV_dovi_extract_log}"
  fi

  if [[ $(grep "Reordering metadata... Done." "${DV_dovi_extract_log}") ]] || [[ ${rpu_existed} == "true" ]]; then

    if [[ ${rpu_existed} == "true" ]]; then
      echo -e "${ORANGE}Dolby Vision metadata already existed. If you have trouble, delete this ${rpu_file} or ${trans_movie_DV} and try again. Or try config overwrite='true'${NOCOLOR}"
      echo "Dolby Vision metadata already existed. If you have trouble, delete this ${rpu_file} or ${trans_movie_DV} and try again. Or try config overwrite='true'" >> "${gen_log}"
    elif [[ $(grep "Reordering metadata... Done." "${DV_dovi_extract_log}") ]]; then
      echo -e "${ORANGE}Dolby Vision metadata was succesfully extracted.${NOCOLOR}"
      echo "Dolby Vision metadata was succesfully extracted." >> "${gen_log}"
    fi

    succ_str="${succ_str:0:4}1${succ_str:5}"
  elif [[ ${trans_movie_DV_existed} == "true" ]]; then
      echo -e "${ORANGE}Dolby Vision Movie already existed. If you have trouble, delete this ${trans_movie_DV} and try again. Or try config overwrite='true'${NOCOLOR}"
      echo "Dolby Vision Movie already existed. If you have trouble, delete this ${trans_movie_DV} and try again. Or try config overwrite='true'" >> "${gen_log}"
      succ_str="${succ_str:0:4}3${succ_str:5}"
  else
    echo -e "${ORANGE}Dolby Vision metadata extraction failed. Check logs: ${DV_dovi_extract_log}${NOCOLOR}"
    echo "Dolby Vision metadata extraction failed. Check logs: ${DV_dovi_extract_log}" >> "${gen_log}"
    succ_str="${succ_str:0:4}2${succ_str:5}"
  fi
elif [[ ! $(mediainfo --Output=Video\;%HDR_Format% "${orig_file}" | grep "Dolby Vision") ]];
  echo -e "${ORANGE}Dolby Vision conversion not not needed.${NOCOLOR}"
  echo "Dolby Vision conversion not not needed." >> "${gen_log}"
  succ_str="${succ_str:0:4}3${succ_str:5}"
else
  echo -e "${ORANGE}Dolby Vision conversion possible but not selected. Change config if you want conversion to happen.${NOCOLOR}"
  echo "Dolby Vision conversion possible but not selected. Change config if you want conversion to happen." >> "${gen_log}"
  succ_str="${succ_str:0:4}3${succ_str:5}"
fi
}

# Function for injection RPU Metadata. Argument position: 1: Transcoded file location 2: Resolution-String (e.g. 1080p) 3: rpu-file 4: resolution width in pixel
inject_RPU(){

    # Prepare Logs:
    DV_mux_log="${log_dir_movie_date}/${title}${teststring} - ${2}_mux.log"
    touch "${DV_mux_log}"
    echo "Title: ${title}" >> "${DV_mux_log}"
    echo "Log for: ${current_date_time}" >> "${DV_mux_log}"

    # Set Paths for the Videostreamfiles in working directory
    vidbitstr_file="${working_dir_movie}/${title}${teststring} - ${2}.hevc"
    vidbitstr_DV_file="${working_dir_movie}/${title}${teststring} - DV${2}.hevc"

    # Set Paths for Dolby Vision movie
    trans_movie_DV="${target_dir_movie}/${title}${teststring} - DV${2}.mp4"

    echo "Input Vars: ${trans_movie} ${res_str} ${rpu_file} ${res_width}" >> "${DV_mux_log}"
  # Check which files are already existing
  if [[ -f ${vidbitstr_file} ]]; then
    vidbitstr_file_existed="true"
  else
    vidbitstr_file_existed="false"
  fi
  if [[ -f ${vidbitstr_DV_file} ]]; then
    vidbitstr_DV_file_existed="true"
  else
    vidbitstr_DV_file_existed="false"
  fi

  if [[ -f ${trans_movie_DV} ]]; then
    trans_movie_DV_existed="true"
  else
    trans_movie_DV_existed="false"
  fi

    #Demux Transcoded Video from MP4 hand over to dovi and inject rpu and remux everything together
  if ([[ ${vidbitstr_file_existed} == "false" ]] && [[ ${vidbitstr_DV_file_existed} == "false" ]] && [[ ${trans_movie_DV_existed} == "false" ]]) || [[ ${overwrite} == "true" ]]; then

    echo -e "${ORANGE}Starting extraction of Video Bitstream of Transcoded MP4.${NOCOLOR}"
    echo "Starting extraction of Video Bitstream of Transcoded MP4." >> "${gen_log}"

    ffmpeg -y -i "${1}" -vcodec copy -vbsf hevc_mp4toannexb -f hevc "${vidbitstr_file}" 2>> "${DV_mux_log}"

    if [[ $? -eq 0 ]]; then
      echo -e "${ORANGE}Extraction of Video Bitstream of Transcoded MP4 was successfull.${NOCOLOR}"
      echo "Extraction of Video Bitstream of Transcoded MP4 was successfull." >> "${DV_mux_log}"
    else
      echo -e "${ORANGE}Extraction of Video Bitstream of Transcoded MP4 failed.${NOCOLOR}"
      echo "Extraction of Video Bitstream of Transcoded MP4 failed." >> "${DV_mux_log}"
    fi
  elif [[ ${vidbitstr_file_existed} == "true" ]]; then
    echo -e "${ORANGE}Video Bitstream of Transcoded MP4 already existed. If you have trouble, delete this ${vidbitstr_file} and try again. Or try config overwrite='true'${NOCOLOR}"
    echo "Video Bitstream of Transcoded MP4 already existed. If you have trouble, delete this ${vidbitstr_file} and try again. Or try config overwrite='true'" >> "${gen_log}"
  fi


  if ([[ ${vidbitstr_DV_file_existed} == "false" ]] && [[ ${trans_movie_DV_existed} == "false" ]]) || [[ ${overwrite} == "true" ]]; then

    echo -e "${ORANGE}Starting injection of RPU in Video Bitstream of Transcoded MP4.${NOCOLOR}"
    echo "Starting injection of RPU in Video Bitstream of Transcoded MP4." >> "${gen_log}"

    dovi_tool inject-rpu -i "${vidbitstr_file}" --rpu-in "${3}" -o "${vidbitstr_DV_file}" 2>> "${DV_mux_log}"
    if [[ $? -eq 0 ]]; then
      echo -e "${ORANGE}Injection of Video Bitstream of Transcoded MP4 was successfull.${NOCOLOR}"
      echo "Injection of Video Bitstream of Transcoded MP4 was successfull." >> "${DV_mux_log}"
    else
      echo -e "${ORANGE}Injection of Video Bitstream of Transcoded MP4 failed.${NOCOLOR}"
      echo "Injection of Video Bitstream of Transcoded MP4 failed." >> "${DV_mux_log}"
    fi
  elif [[ ${vidbitstr_DV_file_existed} == "true" ]]; then
    echo -e "${ORANGE}Video Bitstream with Dolby Vision already existed. If you have trouble, delete this ${vidbitstr_DV_file} and try again. Or try config overwrite='true'${NOCOLOR}"
    echo "Video Bitstream with Dolby Vision already existed. If you have trouble, delete this ${vidbitstr_DV_file} and try again. Or try config overwrite='true'" >> "${gen_log}"
  fi

  if [[ ${trans_movie_DV_existed} == "false" ]] || [[ ${overwrite} == "true" ]]; then

    echo -e "${ORANGE}Starting Remuxing of DV bitstream and original audio from MP4.${NOCOLOR}"
    echo "Starting Remuxing of DV bitstream and original audio from MP4." >> "${gen_log}"

    ffmpeg -y -i "${1}" -i "${vidbitstr_DV_file}" -map 1:v -map 0:a -c copy  -movflags +faststart "${trans_movie_DV}" 2>> "${DV_mux_log}"
    if [[ $? -eq 0 ]] || [[ ${trans_movie_DV_existed} == "true" ]]; then
      if [[ $? -eq 0 ]]; then
        echo -e "${ORANGE}Muxing of DV MP4 was successfull.${NOCOLOR}"
        echo "Muxing of DV MP4 was successfull." >> "${DV_mux_log}"
      elif [[ ${trans_movie_DV_existed} == "true" ]]; then
        echo -e "${ORANGE}Dolby Vision Version of Movie already existed. If you have trouble, delete this ${trans_movie_DV} and try again. Or try config overwrite='true'${NOCOLOR}"
        echo "Dolby Vision Version of Movie already existed. If you have trouble, delete this ${trans_movie_DV} and try again. Or try config overwrite='true'" >> "${gen_log}"
      fi
      if [[ ${4} == "1920" ]] && [[ ${only_orig_res} == "true" ]]; then
        succ_str="${succ_str:0:5}1${succ_str:6}"
        succ_str="${succ_str:0:6}3${succ_str:7}"
      elif [[ ! ${4} == "1920" ]] && [[ ${only_orig_res} == "true" ]] ; then
        succ_str="${succ_str:0:5}3${succ_str:6}"
        succ_str="${succ_str:0:6}1${succ_str:7}"
      elif [[ ! ${4} == "1920" ]] && [[ ! ${only_orig_res} == "true" ]] ; then
        succ_str="${succ_str:0:6}1${succ_str:7}"
      else
        succ_str="${succ_str:0:5}1${succ_str:6}"
      fi
    else
      echo -e "${ORANGE}Muxing of DV MP4 failed.${NOCOLOR}"
      echo "Muxing of DV MP4 failed." >> "${DV_mux_log}"
      if [[ ${4} == "1920" ]] && [[ ${only_orig_res} == "true" ]]; then
        succ_str="${succ_str:0:5}2${succ_str:6}"
        succ_str="${succ_str:0:6}3${succ_str:7}"
      elif [[ ! ${4} == "1920" ]] && [[ ${only_orig_res} == "true" ]] ; then
        succ_str="${succ_str:0:5}3${succ_str:6}"
        succ_str="${succ_str:0:6}2${succ_str:7}"
      elif [[ ! ${4} == "1920" ]] && [[ ! ${only_orig_res} == "true" ]] ; then
        succ_str="${succ_str:0:6}2${succ_str:7}"
      else
        succ_str="${succ_str:0:5}2${succ_str:6}"
      fi
    fi
  fi
}


ORANGE='\033[35;1m'
NOCOLOR='\033[0m'

echo -e "${ORANGE}You script is located in: $(dirname $0)"
if [[ ! -f "$(dirname $0)/MakeMP4s.conf" ]]; then
  echo -e "Could not find MakeMP4s.conf in  $(dirname $0) Please provide a path: "

  read confdir

else
  confdir="$(dirname $0)/MakeMP4s.conf"
fi

# Read configuration orig_file
source "${confdir}"

  if [ $test == "true" ]; then
    teststring=" - test"
  else
    teststring=
  fi

echo -e "All .mkv .mp4 .m4v files in ${source_dir} will be transcoded."
echo -e "But the following filter will be applied: $filter"
echo -e "Override is: ${overwrite} - When true, every movie and/or temp file will be overwritten. If false, it will skip already existing files."
echo -e "All transcoded files will go to: ${target_dir}"
echo -e "The working directory for temp files is: ${working_dir}"
echo -e "The encoder is: ${encoder}"
echo -e "The speed of encoder is: ${enc_speed}"
echo -e "The quality of encoder is: ${enc_q}"
echo -e "Dolby Vision Conversion: ${dov}"
echo -e "Only original resolution mode: ${only_orig_res} - True will not create an FHD Version."
echo -e "Test Run Mode is ${test} - True only converts to minute 3 of a movie. Files will be marked with '_test'."
echo -e "Cleanup state is: ${cleanup} - True will delete all tmp files, such as video bitstream and RPU DV Metadata."
echo -e "Only DV Version is: ${onlyDVmovie} - True will remove transcoded movie version without Dolby Vision."
echo -e "Only DV Injection is: ${onlyDV} - True will not transcode. Usefull when you have mp4s with non DV metadata but the original .mkv available. File locations will have to be exactly as this script would put it."
echo -e "Log will be stored in: ${logdir}"
echo -e "Ignore success state of input files: ${ignore_succ}"
echo -e "Reset success state of (filtered) input files: ${reset_succ}"
echo -e "Here is a List of all files you selected:${NOCOLOR}"


shopt -s nullglob
for orig_file in $source_dir/*.{mkv,mp4,m4v}; do
  # Reset success states

    orig_file_new="$(echo "${orig_file}" | sed 's/\(.*\)_-.*-_\(.*\)/\1\2/')"
    if [[ "${orig_file}" != "${orig_file_new}" ]]; then
      mv "${orig_file}" "${orig_file_new}"
      orig_file="${orig_file_new}"
      orig_file_new=
    fi

  # Delete Test string
  orig_file_new=${orig_file/" - test"/}
    if [[ "${orig_file}" != "${orig_file_new}" ]]; then
      mv "${orig_file}" "${orig_file_new}"
      orig_file="${orig_file_new}"
      orig_file_new=
    fi
done

shopt -s nullglob
for orig_file in $source_dir/*.{mkv,mp4,m4v}; do
  # Check if orig_file has already been processed and filter according to user input
  if [[ ${orig_file} = *"${filter}"* ]] || ([[ -z "${teststring}" ]] && [[ ${orig_file} = *"${filter}"* ]] && [[ ${orig_file} = *"_test"* ]]); then
    echo $orig_file
  fi
done

echo -e "${ORANGE}If you are not happy with this config, change the config file: ${confdir}"

echo -e "Do you want to continue? (yes/no)${NOCOLOR}"
read user_input


if [ $user_input == "yes" -o $user_input == "y" ]; then
    echo -e "Continuing..."
else
    if [ $user_input == "no" -o $user_input == "n" ] ; then
        echo -e "Exiting..."
        exit
    else
        echo -e "Invalid Input, Exiting..."
        exit
    fi
fi

shopt -s nullglob
for orig_file in $source_dir/*.{mkv,mp4,m4v}; do
  # Check if orig_file has already been processed and filter according to user input
  if [[ ${orig_file} = *"${filter}"* ]] || ([[ -z "${teststring}" ]] && [[ ${orig_file} = *"${filter}"* ]] && [[ ${orig_file} = *"_test"* ]]); then
    echo $orig_file

    # Set current Date/time
    current_date_time=$(date +"%Y%m%d_%H%M%S")

    echo -e "${ORANGE}Doing file ${orig_file}${NOCOLOR}"

    #(Re)set Variables
    trans_log=
    extract_success=
    trans_movie=
    rpu_file=
    DV_Meta_String=
    trans_movie_DV=
    succ_str="_-00000-_"
    # Status for original file explanation: Status will be put at the end of the original filename. It contains 5 digits. 0 indicates not set, 1 Indicates success, 2 indicates failure, 3 indicates not applicable. The order of the status are: Transcode in original resolution; Transcode in FHD Resolution; RPU Extract; RPU inject original Resolution; RPU inject in FHD Resolution. e.g. for full success: _-11111-_

    # Get movie title from orig_file name
    title=$(basename "${orig_file}")
    title="${title%.*}"

    # Create subdirectories for movie
    mkdir "${working_dir}" -v
    working_dir_movie="${working_dir}/${title}"
    mkdir "${working_dir_movie}" -v

    mkdir "${target_dir}" -v
    target_dir_movie="${target_dir}/${title}"
    mkdir "${target_dir_movie}" -v

    mkdir "${log_dir}" -v
    log_dir_movie="${log_dir}/${title}"
    mkdir "${log_dir_movie}" -v

    log_dir_movie_date="${log_dir_movie}/${current_date_time}"
    mkdir "${log_dir_movie_date}" -v

    # Prepare general logfile

    gen_log="${log_dir_movie_date}/${title}.log"
    touch "${gen_log}"
    echo "Title: ${title}" >> "${gen_log}"
    echo "Log for: ${current_date_time}" >> "${gen_log}"
    cat $confdir >> "${gen_log}"

    # Get movie length. Necessary because test mode requires a specified stop at for HandBrakeCLi and ffmpeg. Cannot be NULL.
    movie_len=$(mediainfo --Output=General\;%Duration% "${orig_file}")
    movie_len_s=$((${movie_len}/1000))
    movie_len_f=$(mediainfo --Output="Video;%FrameCount%" "${orig_file}")

    # Set stop at according to config
    if [ $test == "true" ]; then
      stop_at_f="frames:4320"
      stop_at_ffmpeg_f="4320"
    else
      stop_at_f="frames:${movie_len_f}"
      stop_at_ffmpeg_f=$movie_len_f
    fi

    # Get resolution of orig_file using mediainfo
    resolution=$(mediainfo --Output=Video\;%Width%x%Height% "${orig_file}")
    res_width=$(cut -d x -f 1 <<< $resolution)
    res_height=$(cut -d x -f 2 <<< $resolution)


    echo -e "${ORANGE}Title of movie is: ${title}${NOCOLOR}"

    sleep 1

    #Set doDV for later if statement, so only DV Movies will get metadata extracted
    if [[ ${dov} == "true" ]] && [[ $(mediainfo --Output=Video\;%HDR_Format% "${orig_file}" | grep "Dolby Vision") ]]; then
      doDV=true
    else
      doDV=false
    fi




    # Set resolution string for filename in orig resolution
    res_str=${res_height}"p"

    # Transcode file to mp4
    if [[ ${only_DV} != "true" ]]; then

      transcode "${orig_file}" "${target_dir_movie}" "${res_width}" "${res_str}"

    fi

    echo -e "${ORANGE} Transcode movie ${title} in ${res_str} Successstate: ${succ_str}${NOCOLOR}"

    sleep 1

    # extract DV metadate if needed/specified
    if [[ ${succ_str:2:1} == "1" ]] || [[ ${succ_str:3:1} == "1" ]]; then

      extract_RPU "${orig_file}"

    fi

    # inject DV metadate
    if ([[ ${succ_str:4:1} == "1" ]] || [[ ${succ_str:4:1} == "3" ]]) && [[ ${doDV} == "true" ]]; then

      inject_RPU "${trans_movie}" "${res_str}" "${rpu_file}" "${res_width}"

    fi

    # Delete non DV Version
    if [[ ${onlyDVmovie} == "true" ]]; then
      echo -e "${ORANGE}Deleting non DV Movie:${NOCOLOR}"
      rm "${trans_movie}" -v
    else
      echo -e "${ORANGE}Keeping non DV Movie Version.${NOCOLOR}"
    fi

    # Now do all of this again in FHD. DV Metadata RPU of UHD Version is identical, so no new extraction necessary
    if [[ ${res_width} -gt 1920 ]] && [[ ${only_orig_res} != "true" ]] && [[ ${succ_str:3:1} == "1" ]]; then

      # Reset Variables
      trans_log=
      # Transcode file to mp4
      if [[ ${only_DV} != "true" ]]; then

        transcode "${orig_file}" "${target_dir_movie}" "1920" "1080p"

      fi

      echo -e "${ORANGE} Transcode movie ${title} in ${res_str} Successstate: ${succ_str}${NOCOLOR}"

      sleep 1

      # extract DV metadate if needed/specified
      if [[ ${succ_str:2:1} == "1" ]] || [[ ${succ_str:3:1} == "1" ]]; then

        extract_RPU "${orig_file}"

      fi

      # inject DV metadate
      if [[ ${succ_str:4:1} == "1" ]]; then

        inject_RPU "${trans_movie}" "1080p" "${rpu_file}" "1920"

      fi

      # Delete non DV Version
      if [[ ${onlyDVmovie} == "true" ]] && [[ $doDV == "true" ]]; then
        echo -e "${ORANGE}Deleting non DV Movie:${NOCOLOR}"
        rm "${trans_movie}" -v
      else
        echo -e "${ORANGE}Keeping non DV Movie Version.${NOCOLOR}"
      fi
    fi

    # Delete tmp files
    if [[ ${cleanup} == "true" ]]; then
      echo -e "${ORANGE}Deleting tmp files:${NOCOLOR}"
      rm "${working_dir_movie}" -rv
    fi

    # Delete log files
    if [[ $succ_str =~ 2 ]] || [[ $keep_logs == "true" ]]; then
      echo -e "${ORANGE}Keeping all logs.${NOCOLOR}"
    else
      echo -e "${Orange}Deleting verbose logs:${NOCOLOR}"
      for log in "${log_dir_movie_date}/*.log"; do
        if [[ ! "$log" == "$gen_log" ]]; then
          rm "$log" -v
        fi
      done
    fi

    # Change Filename of orig file, so status is visible in filename
    echo -e "${Orange}Renaming original source file to make state visible:${NOCOLOR}"

    mv "${orig_file}" "${orig_file%.*}${teststring}${succ_str}.mkv"
    orig_file="${orig_file%.*}${teststring}${succ_str}.mkv"


    echo -e "${ORANGE}Renamed original file to:${NOCOLOR}"
    echo "${orig_file}"
    echo -e "${ORANGE}${title} is done.${NOCOLOR}"

  else
    echo -e "${orig_file} was already transcoded or filtered"
  fi

done
