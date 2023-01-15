#!/bin/bash

echo -e "You script is located in: $(dirname $0) - MakeMP4s.conf has the be in the same directory."

ORANGE='\033[35;1m'
NOCOLOR='\033[0m'

# Read configuration orig_file
source "$(dirname $0)/MakeMP4s.conf"

  if [ $test == "true" ]; then
    teststring="_test"
  fi

echo -e "${ORANGE}All .mkv-files in ${source_dir} will be transcoded."
echo -e "But the following filter will be applied: $filter"
echo -e "All transcoded files will go to: ${target_dir}"
echo -e "The working directory for temp files is: ${working_dir}"
echo -e "The encoder is: ${encoder}"
echo -e "The speed of encoder is: ${enc_speed}"
echo -e "The quality of encoder is: ${enc_q}"
echo -e "Dolby Vision Conversion: ${dov}"
echo -2 "Only original resolution mode: ${only_orig_res} - True will not create an FHD Version."
echo -e "Test Run Mode is ${test} - True only converts to minute 3 of a movie. Files will be marked with '_test'."
echo -e "Cleanup state is: ${cleanup} - True will delete all tmp files, such as video bitstream and RPU DV Metadata."
echo -e "Only DV Version is: ${onlyDV} - True will remove transcoded movie version without Dolby Vision."
echo -e "Log will be stored in: ${logdir}"
echo -e "Here is a List of all files you selected:${NOCOLOR}"

for orig_file in $source_dir/*.mkv; do
  # Check if orig_file has already been processed and filter according to user input
  if [[ ${orig_file} != *"${teststring}_done"*  ]] && [[ ${orig_file} = "${source_dir}"*"${filter}"* ]]; then
    echo $orig_file
  fi
done

echo -e "${ORANGE}If you are not happy with this config, change the config file: $(dirname $0)/MakeMP4s.conf"

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


for orig_file in $source_dir/*.mkv; do
  # Check if orig_file has already been processed and filter according to user input
  if [[ ${orig_file} != *"${teststring}_done"* ]] && [[ ${orig_file} = *"${filter}"* ]]; then
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

    echo -e "${ORANGE}Doing file ${orig_file}${NOCOLOR}"

    # Get movie title from orig_file name
    title=$(mediainfo --Output=General\;%Movie% "${orig_file}")

    echo -e "${ORANGE}Title of movie is: ${title}${NOCOLOR}"

    sleep 3

    # Get resolution of orig_file using mediainfo
    resolution=$(mediainfo --Output=Video\;%Width%x%Height% "${orig_file}")
    res_width=$(cut -d x -f 1 <<< $resolution)
    res_height=$(cut -d x -f 2 <<< $resolution)


    #Set doDV for later if statement, so only DV Movies will get metadata extracted
    if [[ ${dov} == "true" ]] && [[ $(mediainfo --Output=Video\;%HDR_Format% "${orig_file}" | grep "Dolby Vision") ]]; then
      doDV=true
    else
      doDV=false
    fi

    # Set current Date/time
    current_date_time=$(date +"%Y%m%d_%H%M%S")

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



    # Set paths for logfiles and create them
    trans_orig_log="${log_dir_movie_date}/${title}_transcode.log"
    touch "${trans_orig_log}"
    echo "Title: ${title}" >> "${trans_orig_log}"
    echo "Log for: ${current_date_time}" >> "${trans_orig_log}"

    DV_dovi_extract_log="${log_dir_movie_date}/${title}_RPU_extract.log"
    touch "${DV_dovi_extract_log}"
    echo "Title: ${title}" >> "${DV_dovi_extract_log}"
    echo "Log for: ${current_date_time}" >> "${DV_dovi_extract_log}"

    DV_ffmpeg_extract_log="${log_dir_movie_date}/${title}_orig_extract.log"
    touch "${DV_ffmpeg_extract_log}"
    echo "Title: ${title}" >>
    echo "Log for: ${current_date_time}" >> "${DV_ffmpeg_extract_log}"

    DV_orig_mux_log="${log_dir_movie_date}/${title}_mux.log"
    touch "${DV_orig_mux_log}"
    echo "Title: ${title}" >>
    echo "Log for: ${current_date_time}" >> "${DV_orig_mux_log}"

    gen_log="${log_dir_movie_date}/${title}.log"
    touch "${gen_log}"
    echo "Title: ${title}" >>
    echo "Log for: ${current_date_time}" >> "${gen_log}"

    # Use Handbrake to create .mp4 version with specified settings
    # Starting with original Resolution
    # Set resolution string for filename in orig resolution and set path
    res_str=${res_height}"p"
    trans_file="${target_dir_movie}/${title}${teststring} - ${res_str}.mp4"

    #Transcode
    echo -e "${ORANGE}Transcoding in Original resolution starts now.${NOCOLOR}"
    echo "${current_date_time}" >> "${trans_orig_log}"
    HandBrakeCLI -i "${orig_file}" --stop-at "${stop_at_f}" -o "${trans_file}" -m -O -e nvenc_h265_10bit --encoder-preset "${enc_speed}" -q "${enc_q}" --audio-lang-list "deu,eng" --all-audio -E aac -6 "7point1" -Q 5 --loose-anamorphic --modulus 2 2>&1 | tee -a "${trans_orig_log}"

    if [[ $(grep "Encode done!" "${trans_orig_log}") ]]; then
      echo -e "${ORANGE}Transcoding in original resolution done.${NOCOLOR}"
      echo "Transcoding in original resolution done." >> "${gen_log}"


      # extract DV metadate if needed/specified
      if [[ ${doDV} == "true" ]]; then
        echo -e "${ORANGE}Dolby Vision detected. Starting to extract RPU${NOCOLOR}"
        # Get the Dolby Vision Type. Is not actually necessary to make it work.
        DV_Meta_String=$(mediainfo --Output=Video\;%HDR_Format% "${orig_file}")
        # Specifying Directories
        rpu_file="${working_dir_movie}/${title}${teststring}_RPU.bin"
        orig_video_stream="${working_dir_movie}/${title}${teststring}_raw.hevc"
        trans_file_DV="${target_dir_movie}/${title}${teststring} - DV${res_str}.mp4"

        # Extract RPU
        ffmpeg -y -i "${orig_file}" -c:v:0 copy -frames:v:0 "${stop_at_ffmpeg_f}" -vbsf hevc_mp4toannexb -f hevc "${orig_video_stream}" 2> "${DV_ffmpeg_extract_log}"
        dovi_tool  -m 2 -c --drop-hdr10plus extract-rpu "${orig_video_stream}" -o "${rpu_file}" 2>&1 | tee -a "${DV_dovi_extract_log}"

        if [[ $(grep "Reordering metadata... Done." "${DV_dovi_extract_log}") ]]; then
          echo -e "${ORANGE}Dolby Vision metadata was succesfully extracted.${NOCOLOR}"
          echo "Dolby Vision metadata was succesfully extracted." >> "${gen_log}"
        else
          echo -e "${ORANGE}Dolby Vision metadata extraction failed. Check logs: ${DV_dovi_extract_log}${NOCOLOR}"
          echo "Dolby Vision metadata extraction failed. Check logs: ${DV_dovi_extract_log}" >> "${gen_log}"
        fi

        # Set Paths for the Videostreamfiles in working directory
        vidbitstr_file="${working_dir_movie}/${title}${teststring}.hevc"
        vidbitstr_DV_file="${working_dir_movie}/${title}${teststring}_DV.hevc"

        #Demux Transcoded Video from MP4 hand over to dovi and inject rpu and remux everything together
        echo -e "${ORANGE}Starting extraction of Video Bitstream of Transcoded MP4.${NOCOLOR}"
        ffmpeg -i "${trans_file}" -vcodec copy -vbsf hevc_mp4toannexb -f hevc -y "${vidbitstr_file}" 2>> "${DV_orig_mux_log}"

        echo -e "${ORANGE}Starting injection of RPU in Video Bitstream of Transcoded MP4.${NOCOLOR}"
        dovi_tool inject-rpu -i "${vidbitstr_file}" --rpu-in "${rpu_file}" -o "${vidbitstr_DV_file}" 2>> "${DV_orig_mux_log}"

        echo -e "${ORANGE}Starting Remuxing of DV bitstream and original audio from MP4.${NOCOLOR}"
        ffmpeg -i "${trans_file}" -i "${vidbitstr_DV_file}" -map 1:v -map 0:a -c copy -y "${trans_file_DV}" 2>> "${DV_orig_mux_log}"
      fi
    else
      echo -e "${ORANGE}Transcoding in original resolution failed. Check logs in ${trans_orig_log}${NOCOLOR}"
      echo "Transcoding in original resolution failed. Check logs in ${trans_orig_log}" >> "${gen_log}"
      orig_fail="true"
    fi

    # Now do all of this again in FHD. DV Metadata RPU of UHD Version is identical, so no new extraction necessary
    if [[ ${res_width} -gt 1920 ]] && [[ ${only_orig_res} != "true" ]] && [[ ${orig_fail != "true" } ]]; then

      # Set FHD path
      trans_FHD_file="${target_dir_movie}/${title}${teststring} - 1080p.mp4"

      # Create Log Files
      DV_FHD_mux_log="${log_dir_movie_date}/${title}_FHD_mux.log"
      touch "${DV_FHD_mux_log}"
      trans_FHD_log="${log_dir_movie_date}/${title}_FHD_transcode.log"
      touch "${trans_FHD_log}"

      #Transcode in FHD
      echo -e "${ORANGE}Transcoding in FHD resolution starts now.${NOCOLOR}"
      echo "${current_date_time}" >> "${trans_FHD_log}"
      HandBrakeCLI -i "${orig_file}" --stop-at "${stop_at_f}" -o "${trans_FHD_file}" -m -O -e nvenc_h265_10bit --encoder-preset "${enc_speed}" -q "${enc_q}" --width 1920 --audio-lang-list "deu,eng" --all-audio -E aac -6 "7point1" -Q 5 --loose-anamorphic --modulus 2 2>&1 | tee -a "${trans_FHD_log}"


      if [[ $(grep "Encode done!" "${trans_FHD_log}") ]]; then
        echo -e "${ORANGE}Transcoding in FHD resolution done.${NOCOLOR}"
        echo "Transcoding in FHD resolution done." >> "${gen_log}"

        if [[ ${doDV} == "true" ]]; then
          #Set all the paths for FHD Version
          trans_FHD_file_DV="${target_dir_movie}/${title}${teststring} - DV1080p.mp4"
          vidbitstr_FHD_file="${working_dir_movie}/${title}${teststring}_FHD.hevc"
          vidbitstr_FHD_DV_file="${working_dir_movie}/${title}${teststring}_FHD_DV.hevc"

          #Demux Transcoded Video from MP4 hand over to dovi and inject rpu and remux everything together
          echo -e "${ORANGE}Starting extraction of FHD Video Bitstream of Transcoded MP4.${NOCOLOR}"
          ffmpeg -i "${trans_FHD_file}" -vcodec copy -vbsf hevc_mp4toannexb -f hevc -y "${vidbitstr_FHD_file}" 2> "${DV_FHD_mux_log}"

          echo -e "${ORANGE}Starting injection of RPU in FHD Video Bitstream of Transcoded MP4.${NOCOLOR}"
          dovi_tool inject-rpu -i "${vidbitstr_FHD_file}" --rpu-in "${rpu_file}" -o "${vidbitstr_FHD_DV_file}" 2>&1 | tee -a  "${DV_FHD_mux_log}"

          echo -e "${ORANGE}Starting Remuxing of FHD DV bitstream and original audio from MP4.${NOCOLOR}"
          ffmpeg -i "${trans_FHD_file}" -i "${vidbitstr_FHD_DV_file}" -map 1:v -map 0:a -c copy -y "${trans_FHD_file_DV}" 2>> "${DV_FHD_mux_log}"
        fi
      else
        echo -e "${ORANGE}Transcoding in FHD resolution failed. Check logs in ${trans_FHD_log}${NOCOLOR}"
        echo "Transcoding in FHD resolution failed. Check logs in ${trans_FHD_log}" >> "${gen_log}"
      fi
    fi


    # Delete tmp files
    if [[ ${cleanup} == "true" ]]; then
      echo -e "${ORANGE}Deleting tmp files:${NOCOLOR}"
      rm "${working_dir_movie}" -rv
    fi

    # Delete non DV Version
    if [[ ${cleanup} == "true" ]]; then
      echo -e "${ORANGE}Deleting non DV Movie:${NOCOLOR}"
      rm "${trans_file}" -v
      if [[ ${res_width} -gt 1920 ]]; then
        rm "${trans_FHD_file}" -v
      fi
    fi

    # Change Filename of orig file, so status is visible in filename
    mv "${orig_file}" "${orig_file%.*}${teststring}_done.mkv"
    orig_file="${orig_file%.*}${teststring}_done.mkv"

    echo -e "${ORANGE}Renamed original file to:${NOCOLOR}"
    echo "${orig_file}"
    echo -e "${ORANGE}${title} is done.${NOCOLOR}"

  else
    echo -e "${orig_file} was already transcoded or filtered"
  fi

done
