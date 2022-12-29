#!/usr/bin/env ruby

# Poll drives looking for a Blu-Ray disc. If found, rip it with makemkvcon, then eject it.
# Version: 1.0.1

# Constants
MAKE_MKVCON_PATH = "/Applications/MakeMKV.app/Contents/MacOS/makemkvcon"
POLL_SEC = 20
VOLUMES_PATH = "/Volumes"
OUTPUT_PATH = "~/automkv_output"    // Set this to something appropriate for your system.

# Globals
DrivesInUse = {}

# Functions
def scanOpticalVolumes
    volumes = Dir.entries(VOLUMES_PATH)
    volumes.delete_if { |entry| entry.start_with? '.' }
    volumes.delete_if { |entry| !File.exist? "#{VOLUMES_PATH}/#{entry}/BDMV/MovieObject.bdmv" }
    volumes.delete_if { |entry| DrivesInUse.keys.include? entry }

    volumes
end

while true
    sleep POLL_SEC

    # Look for any new optical drives.
    opticalDrives = scanOpticalVolumes

    unless opticalDrives.empty?
        opticalDrives.each do |driveName|
            # Start a new thread to launch and wait for makemkvcon.
            DrivesInUse[driveName] = Thread.new {
                # Make the output directory.
                idx = 0
                rootOutputPath = "#{OUTPUT_PATH}/#{driveName}"
                outputPath = rootOutputPath
                while Dir.exist? outputPath
                    idx += 1
                    outputPath = "#{rootOutputPath}-#{idx}"
                end
                Dir.mkdir(outputPath)

                # Kick off makemkvcon
                system(MAKE_MKVCON_PATH, "mkv", "--noscan", "file:#{VOLUMES_PATH}/#{driveName}", "all", "#{outputPath}")
                # Eject disc when finished
                system("diskutil", "eject", "#{VOLUMES_PATH}/#{driveName}")

                Thread.exit
            }
        end
    end

    deadThreadKeys = []
    DrivesInUse.each_pair do |driveName, thread|
        if thread.status.nil? || thread.status == false
            deadThreadKeys << driveName
        end
    end

    deadThreadKeys.each do |driveName|
        DrivesInUse.delete driveName
    end
end
