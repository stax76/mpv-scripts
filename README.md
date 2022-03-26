
# mpv-scripts

## [delete-current-file](delete-current-filelua.lua)

This script deletes the file that is currently playing
via keyboard shortcut, the file is moved to the recycle bin.

## [seek-show-position](src/seek-show-position.lua)

When seeking displays the position and duration like so: 70:00 / 80:00
Which is different from most players which use: 01:10:00 / 01:20:00
In input.conf set the input command prefix `no-osd` infront of the seek command.
