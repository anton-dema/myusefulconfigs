# Search Files from borg backup 

## String to search the backup sets 

	borg list /path/to/borg/repo

## Command to search for a file name 

	 borg list /path/to/borg/repo::2017-09-15-14:52:50 | grep Silicon | awk '{ print substr($0, index($0,$8)) }'

## Result : 

		home/anton/Pictures/Silicon Valley Stagione 1 Completa
		home/anton/Pictures/Silicon Valley Stagione 1 Completa/Silicon.Valley.S01E01.HDTV.x264-KILLERS.mp4
		home/anton/Pictures/Silicon Valley Stagione 1 Completa/Silicon.Valley.S01E02.HDTV.x264-2HD.mp4
		home/anton/Pictures/Silicon Valley Stagione 1 Completa/Silicon.Valley.S01E04.HDTV.x264-KILLERS.mp4
		home/anton/Pictures/Silicon Valley Stagione 1 Completa/Silicon.Valley.S01E05.HDTV.x264-KILLERS.mp4
		home/anton/Pictures/Silicon Valley Stagione 1 Completa/Silicon.Valley.S01E08.HDTV.x264-KILLERS.mp4
		home/anton/Pictures/Silicon Valley Stagione 1 Completa/silicon.valley.s01e06.hdtv.x264-2hd.mp4
		home/anton/Pictures/Silicon Valley Stagione 1 Completa/silicon.valley.s01e07.hdtv.x264-killers.mp4
		home/anton/immagini/Silicon.Valley.s02e03.720p.sub.itasa.zip

## L'amico DickButt 
![a neat image](http://demaitalia.s3.amazonaws.com/db.jpg)
