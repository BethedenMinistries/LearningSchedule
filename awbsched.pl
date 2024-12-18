#!/usr/local/bin/perl
use feature "switch";
use Getopt::Std;
use List::Util qw(min max);
use Scalar::Util "looks_like_number";
use utf8;
use open qw(:std :utf8);
use Time::Stamp -stamps => { dt_sep => ' ', date_sep => '/', us => 1 };
  # localstamp() will return something like "2012/05/18 10:52:32.123456"

################################################################################
### awbsched.pl
### 
### Author: Carol C. Kankelborg        cckborg2@kankelborg.net
###
################################################################################
### Revision History
################################################################################
#    
# 09/20/2021  	Created
# 10/30/2021	Program is essentially complete.
# 11/01/2021	Removed story title from output. (It was redundant)
# 03/30/2023	Finished a number of wish-list items, to make program more
#				generic for Hebrew and Greek, and allow for titles of videos 
#				in different languages. Removed note to wait for more quizzes
#				if there are currently none. There may not be any more and 
# 				Alpha with Angela is not generating any anyway.
# 09/05/2024	Added code to substitute the default (i.e. English) video title when
#				the target language title field is blank in the video database.
#
################################################################################
### Wish List/To Do List
################################################################################
# Error checking for inputs (Done, 7/25/22)
# Put arguments used to generate the schedule in output file. (Done, 1/28/22)
# Use a default output file name, based on input name and arguments. (Done, 1/28/22)
# Change behavior for extra story videos which duplicate lessons. (Done)
# Split related videos into multiple days if too many. (Done)
#
# For Alpha with Angela
# Tighten up Course option (Don't remember what I meant by this anymore.)
# Change how bonus lessons are handled. Alpha = a, Aleph = b. Alpha had multiple for 
#      one lesson (a, b, etc.) (Done, 3/29/23 -- added column in database for suffix.)
# Handle no quizzes more elegantly. (Done, 3/29/23 -- eliminated the 
#      "watch for more quizzes message" if quiz count is 0.)
#
#
# Add option to skip blank lines for easier formatting in a word processor.
# Better yet, format output using html and have the URL as a link.
#
#
################################################################################
### Program Description
################################################################################
#
#  usage: progname [options] arguments
#  
# Program Tree: 
# -------------
# MAIN                        - Initializes constants.  Controls program flow.
#	GET_VIDEOS
#		CLEANUP
# 	GET_PHRASES
#		CLEANUP
# 	PRINT_HEADER
#   PRINT_TIME
#	PROCESS_VIDEOS	
#		PRINT_LESSON
#			INCREMENT_COUNTERS
#           	MAKE_SECS
#			PRINT_LINE
#				PRINT_TIME
#					PRINT_TOTAL_TIME
#						MAKE_TIME
#					MAKE_TIME
#			PRINT_QUIZ
#				INCREMENT_COUNTERS
#				QUIZ_LOOP
#					PRINT_LINE
#			PRINT_TOTAL_TIME
#			B_TRANSLATE	
#			MAKE_TIME
#	VIDEO_LIST (Currently not used.)
#	MAKE_SECS
#   USAGE                    - Prints out Usage message for -h option.
#
################################################################################
### Initialization of flags and variables
################################################################################
# Names of files to be required
$path_delim = '/';
($src_path, $src) = ($0 =~ m@^(.*${path_delim})([\w.*]+)$@o);

################################################################################
### Process Argument List
################################################################################
# Total number of lessons. Update to actual number when known.
$total_lessons = 999;   

### Process Switches

# Default value of switch options.
$opt_d  = 0;	# Debug Mode
$opt_h  = 0;	# Help Flag
$opt_p  = 0;    # Default: including previous lesson when processing a subset
# $opt_u  = 0;    # Unit Mode, 1 unit (2 lessons) per week.
$opt_x  = 0;    # Unit Mode, but first day is just one lesson.

$opt_a  = 'Aleph'; 			# Default: Aleph with Beth
$opt_c  = '\t'; 			# Default: delimiter character
$opt_e  = $total_lessons;  	# Default: the highest number lesson. 
#$opt_f  = 'AWBVideos.tsv'; # Default
$opt_l  = 0;				# Default: Text output.
#$opt_m  = 2;				# Lesson Mode, Default: 2 main videos per day
#$opt_o  = "Output.txt";    # Default
#$opt_s  = 1;				# Default: Starting Lesson Number
#$opt_t  = "50:00";   		# Time Mode, Default: 50 minutes of video per day
#$opt_u  = 0;               # Unit Mode, 1 unit (2 lessons) per week.
#$opt_v  = 3;   	 		# Video Mode, Default: 3 videos per day
#$opt_w  = 6;				# Default: Number of study days in week, default


# Create variable with invoking command, options, and arguments.
$command = "$src ";
foreach (@ARGV) {
	$command = $command . "$_ ";
} 

# Get Options
getopts('dhlpxa:c:e:f:m:o:s:t:u:v:w:');

if ($opt_d) {
	print "DEBUG MODE\nOptions: Debug: $opt_d, Help: $opt_h, Prev: $opt_p";
	print ", Ancient Lang: $opt_a, Delim: $opt_c, End: $opt_e, Start: $opt_s, Week Length: $opt_w";
	print ", Lesson Mode: $opt_m, Time Mode: $opt_t, Unit Mode: $opt_u, Video Mode: $opt_v";
	print ", Video File: $opt_f, Output File: $opt_o."
}

if ($opt_h) {
	&USAGE($src);
	exit(1);
};

### Process File Name Argument

# Default File names
$video_file = 'AWBVideos.tsv';              # Default
$in_file    = "AWBEnglish.txt";  	   		# Default
$out_file   = "AWBEnglish_Schedule.txt";    # Default

$num_args = $#ARGV + 1;

print "Number of arguments: $num_args\n" if $debug;

if ($num_args == 1) {$in_file    = $ARGV[0];}

#if ($opt_a == 'Alpha') 
#	{$skip_quiz = 1;
#	 $bonus_sfx = 'a';}
#else 
#	{$skip_quiz = 0;
#	 $bonus_sfx = 'b';}

if ($opt_f) {$video_file = $opt_f;}

if ($opt_o) {
	$out_file   = $opt_o;
} else {
	$temp_file = $in_file;
	$temp_file =~ s/(.+)\.(.*)//;
  	$out_file = $1 . "_Schedule" . ".$2"
}

print "Video List File name is -$video_file-\n" if $debug;
print "Input Phrase File name is -$in_file-\n"  if $debug;
print "Output File name is -$out_file-\n" 		if $debug;


# Set variables from switches
$debug        = $opt_d;
$incl_prev    = $opt_p;
$xmode        = $opt_x;
$html_out     = $opt_l;

# Store command creating the schedule and time-stamp for printing at the end of the file
if ($html_out) {
	$command = "$command" . "<br>" . localstamp();
} else {
	$command = $command . "\n";
	$command = $command . localstamp() . "\n";
	print "The non-html Command is $command\n";
}


$course       = $opt_a;	
$csv_char     = $opt_c;

if ($opt_s) {
	$start_lesson = $opt_s;	
} else {
	$start_lesson = 1;  # Default
}
$end_lesson   = $opt_e;

if ($opt_w) {
	$max_day = $opt_w;	   # Maximum number of days/week = 7
} else {
	$max_day = 6;		   # Default number of days
}

################################################################################
### Error Checking of (some) inputs
################################################################################

# Files are checked when opened.
# Mode flags and values are checked below
# getopts('dhpxa:c:e:l:s:t:u:v:w:');

die "ERROR: Course (-a) $opt_a is not valid.\n" unless (($course eq 'Aleph') | ($course eq 'Alpha'));

die "ERROR: Starting lesson (-s) $start_lesson must be a positive integer." unless IS_POS_INT($start_lesson);
die "ERROR: Ending lesson (-e) $end_lesson must be a positive integer." unless IS_POS_INT($end_lesson);
die "ERROR: Starting lesson (-s) $start_lesson is higher than the ending lesson (-e) $end_lesson.\n" unless ($end_lesson >= $start_lesson);

if ($opt_p && !$opt_s) {
	$opt_p = 0;
	print "WARNING: Include Previous lesson flag (-p) is ignored when no starting lesson is specified.\n" ;
}

die "ERROR: Number of days of study per week (-w) $opt_w must be an integer between 1 and 7.\n" unless (($max_day > 0) && ($max_day <= 7) && IS_POS_INT($max_day)) ;


################################################################################
### Initialize Global Constants
################################################################################

# Estimated times for various activities
$verse_read_time  =  "2:30";
$alpha_write_time =  "5:00";
$alpha_read_time  = "10:00";
$quiz_take_time   =  "3:00";
$related_avg_time = "20:00";

# UTF-8 constants
if ($html_out) {
	$box = '<input type="checkbox">';
} else {
	$box    = "\N{U+25A2}"; # should be a blank check-box
}
$bullet = "\N{U+2022}"; # should be a bullet
$dash   = "\N{U+2013}"; # should be en-dash

# Character string to be replaced by video-specific text (in %phrases)
$sub_char = '&&';  

# Character string separating URL from phrase 
# $html_mk = "||";

# Tab indent levels
$ind1 = "\t";
$ind2 = "\t\t";
$ind3 = "\t\t\t";
$ind4 = "\t\t\t\t";
$ind5 = "\t\t\t\t\t";
$ind6 = "\t\t\t\t\t\t";

# Determine Mode
# Order of precedence: Unit, Time, Video, Main, (Default = Main) 

# Mode-related constants
$main_mode  = 'M';
$time_mode  = 'T';
$unit_mode  = 'U';
$video_mode = 'V';

if ($opt_u) {
	# For Unit Mode, The only option is 1 or 2 units per week.
	die "ERROR: Number of units per week (-u) $opt_u must be 1 or 2\n." unless ((($opt_u == 1) || ($opt_u == 2)) && IS_POS_INT($opt_u));
	
	if ($opt_t || $opt_v || $opt_m || $opt_x) {
		print "WARNING: Unit mode overrides all other modes if they are also set.\n";
	}
	if ($opt_w) {
		print "WARNING: Unit mode overrides number of study days per week (-w) $opt_w.\n";
	}
	# The days are divided up according to Main Mode (Default = 2 main videos/day).
	$mode 	  = $unit_mode;
	$max_unit = $opt_u;
	$max_main = 2 * $max_unit;   
	$max_day  = 7;
	print "Running in Unit Mode: $max_unit\n" if $debug;
} elsif ($opt_x) {
	if ($opt_t || $opt_v || $opt_m) {
		print "WARNING: UnitX mode overrides Time (-t), Video (-v) or Main (-m) Modes if they are also set.\n";
	}
	if ($opt_w) {
		print "WARNING: UnitX mode overrides number of study days per week (-w) $opt_w.\n";
	}

	# For UnitX Mode, The only option is 1 unit per week.
	# The days are divided up according to Main Mode (Default = 2 main videos/day)
	# but the first day has only one video. That way you always watch two different videos
	# each day after that.
	# Review Game & Quizzes are separated into their own day.
	$mode 	  = $unit_mode;
	$xmode    = 1;
	$max_unit = 1; 
	$max_main = 2 * $max_unit;   
	$max_day  = 7;
	print "Running in UnitX Mode: $max_unit\n" if $debug;
} elsif ($opt_t) {
	# For Time Mode, the estimated sum of each day's activities and videos will not
  	# exceed the maximum time specified. 

	# Time Mode time value must be in the form mm:ss
	my $test_time = $opt_t;
	die "ERROR: Time value (-t) $opt_t must be of the form mm:ss\n" unless ($test_time =~ s/(\d+):(\d+)//);
	


	if ($opt_v || $opt_m) {
		print "WARNING: Time mode overrides Video (-v) or Main (-m) Modes if they are also set.\n";
	}
	
	$max_time = MAKE_SECS($opt_t); # Specified in mm:ss, converted to seconds.

	$mode     = $time_mode;
	
	die "ERROR: Number of minutes of study per day (-t) $opt_t must be less than or equal to 4800:00.\n" if ($max_time > (24*60*60));

	print "Running in Time Mode: $max_time\n" if $debug;
} elsif ($opt_v) {
	# For Video Mode, the number of videos must be between 1 and 5.
	die "ERROR: Number of videos per day (-v) $opt_v must be an integer between 1 and 5\n." unless (($opt_v > 0) && ($opt_v <= 5) && IS_POS_INT($opt_v));
	
	if ($opt_m) {
		print "WARNING: Video mode overrides Main (-m) Mode if it is also set.\n";
	}
	# For Video Mode, each day has no more than the specified number of videos. 
	# Review game & quizzes count as one video. Additional reading and writing exercises
	# are not included in the count.
	$max_vid  = $opt_v;
	$mode = $video_mode;	
	print "Running in Video Mode: $max_vid\n" if $debug;
} elsif ($opt_m) {

	# For Main Mode, the number of main videos must be between 1 and 5.
	die "ERROR: Number of main videos per day (-m) $opt_m must be an integer between 1 and 5\n." unless (($opt_m > 0) && ($opt_m <= 5) && IS_POS_INT($opt_m));

	$max_main     = $opt_m;
	$mode = $main_mode;
	print "Running in Main Mode: $max_main\n" if $debug;
} else {
	print "WARNING: No mode has been specified. Default mode is Main (-m 2) Mode.\n";
	# Default if no mode is explicitly set.
	$mode 	  = $main_mode;
	$max_main = 2;  # Default
	print "Running in Default Main Mode: $max_main\n" if $debug;
}

# Default Locale code
$default_locale = 'en_US';

# Initialize indexes of @fields array.	
# The title field is of the form 'Title_' . $locale. It will be generated after the phrase file is parsed.

$type		  = "Type";
$num		  = 'Num';
$sfx          = 'Sfx';
$title 		  = 'Title';    		# Video Titles, with locale code appended.
$duration	  = 'Duration';
$quizzes      = "Quiz_Count";
$related	  = 'Related';
$verses		  = 'Read_Verses';
$url		  = 'URL';
$verses_pt	  = 'All_Verses';		# Not used by program
$paraphrases  = 'Paraphrases';		# Not used by program

@field_fmt = ("%-6s", "%6s", "%-32s", "%-12s", "%-12s", 
 					"%-12s", "%-32s", "%-50s", "%-32s", "%-32s");


### Input Error Checking is done at this point. 

### Create Argument String to output to terminal
### It will be printed out after all input error checking has been done.
### getopts('dhpxa:c:e:l:s:t:u:v:w:');

$argstr =           "Generated by $src for Language Course: $course\n";

$argstr = $argstr . "Covers Lessons $start_lesson to $end_lesson, $max_day days per week.";

if ($opt_p) {$argstr = $argstr . " Includes Previous Lesson (" . ($start_lesson - 1) . ").";}
$argstr = $argstr . "\n";

$argstr = $argstr . "Mode: ";
if    ($opt_u) {$argstr = $argstr . "Unit ($opt_u)";}
elsif ($opt_x) {$argstr = $argstr . " UnitX";}
elsif ($opt_t) {$argstr = $argstr . "Time ($opt_t)";}
elsif ($opt_v) {$argstr = $argstr . "Video ($opt_v)";}
elsif ($opt_m) {$argstr = $argstr . "Main ($opt_m)";}
else           {$argstr = $argstr . "Default, Main (2)";}
$argstr = $argstr . "\n";
$argstr = $argstr . "Video File: $video_file\nInput Phrase File: $in_file\nOutput File: $out_file";

print "***********************\n$argstr\n***********************\n";

################################################################################
### Initialize Global Variables
################################################################################

$week_count     = 1;  	# Counts weeks 
$day_count      = 1;	# Counts days within each week

$first 			= 0;	# Flag to indicate processing first lesson
$last 			= 0;	# Flag to indicate processing last  lesson

$main_count     = 0;	# Counts number of main lesson videos for Main mode
$vid_count      = 0;	# Counts number of all  lesson videos for Video mode
$time_count     = 0;	# Counts (estimted) time required for each day. Also used in Time mode.
$lesson_count   = 0;	# Counts number of lessons (1 unit = 2 full lessons) for Unit mode.

$time_adjust    = "";	# Holds the time required for the present activity. 
						# Needed to keep track of when to increment day due to time limit reached
						# and to report time required for  the previous day.
						
$max_secs  = 0;
$min_secs  = 99999;
$tot_time  = 0;
$tot_days  = 0;

################################################################################
### Build Databases for target-language phrases
################################################################################

# Generate Phrases and Canon hashes (Language specific)
($pref, $cref) = GET_PHRASES($in_file);
%phrases = %{$pref};
%canon   = %{$cref};

# Select the right Video titles, based on locale in phrase file. (English is default)

if ($phrases{'locale'}) {
	$locale = $phrases{'locale'};
} else {
	$locale = $default_locale;
}

$title_default = $title . "_$default_locale";
$title         = $title . "_$locale";

print "The Locale is $locale. The Column used is $title\n" if $debug;

################################################################################
### Build Databases for lesson videos
################################################################################

# Generate Videos array from file. Determine starting and ending lessons.
@videos = GET_VIDEOS($video_file, $csv_char, $title, $title_default);

	### Print out array of hashes for debug purposes
	if ($debug) {
		print '*** @videos array of hashes ***' . "\n";
		# Print Field Headings
		while (($k, $key) = each @fields) {printf $field_fmt[$k], "-$key-";} print "\n"; 
		# Print Values
		for (@videos) {while (($k, $key) = each @fields) {printf $field_fmt[$k], "-$_->{$key}-";} print "\n";} 
	}	
	### End of Debug printing    


$max_video  = scalar(@videos) - 1;			# Index for last video
$max_lesson = $videos[$max_video]->{$num};	# Lesson number for last video
$min_lesson = $videos[0]->{$num};			# Lesson number for first video

# Determine first and last lessons for schedule
$start_lesson = $min_lesson if ($start_lesson < $min_lesson);
$end_lesson   = $max_lesson if ($end_lesson  > $max_lesson);

print "Starting Lesson: $start_lesson, Ending Lesson: $end_lesson, Size of Video Array: $max_video\n" if $debug;
print "Highest Lesson: $max_lesson, Lowest Lesson: $min_lesson\n" if $debug;



print "Highest Lesson: $max_lesson, Lowest Lesson: $min_lesson\n" if $debug;


################################################################################
### Create Output file and add header text
################################################################################

open(OUTFILE, ">$out_file")  || die "ERROR: $! ($out_file)\n";

if ($html_out) {
   INITIALIZE_HTML ($course);
}

PRINT_HEADER ($course);

################################################################################
### Cycle Through Lessons
################################################################################

PRINT_TIME(1, 0);

print "Highest Lesson: $max_lesson, Lowest Lesson: $min_lesson\n" if $debug;


($first_vid, $last_vid) = PROCESS_VIDEOS($start_lesson, $end_lesson, $max_video);  

# Include list of videos with URLs at the end of the lesson schedule
# Not sure if this is worth including in the file.
# VIDEO_LIST($first_vid, $last_vid);


close(OUTFILE);

exit;

################################################################################
### Daughter Subroutines
################################################################################
################################################################################
### INITIALIZE_HTML (course_type)
################################################################################
sub INITIALIZE_HTML {
################################################################################
### Generates the opening lines of the HTML Document and the <head> tag.
### 
### 	Global Variables:
################################################################################

	my $course = $_[0];  # Placeholder argument to select language course 

	print OUTFILE "<!DOCTYPE html>\n";
	print OUTFILE "<html>\n";
	
	### Head Element
	print OUTFILE "$ind1<head>\n";
	
	### Ensure Hebrew and other characters render correctly
	print OUTFILE '<meta charset="utf-8">' . "\n";
	
	### Style Sheet
	print OUTFILE "$ind2" . '<link rel="stylesheet" type="text/css" href="./TestSched.css">' . "\n";
	
	return;
}
################################################################################
### INITIALIZE_HTML (course_type)
################################################################################
sub FINALIZE_HTML {
################################################################################
### Generates the opening lines of the HTML Document and the <head> tag.
### 
### 	Global Variables:
################################################################################

	my $course = $_[0];  # Placeholder argument to select language course 

	### Terminate Body Element
	print OUTFILE "$ind1<\/body>\n";
	
	### Terminate HTML Element
	print OUTFILE "<\/html>\n";
	
	return;
}

################################################################################
### HTML_HEADER (course_type)
################################################################################
sub HTML_HEADER {
################################################################################
### Generates the header element in the HTML Document.
### 
### 	Global Variables:
################################################################################

	print OUTFILE "\t\t<header>\n";
	print OUTFILE "\t\t</header>\n";
	print OUTFILE "\t\t<main>\n";
	return;
}

################################################################################
### PRINT_HEADER (course_type)
################################################################################
sub PRINT_HEADER {
################################################################################
### Generates introductory information at the beginning of the learning schedule.
### It has been generalized for any number of intro, howto, and links lines.
### The first line in each category is considered a heading.
### Any line which contains "https" is considered a link and will be indented.
###
### This routine could be simplified by moving the code for each header type
### into a subroutine and/or create a loop to process the three types.
### 
### 	Global Variables: %phrases, $sub_char
################################################################################

	my $course = $_[0];  # Placeholder argument to select language course 

	print "PRINT_HEADER Subroutine ($course)\n" if $debug;
	
	
	for my $ix (0 .. $#{@phrases{'intro'}}) {
	    my $str = $phrases{'intro'}->[$ix];
	    
	    if ($ix ==0) {
			if ($html_out) {
	    		$str =~ s/$sub_char/$start_lesson\&ndash\;$end_lesson/;	    
				print OUTFILE "<title>$str</title>\n";
				print OUTFILE "\t</head>\n";
				print OUTFILE "\t<body>\n";
				HTML_HEADER();
				print OUTFILE "\t\t<section>\n";
				print OUTFILE "\t\t\t<h1>$str</h1>\n";
				print OUTFILE "\t\t\t<p class=\"intro\">\n";
			} else {
	    		$str =~ s/$sub_char/$start_lesson$dash$end_lesson/;	    
				print  OUTFILE "****** $str ******\n\n";    
			}
	    } else {
	        if ($html_out) {
	        	print  OUTFILE "$str<br>\n";
	        } else {
	    		print  OUTFILE "$str\n";
	    	}
	    }  	    
 	}	
	
	if ($html_out) {
		print OUTFILE "</p>\n\n"	
	} else {	
		print OUTFILE "\n\n";
	}	
	
	PRINT_HEADER_SUBSECTION('howto', $course);	
	PRINT_HEADER_SUBSECTION('links', $course);

	return;

}
################################################################################
### PRINT_HEADER_SUBSECTION (starting lesson, ending lesson, index for last video)
################################################################################
sub PRINT_HEADER_SUBSECTION {
################################################################################
### Both the Links and HowTo subsections are processed the same way.
###	Processes one subsection and outputs to OUTFILE.
###	
###     Global Variables: %phrases
### 
################################################################################
	print "PRINT_HEADER_SUBSECTION Subroutine ($course)\n" if $debug;
	
	my $subsection = $_[0];
	my $course     = $_[1];  # Placeholder argument to select language course 

	
	for my $ix (0 .. $#{@phrases{$subsection}}) {
	    my $str = $phrases{$subsection}->[$ix];
	    
	    if ($ix ==0) {
	    	if ($html_out) {
	    		print OUTFILE "$ind3<h2>$str</h2>\n";
	    		print OUTFILE "$ind4<ul class=\"$subsection\">\n";	    		
	    	} else {
	    		print OUTFILE "*** $str ***\n\n";	    
	    	}
	    } elsif (index($str, "http") == -1) {
	    	# No HTML link in phrase
			print  OUTFILE "$ind2$str\n";
	    } else {
	    	# HTML Link in phrase
			$str =~ s/(.*)(http.*)//;
			$str_text = CLEANUP($1);
			$str_link = CLEANUP($2);

  	   		if ($html_out) {
  	   			print OUTFILE "$ind5<li><a target='_blank' href=$str_link>$str_text<\/a><\/li>\n";
  	   		} else {
	    		print OUTFILE "$str\n";
	    	}
	    }	    	    
 	}	
 	
	if ($html_out) {
		print OUTFILE "</ul>\n\n";
		print OUTFILE "$ind2</section>\n";
	} else {	
		print OUTFILE "\n";
	}
	
	return;

}

################################################################################
### PROCESS_VIDEOS (starting lesson, ending lesson, index for last video)
################################################################################
sub PROCESS_VIDEOS {
################################################################################
### Step through array of video hashes, build lesson hash for current lesson.
###	Set the $first and $last flags. Call PRINT_LESSON for each lesson.
###	Assign current lesson hash to previous lesson hash and repeat the process.
### 
###     Global Variables: @videos, $max_count, $first, $last, $lesson_count
### 	Return (index for starting lesson, index for ending lesson)
### 
################################################################################

	my $start_les = $_[0];	# Starting lesson in learning schedule
	my $end_les   = $_[1];	# Ending   lesson in learning schedule
	my $max_ix    = $_[2];	# Index for last video
	    
#	my $debug = 1;

    print "PROCESS_VIDEOS Subroutine ($start_les, $end_les, $max_ix).\n" if $debug;		
	     
    my $vid_ix   = 0;	# Index counter for Video Array    
    my $start_ix = 0;   # Index of first video for first lesson
    my $end_ix   = 999; # Index of last video for last lesson
    
	# Lesson arrays contain a list of every index of @videos for every video associated with
	# the previous or current lesson.
    my @previous_lesson = ();   # Initialize previous lesson array.
	my @current_lesson  = ();   # Initialize current  lesson array.
     

	my $m     = $videos[$vid_ix]{$num};	# Lesson Num
	

	# Skip over lessons before the starting lesson.
	# Need to generate previous lesson array if $incl_prev = 1;
	while ($m < $start_les) { 
		print "Skip... Index: $vid_ix Starting Lesson: $start_les, Lesson Number: $m\n" if $debug;
		# Generate @previous_lesson if the previous lesson is supposed to be included.
		if (($m == $start_les - 1) && ($incl_prev)) {
			push (@previous_lesson, $vid_ix);
		}
		$vid_ix++;
		$m = $videos[$vid_ix]{$num};
	}
		
	$start_ix = $vid_ix;   # Index of @videos for the start lesson to be processed. 
	
	LLOOP: while ($vid_ix <= $max_ix) {		
		# Find all videos for lesson $m.
		my $m_next = $videos[$vid_ix]{$num};
		
		while ($m_next == $m) { 
			push (@current_lesson, $vid_ix); 
			$vid_ix++;
			$m_next = $videos[$vid_ix]{$num};
		}	

		$end_ix = $vid_ix;
		
		## Print the Current and Previous Lesson Index arrays
		if ($debug)	{
			print "Lesson M Index Array for Lesson $videos[$current_lesson[0]]{$num}: ( ";
			for (@current_lesson) {print "$_, ";} 
			print " )\n"; 
			if (@previous_lesson) {  # If array is not empty
				print "Lesson P Index Array for Lesson $videos[$lesson_p[0]]{$num}: ( ";
				for (@previous_lesson) {print "$_, ";} 
				print " )\n";
			} else {
				print "No previous Array (" . join (", ", @previous_lesson) . ")\n";
			}
			print "\n";
		}
		## End of Debug Print
	
		# Determine if $ is either first or last lesson 
		if ($m == $end_les) {
			$last = 1;
		} else {
			$last = 0;
		}
		if ($m == $start_les) {
			$first = 1
		} else {
			$first = 0;
		}
		
		PRINT_LESSON(\@previous_lesson, \@current_lesson);
		
		
		if ($last) { # End loop if we are on the last lesson.
			$end_ix = $vid_ix - 1; # Index of Video array of last video for ending lesson
			last; 
		} 
		
		@previous_lesson = @current_lesson;  # Current lesson array becomes previous lesson array.
		@current_lesson = ();   # Reset current lesson array.
		$m++;  # Go to the next lesson.
		
	} # End LLOOP
     
   print "End PROCESS_VIDEOS Subroutine S: $start_ix, E: $end_ix\n" if $debug;  
   return ($start_ix, $end_ix);
}

################################################################################
### PRINT_LESSON (previous lesson array, current lesson array)
################################################################################
sub PRINT_LESSON {
################################################################################
### This subroutine is the brains of the schedule generation. It processes each
### type of video as needed. (See GET_VIDEOS subroutine for description of each type.)
###
###		Global Variables: $debug, @videos, $first, $last, $lesson_count, $command, $incl_prev
###			Keys to @videos: $type, $num, $duration, $related, $quizzes, $verses, $url)
### 		Time constants: $$verse_read_time, $alpha_write_time, $alpha_read_time, 
###							$quiz_take_time, $related_avg_time, ## $bonus_sfx
###
###
### General Procedure:
### Types G, A: Listen 1x, Repeat 3x. 
### Types P, S, T: Listen 1x, Repeat 1x.
### Types X: Alert to existence.
### Types W, L: Listen & sing, 2x.
### Interleave listening and repeating lessons as well as previous with current.
### Review related videos
### Type R: End with Review Game and Quizzes of both current & previous lessons.
### 
### Here is the basic template for current lesson $n (previous lesson $p)
### 
### $n lesson listen		1
### $n lesson repeat		2
### $p story  listen			1		
### $p bonus  repeat				2
### $n alphabet write
### 
### $p lesson repeat	4	
### $p story  repeat			2
### $n bonus  listen					1
### $n lesson repeat		3
### $n script read (alphabet lesson)
### $n verse  read
### 
### $p, $n related Videos 
### $p, $n extra videos (X)
### $p, $n extra alphabet videos (L)
### 
### $p, $n review game (R)
### $p.q   quizzes
### $n.q   quizzes
### 
################################################################################

	my @lesson_p = @{$_[0]}; # List of indexes of @videos for the previous lesson
	my @lesson_n = @{$_[1]}; # List of indexes of @videos for the current  lesson

	# Initialize Variables	
	
	# Hashes or arrays. Hash keys are each video type (A, G, P, etc.). 
	# The array contains all indexes of @videos for that type for the previous/current lesson
	my %phash;
	my %nhash;
	
	# Arrays that hold the indexes for all main videos (Types 'G' or 'A')
	my @main_lessons_p = ();
	my @main_lessons_n = ();
	
	# Arrays that hold the indexes for all story videos (Types 'S' or 'T')
	my @main_stories_p = ();
	my @main_stories_n = ();
	
	my $num_p;	# Lesson Number of previous lesson
	my $num_n;	# Lesson Number of current  lesson
	
#	my $debug = 1;
	
	print "PRINT_LESSON Subroutine.\n" if $debug;
	
	## Print the Current and Previous Lesson Index arrays
	if ($debug)	{
		print "Lesson N Index Array for Lesson $videos[$lesson_n[0]]{$num}: ( ";
		for (@lesson_n) {print "$_, ";} 
		print " )\n"; 
		if (@lesson_p) {  # If array is not empty
			print "Lesson P Index Array for Lesson $videos[$lesson_p[0]]{$num}: ( ";
			for (@lesson_p) {print "$_, ";} 
			print " )\n";
		} else {
			print "No previous Array (" . join (", ", @lesson_p) . ")\n";
		}
		print "\n";
	}
	## End of Debug Section
	
	for (@lesson_p) {  # Separate videos by type
			push( @{ $phash{$videos[$_]{$type}}}, $_);
	}
	
	for (@lesson_n) {  # Separate videos by type
			push( @{ $nhash{$videos[$_]{$type}}}, $_);
	}

	## Print the Current and Previous Lesson Hashes
	if ($debug) {
		for $key ( keys %nhash) {
			print "nhash: -$key-" . join(", ", @{$nhash{$key}}) . "\n";
		}

		for $key ( keys %phash) {
			print "PHASH: -$key-" . join(", ", @{$phash{$key}}) . "\n";
		}
	}
	## End of Debug Section

	# Create array of all Grammar and Alphabet lessons
	
	push(@main_lessons_n, @{ $nhash{'G'}}, @{ $nhash{'A'}});
	push(@main_lessons_p, @{ $phash{'G'}}, @{ $phash{'A'}});

	push(@main_stories_n, @{ $nhash{'S'}}, @{ $nhash{'T'}});
	push(@main_stories_p, @{ $phash{'S'}}, @{ $phash{'T'}});

	# Assign lesson numbers for current and previous lessons
	$num_n = $videos[$main_lessons_n[0]]{$num};  
	$num_p = $videos[$main_lessons_p[0]]{$num}; 
	
	$lesson_count++;
	
	if ($html_out) {
		$nt = " ";
		$colon = "";
	} else {
		$nt = "\n\t";
		$colon = ":";
	}
	 
	### Current Lesson (Grammar or Alphabet): Listen, Repeat
	MAIN_N1: for (@main_lessons_n) {
#		print "MAIN_N1 -$_-\n";
		$line = "$videos[$_]{$num} ($videos[$_]{$duration})";
		INCREMENT_COUNTERS (1, 1, $videos[$_]{$duration}, 1);
		# Force new week after max units is completed and you are on the first lesson of the new unit. 
		# i.e. Current lesson modulo (2 * number of units) = 1 (first lesson past $max_unit boundary)
		# This accounts for the starting lesson not being on a full week boundary 
		my $force_wk = ($mode eq $unit_mode) && ($num_n % (2 * $max_unit) == 1) && !$first;
		my $force_dy = 0; # Took out Force New Day.
		PRINT_LINE($line, 'watch_listen', 1, " ($videos[$_]{$title}$colon$nt$videos[$_]{$url})", 0, 0, $force_dy, $force_wk);
		# Force a new day after first video if in UnitX mode unless it is the first day.
		INCREMENT_COUNTERS (1, 1, $videos[$_]{$duration}, 1);
		my $force_dy = ($xmode && !$first && ($videos[$_]{$num} %2 == 1));		
		PRINT_LINE($line, 'watch_repeat', 1, " ($videos[$_]{$title})", 0, 0, $force_dy, 0);
	}		
	
    # Previous Lesson Story: Listen
	STORYP1: for (@main_stories_p) {
#		print "STORYP1 -$_-\n";
		$line = "$videos[$_]{$title} ($videos[$_]{$duration})";
		INCREMENT_COUNTERS (0, 1, $videos[$_]{$duration}, 1);
		PRINT_LINE($line, 'watch_story_listen', 1, "$nt($videos[$_]{$url})", 0, 0, 0, 0);
	}
	
	# Previous Lesson Bonus: Repeat	
	BONUSP: for (@{ $phash{'P'}}) {
#		print "BONUSP -$_-\n";
		$line = "$videos[$_]{$num}$videos[$_]{$sfx} ($videos[$_]{$duration})";
		INCREMENT_COUNTERS (0, 1, $videos[$_]{$duration}, 1);
		PRINT_LINE($line, 'watch_repeat',  1, " ($videos[$_]{$title})", 0, 0, 0, 0);
	}
				
	# Current Lesson (Alphabet): Write
 	ALPHA_WR: for (@{ $nhash{'A'}}) {
#		print "ALPHA_WR -$_-\n";
		INCREMENT_COUNTERS (0, 0, $alpha_write_time, 1); 
		PRINT_LINE($videos[$_]{$num},  'write10', 	  1, "", 0, 0, 0, 0);
	}
				
	### Previous Lesson (Grammar or Alphabet): Repeat
	MAIN_P: for (@main_lessons_p) {
#		print "MAIN_P -$_-\n";
		$line = "$videos[$_]{$num} ($videos[$_]{$duration})";
		INCREMENT_COUNTERS (1, 1, $videos[$_]{$duration}, 1);
		PRINT_LINE($line, 'watch_repeat',	1, " ($videos[$_]{$title})", 0, 0, 0, 0);
	}
				
	# Current Lesson Bonus: Listen	
	BONUSN: for (@{ $nhash{'P'}}) {
#		print "BONUSN -$_-\n";
		$line = "$videos[$_]{$num}$videos[$_]{$sfx} ($videos[$_]{$duration})";
		INCREMENT_COUNTERS (0, 1, $videos[$_]{$duration}, 1);
		PRINT_LINE($line, 'watch_listen',	1, " ($videos[$_]{$title}:\n\t$videos[$_]{$url})", 0, 0, 0, 0);
	}
				
	### Current Lesson ((Grammar or Alphabet)): Repeat
	MAIN_N2: for (@main_lessons_n) {
#		print "MAIN_N2 -$_-\n";
		$line = "$videos[$_]{$num} ($videos[$_]{$duration})";
		# Special case for the first lesson. Because there is no previous lesson to repeat
		# you are left with a single video for a day's listening. Combine it with the next lesson.
		INCREMENT_COUNTERS (1, 1, $videos[$_]{$duration}, 1);
		my $combine = !$incl_prev && $first && !(($mode eq $unit_mode) && $xmode);
#		my $force_dy = (($mode eq $unit_mode) && $first && ($videos[$_]{$num} %2 == 1));		
#		my $force_dy = (($mode eq $unit_mode) && $xmode && $no_prev && ($videos[$_]{$num} %2 == 1));
		PRINT_LINE($line, 'watch_repeat',	1, " ($videos[$_]{$title})", $combine, 0, 0, 0);
	}
	
    # Previous Lesson Story: Repeat
	STORYP2: for (@main_stories_p) {
#		print "STORYP2 -$_-\n";
		$line = "$videos[$_]{$title} ($videos[$_]{$duration})";
		INCREMENT_COUNTERS (0, 1, $videos[$_]{$duration}, 1);
		PRINT_LINE($line, 'watch_story_repeat',	1, "", 0, 0, 0, 0);
	}
	
	# Current Lesson (Alphabet): Read Script
 	ALPHA_RD: for (@{ $nhash{'A'}}) {
#		print "ALPHA_RD -$_-\n";
		INCREMENT_COUNTERS (0, 0, $alpha_read_time, 2);
		PRINT_LINE($videos[$_]{$num},   'read_script', 	2, "", 0, 0, 0, 0);
	}
		
	# Current Lesson (Grammar only): Verse Read
	VERSE: for (@{ $nhash{'G'}}) {
		$line = B_TRANSLATE($videos[$_]{$verses});
		if ($line) {
#			print "VERSE -$_- ..$videos[$_]{$verses}..\n";
			my $str = $line;		         # Make a copy 
			my $num_verses = ($str =~ tr/,//) + 1;  # Number of verses = number of commas + 1.
			INCREMENT_COUNTERS (0, 0, $verse_read_time, 2 * $num_verses);
			PRINT_LINE($line, 'read_verse', 2, "", 0, 0, 0, 0);
		}
	}		
	
    # Related Review Videos only after even numbered lessons or the last lesson
    RELATED: if (($num_n % 2 == 0) || $last) {
    	
    	# Previous lesson (Grammar or Alphabet): Related Videos to Review
    	if (($num_n % 2 == 0) && (!$last)) {
			PROCESS_RELATED($num_p, \@main_lessons_p);
		}
		
		# Current Lesson (Grammar or Alphabet): Related Videos to Review
		PROCESS_RELATED($num_n, \@main_lessons_n);

	}
		
	# Extra Alphabet Videos only after even numbered lessons or the last lesson
    XALPHA_N: if (($num_n % 2 == 0) || $last) {
		# Previous Lesson: Extra Alphabet Videos	
		if (!$last) {
			for (@{ $phash{'L'}}) {
#				print "XALPHA_N -$_-\n";
				$line = "$num_p, $videos[$_]{$title} ($videos[$_]{$duration}),";
				if ($line) {
					INCREMENT_COUNTERS (0, 1, $videos[$_]{$duration}, 2);
					PRINT_LINE($line, 'alpha_extra', 2, "\n\t($videos[$_]{$url})", 0, 0, 0, 0);
				}
			}
		}	
		# Current Lesson: Extra Alphabet Videos	
		for (@{ $nhash{'L'}}) {
			$line = "$num_n, $videos[$_]{$title} ($videos[$_]{$duration}),";
			if ($line) {
				INCREMENT_COUNTERS (0, 1, $videos[$_]{$duration}, 2);
				PRINT_LINE($line, 'alpha_extra', 2, "\n\t($videos[$_]{$url})", 0, 0, 0, 0);
			}
		}
	
	}

	# Extra Videos only after even numbered lessons or the last lesson.
	# This are condensed versions of stories introduced in lesson videos. 
	# For optional review. Do not count as a video.
	
    EXTRA_N: if (($num_n % 2 == 0) || $last) {
		# Previous Lesson: Extra Videos	
		if (!$last) {
			for (@{ $phash{'X'}}) {
#				print "EXTRA_N -$_-\n";
				$line = "$num_p, $videos[$_]{$title} ($videos[$_]{$duration}),";
				if ($line) {
					INCREMENT_COUNTERS (0, 0, 0, 1);
					PRINT_LINE($line, 'extra', 0, "\n\t($videos[$_]{$url})", 0, 0, 0, 0);
				}
			}
		}	
		# Current Lesson: Extra Videos	
		for (@{ $nhash{'X'}}) {
			$line = "$num_n, $videos[$_]{$title} ($videos[$_]{$duration}),";
			if ($line) {
				INCREMENT_COUNTERS (0, 0, 0, 1);
				PRINT_LINE($line, 'extra', 0, "\n\t($videos[$_]{$url})", 0, 0, 0, 0);
			}
		}
	
	}

    # Current Lesson: Worship Videos	
	SONG: for (@{ $nhash{'W'}}) {
#		print "SONG -$_-\n";
		$line = "$videos[$_]{$title} ($videos[$_]{$duration})";
		INCREMENT_COUNTERS (0, 1, $videos[$_]{$duration}, 1);
		PRINT_LINE($line, 'worship', 1, "\n\t($videos[$_]{$url})", 0, 0, 0, 0);
	}
    

	#### Current Lesson: Review Game [Assumes covers 2 lessons, current & (current - 1)]
	
	REVIEW: for (@{ $nhash{'R'}}) {
#		print "REVIEW -$_-\n";
		$prev = $videos[$_]{$num} - 1;
		$review_n = "$videos[$_]{$title} ($videos[$_]{$duration})";
		INCREMENT_COUNTERS (0, 1, $videos[$_]{$duration}, 1);
		PRINT_LINE($review_n, 'review_game', 1, "\n\t($videos[$_]{$url})", 0, 0, 0, 0);
	}
	

	# Current & Previous Lesson (Grammar or Alphabet): Quizzes
	$quiz_cnt_p = 0;
	QUIZ_P: for (@main_lessons_p) {
		$quiz_cnt_p = $quiz_cnt + $videos[$_]{$quizzes};
	}
	
	$quiz_cnt_n = 0;
	QUIZ_N: for (@main_lessons_n) {
		$quiz_cnt_n = $quiz_cnt + $videos[$_]{$quizzes};
	}	


		# PRINT_QUIZ prints quizzes after even numbered lessons and after last lesson.
    PRINT_QUIZ ($num_n, $quiz_cnt_n, $num_p, $quiz_cnt_p);
    		   
	# If there more lessons to come (HOW DO I KNOW THIS?), say so.
	if ($last) {
		PRINT_TOTAL_TIME($time_count);
		print OUTFILE "\n";
	}

	if ($last && ($videos[$lesson_n[0]]{$num} < $total_lessons)) {
		PRINT_LINE("", 'more', 99, "", 0, 1, 0, 0, 0, 0);			   
		print OUTFILE "\n";
	} 
	
	if ($last) {
		if ($html_out) {
			# End MAIN section and start Footer
			print OUTFILE "<\/main>\n";
			print OUTFILE "<footer>\n<hr>\n";
			print OUTFILE "<ul class=\"times\">\n";
		}
		
		PRINT_LINE(MAKE_TIME($max_secs, 0),             'longest',    99, "", 0, 1, 0, 0);
		PRINT_LINE(MAKE_TIME($min_secs, 0),             'shortest',   99, "", 0, 1, 0, 0);
		PRINT_LINE(MAKE_TIME(int($tot_time/$tot_days)), 'average',    99, "", 0, 1, 0, 0);
		PRINT_LINE($tot_days,                           'total_days', 99, "", 0, 1, 0, 0);
		PRINT_LINE(MAKE_TIME($tot_time, 1),             'total_time', 99, "", 0, 1, 0, 0);
				
		if ($html_out) {
			print OUTFILE "<\/ul>\n\n";
			print OUTFILE "<p class='cmd'>$command<\/p>\n";  # Print options used to generate file and time stamp.
		} else {
			print OUTFILE "\n";
			print OUTFILE $command;  # Print options used to generate file and time stamp.
		}
	}
	
	
	if ($html_out) {
		print OUTFILE "$ind1<\/footer>\n";
		FINALIZE_HTML($course);
	}
	
	# Reset $first flag
	$first = 0;
	
	print "End of PRINT_LESSON\n" if $debug;
	
return;

}

################################################################################
### PRINT_LINE (text to substitute, phrase key, number of checkboxes, text to append,
###             combine day, block new day, force new day, force new week)
################################################################################
sub PRINT_LINE {
################################################################################
### Prints a line in the output Schedule file for a video or activity. 
### Determines Week and Day boundaries.
### Global Variables: %phrases, 
###		$max_count, $max_main, $vid_count, $max_vid, $lesson_count, $max_unit,
###     $time_count, $max_time, $box, $sub_char
###     $main_mode, $video_mode, $unit_mode, $time_mode
### 
###  Modes: M $max_main main videos per day plus any additional material
### 		V $max_vid  videos per day, regardless of type
### 		L $max_unit lessons per week
### 		T $max_time duration of videos per day, regardless of type
### 
################################################################################

	my $n 		   = $_[0];  # Text to substitute
	my $keyx 	   = $_[1];  # Phrase to use
	my $boxnum 	   = $_[2];  # Number of checkboxes
	my $append     = $_[3];  # Text to append at the end
	

	my $combine_day = $_[4];  # Special case in Main Mode. Combine current line with next
							  # on the first lesson when previous is not include
							  

	my $block_day   = $_[5];  # Block a new day, used when printing Quiz lines.
	my $force_day   = $_[6];  # Force a new day (Used in Unit Mode before Review Game/Quizzes)
	my $force_week  = $_[7];  # Force a new week (Used in Unit Modes when starting lesson is even or if max number of lessons is reached)
	
	
	print "PRINT_LINE Subroutine ($n, $keyx, $boxnum, $append, $combine_day, $block_day, $force_day, $force_week)\n" if $debug;
	
	# Initialize Variables
	my $line  = $phrases{$keyx};
	my $boxes = "";		
	my $i     = 0;
		
#		print OUTFILE "Block Day: $block_day, Mode: $mode, Main Count: $main_count, Force Week: $force_week, Force Day: $force_day\n";
		
	# Based on Mode, call PRINT_TIME.
	unless ($block_day) {
		for ($mode) {
			if (/$main_mode/) {
				if (($main_count > $max_main) || $force_week || $force_day)  {
					&PRINT_TIME(0, $force_week);
					if ($combine_day) { # Special case for second day, first week, no previous.
						$main_count = 0;	
					} elsif ($force_day){  # Day forced before Review/Quiz.
						$main_count = $max_main;  # Trick it into starting a new day after Review/Quiz.
					} else {
						$main_count = 1;	# Accounts for Related Videos.
					}
					$lesson_count = 1 if $force_week;
				}

			} elsif (/$video_mode/) {
				if ($vid_count > $max_vid) {
					&PRINT_TIME(0, 0);
					$vid_count = $vid_count - $max_vid; # Accounts for Related Videos.
				}	
						
			} elsif (/$unit_mode/) { # Unit Mode works like Main mode, except Week ends after quizzes.
				if ((($main_count > $max_main) || $force_week || $force_day) && !$block_day)  {
					&PRINT_TIME(0, $force_week);
					if ($combine_day) { # Special case for first lesson, no previous.
						$main_count = 0;	
					} else {
						$main_count = 1;
					}
					$lesson_count = 1 if $force_week;
				}
							
			} elsif (/$time_mode/) {
			#	print OUTIFILE "Time Mode: Time Count = $time_count, Max Time = $max_time\n";
				# Don't print time if printing quizzes. 
				if (($time_count > $max_time) && !$block_day) {
					&PRINT_TIME(0, 0);
				}
			
			} else {
			   print "Unknown Schedule Mode $mode\n";
			   exit;			
			}
		}
	}
		
	if ($boxnum == 99) {
		$boxes = "";
	} elsif ($boxnum == 0) {
		$boxes = "$bullet" . "\t";
	} else {
		while ($i < $boxnum) {
			$boxes = $boxes . "$box ";
			$i++;
		}
		$boxes = $boxes . "\t";
	}
	
	# Make the substitution
	$line =~ s/$sub_char/$n/;
	
    print  "Key: $keyx, MD $mode, CT $main_count, MX $max_main\n$line\n" if $debug;
	
	my $time_str = MAKE_TIME($time_count, 0);
	
	if ($html_out) {
	    ## Need a decision tree for $keyx.
	    my $temp = $boxes . $line . $append;
	    
		print OUTFILE URL_PARSE($keyx, "$boxes$line$append") ."\n";
		
	} else {
		print OUTFILE "$boxes$line$append";
		print OUTFILE " ($main_count, $vid_count, $lesson_count, $time_str)" if $debug;
		print OUTFILE "\n";
	}
	
	return;

}
################################################################################
### URL_PARSE ($keyx, text_string)
################################################################################
sub URL_PARSE {
################################################################################
###	Parses the text string into URL, link text, and everything else.
### 
### Returns the string with <a href=URL></a> format and other tags based on $keyx.
### 
###		Global Variables: $debug
### 
################################################################################

	my $keyx    = $_[0];	
	my $str		= $_[1];
		
	if (index($str, "http") == -1) {
	    	$temp_str = $str;
	    } else {
	    	# HTML Link in phrase
	print "String: $str\n";
	    	
			$str =~ s/(.*)\{(.*)\}(.*)\w(http.*)[\)\w]//;
			print "--$1--$2--$3--$4--$5--\n";
			$str1    = $1;
			$a_str   = $2;
			$str2    = $3;
			$url_str = $4;
			$str3    = $5;
			if (index($str2, "http") >= 0) { 
				
			
			
			}
			
  	   		$temp_str = "$str1<a target='_blank' href=$url_str>$a_str<\/a>$str2$str3";
	    }	    	    

    $html_str = "<li>$temp_str<\/li>";

	
	return $html_str;
}
################################################################################
### PRINT_TIME (Skip printing total time flag, force new week flag)
################################################################################
sub PRINT_TIME {
################################################################################
###	Prints the new week or day headings as well as calling PRINT_TOTAL_TIME to
### print the total time for the day's assignment.
###
###		Global Variables: %phrases, $week_count, $day_count, $max_day
### 				$time_count, $time_adjust, $html_out, $debug
### 
################################################################################

	my $skip_total     = $_[0];	# Don't PRINT_TOTAL_TIME at the beginning of the schedule.
	my $force_new_week = $_[1]; # Force a new week even if $mode does not require it
	
	print "PRINT_TIME Subroutine\n" if $debug;
   	
   	# Print Total count for previous day
   	PRINT_TOTAL_TIME($time_count - $time_adjust) unless $skip_total;
   	$time_count = $time_adjust;

   	
   	if (($day_count == 1) || $force_new_week) {
   		# Time for a new week. Previous Week is full.
		$day_count = 1;
		print "Reset Day count: $day_count, $week_count\n" if $debug;
		
		# Print Week Heading
   		if ($html_out) {
   		   print OUTFILE "<h2 class=\"week\">$phrases{'week'} $week_count<\/h3>\n";
   		} else {
    		print OUTFILE "\n\n\*\*\* $phrases{'week'} $week_count \*\*\*\n";	
   		}
		
		# Print Day Heading
   		if ($html_out) {
   		   print OUTFILE "<h3 class=\"day\">$phrases{'day'} $day_count<\/h3>\n";
   		   print OUTFILE $ind1 . '<ul class="check">' . "\n";
   		} else {
   		   	print OUTFILE "\n$phrases{'day'} $day_count\n";
   		}
		$week_count++;		
   	} else {
   		# Start a new day, Print Day Heading
   		if ($html_out) {
   		   print OUTFILE "<h3 class=\"day\">$phrases{'day'} $day_count<\/h3>\n";
   		   print OUTFILE $ind1 . '<ul class="check">' . "\n";

   		} else {
   		   	print OUTFILE "\n$phrases{'day'} $day_count\n";
   		}
   	}
    
	if (($day_count < $max_day)){$day_count++;} else {$day_count = 1};

    return;

}

################################################################################
### PRINT_TOTAL_TIME (time in seconds)
################################################################################
sub PRINT_TOTAL_TIME {
################################################################################
### Prints the approximate total time it will take to complete a day's videos
### and activities.
###		Global Variables: %phrases, $sub_char, $max_secs, $min_secs, 
###						  $tot_time, $tot_days
################################################################################

	my $t = $_[0];
	my $n = MAKE_TIME($t, 0);
	
	print "PRINT_TOTAL_TIME Subroutine ($n)\n" if $debug;

	## Update constants for keeping track of time numbers for bookkeeping ##
	$max_secs = max($max_secs, $t);
	$min_secs = min($min_secs, $t);
	$tot_time+= $t;
	$tot_days++;

	my $line = $phrases{'time'};
	$line =~ s/$sub_char/$n/;
	
	if ($html_out) {
		print OUTFILE "$ind1<\/ul>\n";
		print OUTFILE "$ind1<p tottime=\"day\">$line<\/p>\n\n";
	} else {
		print OUTFILE "\t$line\n";
	}
	
	return;
   	
}

################################################################################
### PRINTQUIZ (Current Lesson num, current quiz count, 
###					Prev lesson num, Prev quiz count)
################################################################################
sub PRINT_QUIZ {
################################################################################
###  Prints one line in the learning schedule per quiz for the previous and current
###  lessons when the current lesson is an even number. 
###		If the first lesson is even, then print the first lesson quizzes. 
###		If the last  lesson is odd,  then print the last  lesson quizzes. 
###
### 	Global Variables: $first, $last, $quiz_take_time, $skip_quizzes
################################################################################
	my $n    = $_[0];  # Current Lesson Number
	my $nqz  = $_[1];  # Current Lesson number of quizzes
	my $p    = $_[2];  # Previous Lesson Number
	my $pqz  = $_[3];  # Previous Lesson number of quizzes
	
	return if $skip_quiz;
	
# 	my $debug = 1;
	
	print "PRINT_QUIZ Subroutine ($n, $nqx, $p, $pqx)\n" if $debug;
	
	print OUTFILE "\n";
	if (0 == $n % 2) {  #Even numbered lesson
		QUIZ_LOOP($p, $pqz) if (!$first || ($first & $incl_prev));
		QUIZ_LOOP($n, $nqz);
		print OUTFILE "\n";
		
	}  else {  # Odd numbered lesson	
	 	if ($last) {
			QUIZ_LOOP($n, $nqz);	 	
	 	}
	}
	
	return;
		
}

################################################################################
### QUIZ_LOOP (lesson_number, quiz_count)
################################################################################
sub QUIZ_LOOP {
################################################################################
### Loop to print the correct number of quiz lines.
################################################################################
	my $lnum = $_[0];  # Lesson Nunber
	my $qcnt = $_[1];  # Number of quizzes for lesson
	
	# Keep all quizzes on the same day unless you are in time_mode.
	my $block_day = $mode ne $time_mode;
	
	print "QUIZ_LOOP Subroutine ($lnum, $qcnt)\n" if $debug;
	
#		if ($qcnt == 0) { # No quizzes exist for this lesson (yet)
#			PRINT_LINE($lnum, 'quiz_no', 0, "", 0, 0, 0, 0);
#		} else {
		if ($qcnt > 0) { # Quizzes exist for this lesson (yet)
			my $q = 1;
			QZ: while ($q <= $qcnt){
				INCREMENT_COUNTERS (0, 0, $quiz_take_time, 1);
				PRINT_LINE("$lnum.$q", 'quiz_yes', 1, "", 0, $block_day, 0, 0);
				$q++;
				next QZ;
			}		
		}
}

################################################################################
### PROCESS_RELATED (lesson_number, Array_of_videos)
################################################################################
sub PROCESS_RELATED {
	my $num = $_[0];
	my @main_lessons =  @{$_[1]};
	my $block_day;
	
	if ($mode eq $unit_mode) {
		$block_day = 1;
	} else {
		$block_day = 0;
	}
					

	
	for (@main_lessons) {
		if ($videos[$_]{$related}) {
			$related_list = $videos[$_]{$related};
			print "$related_list\n" if $debug;
			my @related_array = split(', ', $related_list);
			for (@related_array) {
				# Keep related videos on one day when in unit mode.
				INCREMENT_COUNTERS (1, 1, $related_avg_time, 1);
				PRINT_LINE($_, 'related', 1, "", 0, $block_day, 0, 0);
		
			}
		}
	}
	

}

################################################################################
### VIDEO_LIST (start_index, end_index)
################################################################################
sub VIDEO_LIST {
################################################################################
### Print list of Videos using specified range with URLs and titles at the 
### end of the Learning Schedule.
###     Global Variables: @videos
################################################################################

	my $first_ix = $_[0]; # Index for first video in array.
	my $last_ix  = $_[1]; # Index for last  video in array.	
	    
#	my $debug = 1;
	     
    my @headings = ('   Video', 'URL',   'Title');
    my @head_fmt = ("%-13s",    "%-52s", "%-50s");

    
    
	# Print Field Headings
	while (($k, $key) = each @headings) {
		printf OUTFILE $head_fmt[$k], "$key";
	} 
	print OUTFILE "\n";
	
	for (@videos[$first_ix..$last_ix]) {	
	
		my $number = sprintf("%3s", $_->{'Num'});  # Fornat Lesson Number
		

		for ($_->{'Type'}) {		
			$lesson_type = "$number (Lesson)" if /G/;
			$lesson_type = "$number (Lesson)" if /A/;
			$lesson_type = "$number (Bonus)"  if /P/;
			$lesson_type = "$number (Review)" if /R/;
			$lesson_type = "$number (Song)"   if /W/;
			$lesson_type = "$number (Story)"  if /S/;
			$lesson_type = "$number (Story)"  if /T/;
			$lesson_type = "$number (Alpha)"  if /L/;
			$lesson_type = "$number (Extra)"  if /X/;					
		}
				
		printf OUTFILE "$head_fmt[0]", $lesson_type;
		printf OUTFILE "$head_fmt[1]", $_->{@headings[1]};
		printf OUTFILE "$head_fmt[2]", $_->{@headings[2]};
		print  OUTFILE "\n";	
		
	} # End VLOOP
     
   return;
}

################################################################################
### GET_VIDEOS ($video_file,  $csv_char, $title, $title_default)
################################################################################
sub GET_VIDEOS {
################################################################################
###  Builds an Array of hashes for all videos from input file.
###       Return: @videos
###		  Global Variables: @fields, $debug
###
### 
### Syntax of Video Input File: (UTF-8, Tab-separated Values)
### First line is the list of fields. Valid fields are
###		Type		Kind of video. Determines how it is processed.
###			A: Alphabet Lesson
###			G: Grammar Lesson
###			L: aLphabet learning videos (special case)
###			P: suPplemental (a.k.a. Bonus) Lesson. (Not 'B' so that G & A will sort to the top)
###			R: Review Game Video
###			S: Easy Hebrew Story Video
###			T: Easy Bible (Tanakh) Story Video -- Treated the same as S type (Story)
###			W: Worship Song Video
###			X: Extra Video -- Many of these are stories explained in a lesson video.
###			
###		Num			Lesson Number each video is associated with
###		Title		Title of YouTube video
###		Duration	Length of video in MM:SS
###		Quiz_Count	Number of Quizzes for lesson
###		Related		Lesson videos related to the current lesson. Good for a refresher.
###		Read_Verses	Complete verses presented in Grammar and Bonus videos. 
###					For Bible Story and Extra videos, the Bible chapter(s) covered by the story.
###		URL			URL in YouTube of video
###		All_Verses	Partial verses presented in Grammar and Bonus videos. Not used.
###		Paraphrases	Passages paraphrased in Grammar and Bonus videos. Not used.
###
### There is usually only one main lesson video (Grammar or Alphabet type) but the code can handle 
### multiple videos of any type.
###
###     #########################################
### Helpful hints from Craig: (10/14-15/2021)
### Craig, are you still up on your Perl? I am writing a Perl script that uses an array of hashes.
### I can't figure out how to loop through the array and access each hash, short of stepping through 
### with an index variable. The examples I see on the web don't seem to be working.  
### If I do a "for (@array) {" How do I turn $_ into a hash? %hash = $_; doesn't seem to work.
### For that matter, %hash = $array[$index]; doesn't either. Any suggestions? I'm using Perl 5.18.4.
### Never mind. After fighting with it for the last two days, I did yet another search and found the following worked:   	
### 	for $lesson ( @all ) { 
###  		for $key ( keys %$lesson ) { 
###  			print "$key=$lesson->{$key} "; 
###  		}
###		}
### 
### Craig's Response:
### But even without it (the loop variable) you should be able to dereference 
### $_, as in "$val = $_->{$key};", inside the loop.  
### The important insight is that @all isn't an array of hashes, since arrays can't contain hashes.  
### It's an array of hash references.  So you have to include the "->" when you do keyword lookup in the array element.
### For your %hash example, you could say "%hash = %$_;" to place the referenced hash into %hash.
### Depending on how implicit you want to get, you can also use the "map {} @array" form 
### to convert your array of hashes into an array of values, as in:  "print map { "$_->{$key}\n" } @all;".
### That is sort of like the implicit-loop construct in Python, if you're familiar with that -- 
### but map{} is a little more general.
### ...and now I finally see your last message about the "%$" juxtaposition.  
### yes, but it's not the sigils that are being juxtaposed, it's "%" being juxtaposed 
### with a scalar value that evaluates to a hash ref.  You can say, for example, "%{func(@params)}" 
### (where the curlies here are making sure that the interior is executed as a functional block 
### (i.e. extended expression), returning a scalar value that is %'ed.  
### If the functional block returns something that isn't a hash ref, it'll throw an error.
### 
################################################################################

	my $vid_file = $_[0];	# Input CSV (TSV) file of videos.
	
#	my $debug = 1;

	my @vids      = ();   # Array of Hashes of Videos. 
	my @variables = ();   # Array of comma-separated values for current video
	
	print "GET_VIDEOS Subroutine\n" if $debug;
		
	open(VIDFILE, "<$vid_file") || die print "ERROR: $! ($vid_file)\n";			
	
	# First line contains field titles. Assign to fields variable.
	my $line = <VIDFILE>;
	
	$line = CLEANUP($line);
	
	@fields = split($csv_char, $line);	# Split line into fields using delimieter
		
	my $ln = 0;			# Keep track of index for array (line nunber).
	
	READV: while (<VIDFILE>){		
		$line = CLEANUP($_);
			    
	    @variables = split($csv_char, $line);
	    		
	    # Build hash for current line in video file.
	    my $ix = 0;
	    for (@variables) {	    
	    	# Strip off leading & trailing whitespace and quotation marks
	    	# Quotation marks are used when a value contains commas.
	    	$_ =~ s/^["''\s]+|["'\s]+$//g;  # Remove leading and trailing whitespace and quotation marks

	    	$vids[$ln]{$fields[$ix]} = $_;
	    	$ix++;
	    }
	    
		$ln++;
	} # End of READV
	
	
	# If language-specific title field is blank, substitute default (en_US) title.
	print "The title is $title and the default title is $title_default. There are $ln lines.\n" if $debug;
	
	if ($title ne $title_default) {
		for my $iy (0 .. $ln-1) {
		    print "Line $iy $vids[$iy]{'Duration'}\n" if $debug;
			if ($vids[$iy]{$title} eq '') {
			    print "Title should be blank -$vids[$iy]{$title}- " if $debug;
				$vids[$iy]{$title} = $vids[$iy]{$title_default};	
				print "Changed to --$vids[$iy]{$title}--\n" if $debug;
			}
		}	
	}
	
					
	close(VIDFILE);

	print "End of GET_VIDEOS\n" if $debug;
	
	return (@vids);	

} # End of GET_VIDEOS	

################################################################################
### GET_PHRASES (input_file)
################################################################################
sub GET_PHRASES {
################################################################################
### Creates the hash of phrases and hash of Bible book names from the input file. 
###       Global Variables: $debug
###       Return:  %phrase_hash, %canon
### 
### Syntax of Phrases Input File:
### 
### 	Default:
### 		<tag>Text for that tag with && character to mark where .
### 
### 		The text following the tag will be assigned to that tag in the program.
###			'&&' will be substituted with the lesson number or other specific information.
###			Some of the text is a URL. The correct link may be different for different
###				 languages.
### 		
### 
### 	Special Cases: 
###
###         <introN>, <howtoN>, and <linksN> are for the content at the 
###                beginning of the learning schedule. N will increment from 0. 
###				   the number of lines is flexible.
###                
### 		<Bible>
### 		<Book-of-the-Bible-tag>Book-of-the-Bible-name-in-target-language
###			</Bible>
### 
### 
### 		The tags <Bible> and </Bible> mark the beginning and end of   
### 			book of the bible tag/text pairs. 
### 
### 
### Comment Character: #
### 	Comments can only be full line. (One of the URLs contains a '#')
### 	Leave the Commented English template for each tag so that the translation  
### 		can be compared to the original.
### 
### Comments and blank lines will be ignored.
### 

################################################################################
	my $lang_file = $_[0];
	
	my %phrase_hash;
	my %canon_hash;	
	my $ln          = 0; 	# Keep track of line number for input file.
	my $build_canon = 0;	# Flag to keep track of Bible Books vs. normal tags
	my $line        = "";
	
	print "GET_PHRASES Subroutine.\n" if $debug;

	open(INFILE, "<$lang_file") || die "ERROR: $! ($lang_file).\n";
	
	
	READF: while (<INFILE>){
		$ln++;
		
	    $line = CLEANUP($_);
	    	
		# Check for comments and remove. Only full-line comments are allowed.
		my $cmt_ix = index($line, '#'); # Returns -1 if no occurrance.
		if ($cmt_ix == 0) { # if ($cmt_ix >= 0) allows for partial-line comments
			print "Index for comment: $cmt_ix     -$line-\n" if $debug;
			$line = substr($line, 0, $cmt_ix);
		};
				
		next READF if (length($line) == 0);  # Skip over blank lines or full-line comments
		
		$line =~ /<(.*)>(.*)/;
		my $ltag  = $1;			# Hash key
		my $ltext = $2;			# Hash value
		
		if (index($ltag, 'intro') == 0) {
			$ltag =~ /(intro)(\d+)/;
			$phrase_hash{$1}[$2] = $ltext;
			print "$1($2) is $phrase_hash{$tag}[$ix]\n" if $debug;			
		}
		
		if (index($ltag, 'howto') == 0) {
			$ltag =~ /(howto)(\d+)/;
			$phrase_hash{$1}[$2] = $ltext;
			print "$1($2) is $phrase_hash{$tag}[$ix]\n" if $debug;			
		}
		
		if (index($ltag, 'links') == 0) {
			$ltag =~ /(links)(\d+)/;
			$phrase_hash{$1}[$2] = $ltext;
			print "$1($2) is $phrase_hash{$tag}[$ix]\n" if $debug;			
		}

		if ($ltag eq 'Bible') {  # Turn on flag at start of Bible section
			$build_canon = 1;
			next READF;
		}
		if ($ltag eq '/Bible') { # Turn off flag at end of Bible section
			$build_canon = 0;
			next READF;
		}
	
		if ($build_canon) {
			$canon_hash{$ltag} = $ltext;
		} else{
			$phrase_hash{$ltag} = $ltext;		
		}

	} # End of READF
					
	close(INFILE);
	
# my $debug = 1;
	if ($debug) {
		print 'Contents of %phrase_hash:' . "\n";
		for (keys %phrase_hash){
			printf "%-20s", "$_"; print "-$phrase_hash{$_}-\n";
		}
		
		print 'Contents of %canon_hash:' . "\n";
		for (keys %canon_hash){
			printf "%-20s", "$_"; print "-$canon_hash{$_}-\n";
		}
	}
			
	return (\%phrase_hash, \%canon_hash);

} # End of GET_PHRASES

################################################################################
### INCREMENT_COUNTERS (incr_main, incr_vid, adjust_secs, adjust_factor)
################################################################################
sub INCREMENT_COUNTERS {
################################################################################
###  Global Variables: $main_count, $vid_count, $time_adjust, $time_count
################################################################################

    print OUTFILE "INCREMENT_COUNTERS Subroutine ($_[0], $_[1], $_[2], $_[3])\n"  if $debug;

	$main_count    = $main_count + $_[0];
	$vid_count 	   = $vid_count  + $_[1];
	$time_adjust   = MAKE_SECS($_[2]) * $_[3];
	$time_count    = $time_count + $time_adjust;
	
	return;
}

################################################################################
### B_TRANSLATE (Bible Verses)
################################################################################
sub B_TRANSLATE {
################################################################################
### Substitutes uses %canon to replace default Bible book names with those from  
###	target language. 
###
###  Global Variables: %canon
###  Return: Text String with replaced Bible book names
################################################################################

	my $text_str = $_[0];
#	my $debug = 1;
	
	print "B_TRANSLATE subroutine ($text_str)\n" if $debug;
	
	for $key (keys %canon) {
		$text_str =~ s/$key/$canon{$key}/g;
	}
	print "After: $text_str\n" if $debug;

	return $text_str;
}

################################################################################
### CLEANUP (text_string)
################################################################################
sub CLEANUP {
################################################################################
###    Removes UTF-8 BOM, line-breaks, and leading and trailing whitespace
### 	Returns cleans up text string.
################################################################################
	my $str = $_[0];	# Text string to be cleaned up.
	
	$str =~ s/\R//g;		 # Remove line-breaks, regardless of type or platform using.
	$str =~ s/^\x{FEFF}//;   # Remove UTF-8 BOM (ZERO WIDTH NO-BREAK SPACE (U+FEFF)) from first line if present.
	$str =~ s/^\s+|\s+$//g;  # Remove leading and trailing whitespace
	
	return $str;

}

################################################################################
### MAKE_SECS (mm:ss)
################################################################################
sub MAKE_SECS {
################################################################################
### Converts text string of form mm:ss into seconds.
###		Returns number of seconds.
################################################################################
	my $str = $_[0];
		
	$str =~ s/(\d+):(\d+)//;
	
	my $seconds = ($1 * 60) + $2;
			
	return $seconds;

}

################################################################################
### MAKE_TIME (seconds, include_hours)
################################################################################
sub MAKE_TIME {
################################################################################
### Converts numeric value of seconds to a text string of form mm:ss 
###		Returns text string of form mmm:ss or hh:mm:ss
###     Global variables: $debug
################################################################################
	my $secs = $_[0];  # Time in seconds
	my $include_hours = $_[1];
	
	print "MAKE_TIME(Seconds: $secs, Include Hours: $include_hours)\n" if $debug;
		
	my $seconds = $secs % 60;			 # Remainder after minutes divided out
	my $minutes = 0;
	my $hours   = 0;
	
	
	if (!$include_hours) {
	    $minutes = ($secs - $seconds)/60;
		$result  = sprintf "%02s:%02s", $minutes, $seconds;
	} else {
 	    $hours   = int(($secs - $seconds)/3600);
	    $minutes = (($secs - $seconds) % 3600)/60;
		$result = sprintf "%s:%02s:%02s", $hours, $minutes, $seconds;
	}
			
	print "T: $secs, H: $hours, M: $minutes, S: $seconds\n" if $debug;

	return $result;

}

################################################################################
### IS_POS_INT (value)
################################################################################
sub IS_POS_INT {
################################################################################
### Tests a variable to see if it is a positive integer.
###		Returns number of seconds.
################################################################################
	my $val = $_[0];
		
	if (looks_like_number($val) && (int($val) == $val) && ($val > 0)) {
	    return 1;
	} else {
		return 0;
	}
	
}

################################################################################
### USAGE (source)
###    Outputs help text.
################################################################################
sub USAGE {
   # Prints out the usage help for this script.
  local($src) = $_[0];

  print <<"EndOfHelp";
  usage: $src [-dhpux] [-a <ancient-language-course>][-c <vid_file delimiter>][-e <ending lesson number>]
  				[-m <max-main-videos>][-s <starting lesson number>]  [-t <mm:ss>] [-v <max-videos>]
  				[-w <days per week number>] phrase_file
  
  where:
         -d     - Set debug mode.
         -h     - Display this help text.
         -p     - Include previous lesson in the rotation for the first lesson
         -x     - Set Unit Mode, but avoids repeating a video on the same day.
         
         -a <text>     - Ancient Language course (Default = 'Aleph') Place-holder switch.
         -c <char>     - Delimiting character for video_file. (Default is Tab, \\t)
         -e <num>      - Ending Lesson (Default = max)
         -f <filename> - Set Video List File name (columns separated by delimiter character, usu. \\t (Default = AWBVideos.tsv)
         -m <num>      - Set Main Mode. (Limit each day to <num> main videos, adding in any associated videos and activities.)
         -o <filename> - Output File name (learning schedule). If not set, default is <phrase_file>_Schedule.<phrase_file extension>.  
         -s <num>      - Starting Lesson (Default = 1)
         -t <mm:ss>    - Set Time Mode. (Limit each day to mm:ss time, unless not possible.)
         -u <num>      - Set Unit Mode (Cover <num> * 2 lessons each week.) (<num> = 1 (recommended) or 2 (intensive study))
         -v <num>      - Set Video Mode. (Limit day to num total videos.)
         -w <num>      - Number of study days per week (Default = 6).
         
         phrase_file   - Input File name (Text file of language-specific phrases, Default is AWBEnglish.txt)

This program takes the video "database" and target-language-specific phrase file to generate a learning schedule for
the Aleph with Beth Hebrew learning course. It can be customized to various criteria, depending on the learner's needs.

Written in Perl v.5.18.4.  

EndOfHelp

}