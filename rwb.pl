#!/usr/bin/perl -w

#
#
# rwb.pl (Red, White, and Blue)
#
#
# Example code for EECS 339, Northwestern University
#
#
#

# The overall theory of operation of this script is as follows
#
# 1. The inputs are form parameters, if any, and a session cookie, if any. 
# 2. The session cookie contains the login credentials (User/Password).
# 3. The parameters depend on the form, but all forms have the following three
#    special parameters:
#
#         act      =  form  <the form in question> (form=base if it doesn't exist)
#         run      =  0 Or 1 <whether to run the form or not> (=0 if it doesn't exist)
#         debug    =  0 Or 1 <whether to provide debugging output or not> 
#
# 4. The script then generates relevant html based on act, run, and other 
#    parameters that are form-dependent
# 5. The script also sends back a new session cookie (allowing for logout functionality)
# 6. The script also sends back a debug cookie (allowing debug behavior to propagate
#    to child fetches)
#


#
# Debugging
#
# database input and output is paired into the two arrays noted
#
my $debug=0; # default - will be overriden by a form parameter or cookie
my @sqlinput=();
my @sqloutput=();

#
# The combination of -w and use strict enforces various 
# rules that make the script more resilient and easier to run
# as a CGI script.
#
use strict;

# The CGI web generation stuff
# This helps make it easy to generate active HTML content
# from Perl
#
# We'll use the "standard" procedural interface to CGI
# instead of the OO default interface
use CGI qw(:standard);


# The interface to the database.  The interface is essentially
# the same no matter what the backend database is.  
#
# DBI is the standard database interface for Perl. Other
# examples of such programatic interfaces are ODBC (C/C++) and JDBC (Java).
#
#
# This will also load DBD::Oracle which is the driver for
# Oracle.
use DBI;

#
#
# A module that makes it easy to parse relatively freeform
# date strings into the unix epoch time (seconds since 1970)
#
use Time::ParseDate;


my $encrypt="code";
#
# You need to override these for access to your database
#
my $dbuser="mlk673";
my $dbpasswd="z9bOpcZt0";


#
# The session cookie will contain the user's name and password so that 
# he doesn't have to type it again and again. 
#
# "RWBSession"=>"user/password"
#
# BOTH ARE UNENCRYPTED AND THE SCRIPT IS ALLOWED TO BE RUN OVER HTTP
# THIS IS FOR ILLUSTRATION PURPOSES.  IN REALITY YOU WOULD ENCRYPT THE COOKIE
# AND CONSIDER SUPPORTING ONLY HTTPS
#
my $cookiename="RWBSession";
#
# And another cookie to preserve the debug state
#
my $debugcookiename="RWBDebug";
my $locationcookiename = "Location";
#
# Get the session input and debug cookies, if any
#
my $inputcookiecontent = cookie($cookiename);
my $inputdebugcookiecontent = cookie($debugcookiename);
my $inputlocationcookiecontent = cookie($locationcookiename);
#
# Will be filled in as we process the cookies and paramters
#
my $outputcookiecontent = undef;
my $outputdebugcookiecontent = undef;
my $deletecookie=0;
my $user = undef;
my $password = undef;
my $logincomplain=0;

#
# Get the user action and whether he just wants the form or wants us to
# run the form
#
my $action;
my $run;

my %PARTYCOLOR = ('Republican' => -1,
		      'Democratic' => 1,
		      'Undecided' => 0,
		      );
if (defined(param("act"))) { 
  $action=param("act");
  if (defined(param("run"))) { 
    $run = param("run") == 1;
  } else {
    $run = 0;
  }
} else {
  $action="base";
  $run = 1;
}

my $dstr;

if (defined(param("debug"))) { 
  # parameter has priority over cookie
  if (param("debug") == 0) { 
    $debug = 0;
  } else {
    $debug = 1;
  }
} else {
  if (defined($inputdebugcookiecontent)) { 
    $debug = $inputdebugcookiecontent;
  } else {
    # debug default from script
  }
}

$outputdebugcookiecontent=$debug;

#
#
# Who is this?  Use the cookie or anonymous credentials
#
#
if (defined($inputcookiecontent)) { 
  # Has cookie, let's decode it
  ($user,$password) = split(/\//,$inputcookiecontent);
  $outputcookiecontent = $inputcookiecontent;
} else {
  # No cookie, treat as anonymous user
  ($user,$password) = ("anon","anonanon");
}

#
# Is this a login request or attempt?
# Ignore cookies in this case.
#
if ($action eq "login") { 
  if ($run) { 
    #
    # Login attempt
    #
    # Ignore any input cookie.  Just validate user and
    # generate the right output cookie, if any.
    #
    ($user,$password) = (param('user'),param('password'));
if ($user eq "root" or $user eq "anon"){}
else {$password=$password.$encrypt;}
    if (ValidUser($user,$password)) { 
      # if the user's info is OK, then give him a cookie
      # that contains his username and password 
      # the cookie will expire in one hour, forcing him to log in again
      # after one hour of inactivity.
      # Also, land him in the base query screen
      $outputcookiecontent=join("/",$user,$password);
      $action = "base";
      $run = 1;
    } else {
      # uh oh.  Bogus login attempt.  Make him try again.
      # don't give him a cookie
      $logincomplain=1;
      $action="login";
      $run = 0;
    }
  } else {
    #
    # Just a login screen request, but we should toss out any cookie
    # we were given
    #
    undef $inputcookiecontent;
    ($user,$password)=("anon","anonanon");
  }
} 


#
# If we are being asked to log out, then if 
# we have a cookie, we should delete it.
#
if ($action eq "logout") {
  $deletecookie=1;
  $action = "base";
  $user = "anon";
  $password = "anonanon";
  $run = 1;
}


my @outputcookies;

#
# OK, so now we have user/password
# and we *may* have an output cookie.   If we have a cookie, we'll send it right 
# back to the user.
#
# We force the expiration date on the generated page to be immediate so
# that the browsers won't cache it.
#
if (defined($outputcookiecontent)) { 
  my $cookie=cookie(-name=>$cookiename,
		    -value=>$outputcookiecontent,
		    -expires=>($deletecookie ? '-1h' : '+1h'));
  push @outputcookies, $cookie;
} 
#
# We also send back a debug cookie
#
#
if (defined($outputdebugcookiecontent)) { 
  my $cookie=cookie(-name=>$debugcookiename,
		    -value=>$outputdebugcookiecontent);
  push @outputcookies, $cookie;
}

#
# Headers and cookies sent back to client
#
# The page immediately expires so that it will be refetched if the
# client ever needs to update it
#
print header(-expires=>'now', -cookie=>\@outputcookies);

#
# Now we finally begin generating back HTML
#
#
#print start_html('Red, White, and Blue');
print "<html style=\"height: 100\%\">";
print "<head>";
print "<title>Red, White, and Blue</title>";
print "</head>";

print "<body style=\"height:100\%;margin:0\">";

#
# Force device width, for mobile phones, etc
#
#print "<meta name=\"viewport\" content=\"width=device-width\" />\n";

# This tells the web browser to render the page in the style
# defined in the css file
#
print "<style type=\"text/css\">\n\@import \"rwb.css\";\n</style>\n";
  

print "<center>" if !$debug;


#
#
# The remainder here is essentially a giant switch statement based
# on $action. 
#
#
#


# LOGIN
#
# Login is a special case since we handled running the filled out form up above
# in the cookie-handling code.  So, here we only show the form if needed
# 
#
if ($action eq "login") { 
  if ($logincomplain) { 
    print "Login failed.  Try again.<p>"
  } 
  if ($logincomplain or !$run) { 
    print start_form(-name=>'Login'),
      h2('Login to Red, White, and Blue'),
	"Name:",textfield(-name=>'user'),	p,
	  "Password:",password_field(-name=>'password'),p,
	    hidden(-name=>'act',default=>['login']),
	      hidden(-name=>'run',default=>['1']),
		submit,
		  end_form;
  }
}



#
# BASE
#
# The base action presents the overall page to the browser
#
#
#
if ($action eq "base") { 
  #
  # Google maps API, needed to draw the map
  #
  print "<script src=\"http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js\" type=\"text/javascript\"></script>";
  print "<script src=\"http://maps.google.com/maps/api/js?sensor=false\" type=\"text/javascript\"></script>";
  
  #
  # The Javascript portion of our app
  #
  print "<script type=\"text/javascript\" src=\"rwb.js\"> </script>";



  #
  #
  # And something to color (Red, White, or Blue)
  #
  print "<div id=\"color\" style=\"width:100\%; height:10\%\"></div>";

  #
  #
  # And a map which will be populated later
  #
  print "<div id=\"map\" style=\"width:100\%; height:80\%\"></div>";
  
  
  #
  # And a div to populate with info about nearby stuff
  #
  #
  if ($debug) {
    # visible if we are debugging
    print "<div id=\"data\" style=\:width:100\%; height:10\%\"></div>";
  } else {
    # invisible otherwise
    print "<div id=\"data\" style=\"display: none;\"></div>";
  }


   #Show The Select Form with checkboxes and dynamic cycles
  
  my @cycles_exist = sort eval{
    ExecSQL($dbuser, $dbpasswd, "select distinct cycle from cs339.committee_master","COL");
  }; 
if (!UserCan($user,"query-opinion-data")){
  print start_form
  (-name=>'selections'),
   "Select Cycles:",
   popup_menu(-name=>'Cycles', -id=>'selectcycle', -multiple=>'multiple', -values=>[@cycles_exist], -default=>'1314'),
   "Select Items:",
  checkbox(-name=>'Committees', -id=>'checkbox1', -checked=>'true'),
  checkbox(-name=>'Candidates', -id=>'checkbox2', -checked=>'true'),
  checkbox(-name=>'Individuals', -id=>'checkbox3', -checked=>'true'),
  button(-value=>'Apply', -onclick=>'ViewShift()'),
  end_form;}
else{
  print start_form
  (-name=>'selections'),
   "Select Cycles:",
   popup_menu(-name=>'Cycles', -id=>'selectcycle', -multiple=>'multiple', -values=>[@cycles_exist], -default=>'1314'),
   "Select Items:",
  checkbox(-name=>'Committees', -id=>'checkbox1', -checked=>'true'),
  checkbox(-name=>'Candidates', -id=>'checkbox2', -checked=>'true'),
  checkbox(-name=>'Individuals', -id=>'checkbox3', -checked=>'true'),
  checkbox(-name=>'Opinions', -id=>'checkbox4', -checked=>'true'),
  button(-value=>'Apply', -onclick=>'ViewShift()'),
  end_form;}



#Show the Summary Information
	print h2("Contributions Summary");
	print "<div id='comm_sum'></div>";
	print "<div id='indi_sum'></div>";
	print "<div id='opin_sum'></div>";
#Show election results

	print h2("Election Results");
	print "<div id='result_ele'></div>";



# height=1024 width=1024 id=\"info\" name=\"info\" onload=\"UpdateMap()\"></iframe>";
  

  #
  # User mods
  #
  #
  if ($user eq "anon") {
    print "<p>You are anonymous, but you can also <a href=\"rwb.pl?act=login\">login</a></p>";
  } else {
    print "<p>You are logged in as $user and can do the following:</p>";
    if (UserCan($user,"give-opinion-data")) {
      print "<p><a href=\"rwb.pl?act=give-opinion-data\">Give Opinion Of Current Location</a></p>";
    }
    if (UserCan($user,"give-cs-ind-data")) {
      print "<p><a href=\"rwb.pl?act=give-cs-ind-data\">Geolocate Individual Contributors</a></p>";
    }
    if (UserCan($user,"manage-users") || UserCan($user,"invite-users")) {
      print "<p><a href=\"rwb.pl?act=invite-user\">Invite User</a></p>";
    }
    if (UserCan($user,"manage-users") || UserCan($user,"add-users")) { 
      print "<p><a href=\"rwb.pl?act=add-user\">Add User</a></p>";
    } 
    if (UserCan($user,"manage-users")) { 
      print "<p><a href=\"rwb.pl?act=delete-user\">Delete User</a></p>";
      print "<p><a href=\"rwb.pl?act=add-perm-user\">Add User Permission</a></p>";
      print "<p><a href=\"rwb.pl?act=revoke-perm-user\">Revoke User Permission</a></p>";
    }
    print "<p><a href=\"rwb.pl?act=logout&run=1\">Logout</a></p>";
  }

}

#
#
# NEAR
#
#
# Nearby committees, candidates, individuals, and opinions
#
#
# Note that the individual data should integrate the FEC data and the more
# precise crowd-sourced location data.   The opinion data is completely crowd-sourced
#
# This form intentionally avoids decoration since the expectation is that
# the client-side javascript will invoke it to get raw data for overlaying on the map
#
#
if ($action eq "near") {
  my $latne = param("latne");
  my $longne = param("longne");
  my $latsw = param("latsw");
  my $longsw = param("longsw");
  my $whatparam = param("what");
  my $format = param("format");
  my $cycle = param("cycle");
  my %what;
  
  $format = "table" if !defined($format);
  $cycle = "1112" if !defined($cycle);


#print $cycle;

#Transform the into right format
my @cycle_list = map {"\'" . "$_" . "\'"} split(/\s*,\s*/,$cycle);
#print @cyclelist;    

my $cyclelist = join(', ', @cycle_list);
#print  $cycle_in;


my ($ee,$E_R)=Election_results($cyclelist);




if (!defined($whatparam) || $whatparam eq "all") { 
    %what = ( committees => 1, 
	      candidates => 1,
	      individuals =>1,
	      opinions => 1);
  } else {
    map {$what{$_}=1} split(/\s*,\s*/,$whatparam);
  }
	       

  if ($what{committees}) { 
    my ($str,$error) = Committees($latne,$longne,$latsw,$longsw,$cycle,$format);
    if (!$error) {
      if ($format eq "table") { 
	print "<h2>Nearby committees</h2>$str";
      } else {
	print $str;
      }
    }
  }
  if ($what{candidates}) {
    my ($str,$error) = Candidates($latne,$longne,$latsw,$longsw,$cycle,$format);
    if (!$error) {
      if ($format eq "table") { 
	print "<h2>Nearby candidates</h2>$str";
      } else {
	print $str;
      }
    }
  }
  if ($what{individuals}) {
    my ($str,$error) = Individuals($latne,$longne,$latsw,$longsw,$cycle,$format);
    if (!$error) {
      if ($format eq "table") { 
	print "<h2>Nearby individuals</h2>$str";
      } else {
	print $str;
      }
    }
  }
  if ($what{opinions}) {
    my ($str,$error) = Opinions($latne,$longne,$latsw,$longsw,$cycle,$format);
    if (!$error) {
      if ($format eq "table") { 
	print "<h2>Nearby opinions</h2>$str";
      } else {
	print $str;
      }
    }
  }
}


if ($action eq "invite-user") {
   
	if(!UserCan($user,"invite-users")){
		print h2('You do not have the permission to invite users.');
	}else{
	      if (!$run) {
my @permlist;
 eval { @permlist = ExecSQL($dbuser, $dbpasswd, "select action from rwb_permissions where name=?","COL",$user); };
print $user;
#my $test=join(",",@permlist);
#print $test;
# foreach my $test(@permlist){
#print '$test';
#     	
    	print start_form(-name=>'InviteUser'),
		h2('Invite User'),
		"Email: ", textfield(-name=>'email'),
		p,
                
		hidden(-name=>'run',-default=>['1']),
		hidden(-name=>'act',-default=>['invite-user']),
                checkbox_group(-name=>'perm',-value=>[@permlist]),
#                "manage-users",checkbox(-name=>'perm',-value=>'manage-users'),
#                "invite-users",checkbox(-name=>'perm',-value=>'invite-users'),
#                "add-users",checkbox(-name=>'perm',-value=>'add-users'),
#                "query-cs-ind-data",checkbox(-name=>'perm',-value=>'query-cs-ind-data'),
#                "give-cs-ind-data",checkbox(-name=>'perm',-value=>'give-cs-ind-data'),
#                "give-opinion-data",checkbox(-name=>'perm',-value=>'give-opinion-data'),
	       submit,
               end_form,
               	
               hr;
		
#               if(UserCan($user,"manage-users")){
#print "manage-users",checkbox(-name=>'perm',-value=>'0')};
#print "invite-users",checkbox(-name=>'perm',-value=>'1');
#               if(UserCan($user,"add-users")){
#print "add-users",checkbox(-name=>'perm',-value=>'2')};
#               if(UserCan($user,"query-cs-ind-data")){
#print "query-cs-ind-data",checkbox(-name=>'perm',-value=>'3')};
#               if(UserCan($user,"give-cs-ind-data")){
#print "give-cs-ind-data",checkbox(-name=>'perm',-value=>'4')};
#               if(UserCan($user,"give-opinion-data")){
#print "give-opinion-data",checkbox(-name=>'perm',-value=>'5')};
               
               

               
	       }else{
                

                 my $perm0;

                  my @checks = param('perm');
                  $perm0=join(',',@checks);
                 
#                  foreach(@checks){
#if ($_ eq "0") $perm0=1;}
                  my $uuid=int(rand(10000));
                  my $used=0;
		  my $link="http://murphy.wot.eecs.northwestern.edu/~mlk673/rwb/rwb.pl?act=create-account&refer=$user&perm0=$perm0&uuid=$uuid";
	eval { ExecSQL($dbuser,$dbpasswd,
"insert into rwb_uuid (id, used) values (?,?)",undef,$uuid, $used);
};
		  my $email=param('email');
		  my $subject="You-are-invited-to-RWB-with-your-new-accout";
		  my $content="Click the link below to setup your account. \n\n\n $link";
		  open(MAIL,"| mail -s $subject $email")or die "Can't run mail\n";
		  print MAIL $content;
		  close(MAIL);
		  print "The invitation from $user has been sent to $email";
}
}
	print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}
if ($action eq "create-account"){
my $perm0=param('perm0');
my $uuid=param('uuid');
my @used = eval { ExecSQL($dbuser,$dbpasswd,
"select used from rwb_uuid where id=?",undef,$uuid);
};

my $rowref = $used[0];
my $used_num = @{$rowref}[0];
if ($used_num) {
print h2('This link has already been used to register, sorry!');}
           else{
if(!$run) {
print $perm0;
my @perm=split(',',$perm0);


print start_form(-name=>'register'),
h2('Register'),
"E-mail: ", textfield(-name=>'email'),
p,
"Username: ", textfield(-name=>'username'),
p,
"Password: ", textfield(-name=>'password'),
p,
hidden(-name=>'run',-default=>['1']),
hidden(-name=>'refer',-default=>[param('refer')]),
hidden(-name=>'act',-default=>['register']),
hidden(-name=>'perm',-default=>[param('perm')]),
submit, end_form, hr;
}else{
my $username=param('username');
my $password=param('password');
my $email=param('email');
my $refer=param('refer');
my @perm=param('perm');

$password=$password.$encrypt;
my $error = UserAdd($username, $password, $email, $refer);
if ($error) {
print "Could not complete registration because: $error";
            }
 else {
my $flag=1;
foreach (@perm){
my $cerror=GiveUserPerm($username,"$_");

	if ($cerror) {
print "Can't add a permission to user because: $cerror";
  $flag=0;           }

               }
if ($flag) {print "Add permission successfully";}
      }
     }
    }
}


if ($action eq "give-opinion-data") { 
  #print h2("Giving Location Opinion Data Is Unimplemented");
	my $run = param('run');
	my $party = param('party_affiliation');
	my ($lat,$lng) = (undef,undef);
	
        if (defined($inputlocationcookiecontent)) { 
		($lat,$lng) = split(/\//,$inputlocationcookiecontent);
	}

	if (!$run) {
		print h2("GIVE YOUR OPINION");
		print start_form(-name-'GiveOpinion'),
		      radio_group(-name=>'party_affiliation', -values=>['Republican','Democratic','Undecided']),
		      hidden(-name=>'run',-default=>['1']),
		      hidden(-name=>'lat',-default=>[param('lat')]),
	
	      hidden(-name=>'lng',-default=>[param('lng')]),
		      hidden(-name=>'act',-default=>['give-opinion-data']);
		print p("*Attention: once clicking submit, a pin marking your current location and you opinion will be added to the map.");
		print submit, end_form;
		print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
	} else {
		if (defined($lat) && defined($lng)) {
			eval { 
				ExecSQL($dbuser,$dbpasswd,"insert into rwb_opinions (submitter,color,latitude,longitude) values (?,?,?,?)",undef,$user,$PARTYCOLOR{$party},$lat,$lng);
			};
			print "$user, $PARTYCOLOR{$party},$lat,$lng";
			print h2("Thank you. Your opinion has been recorded at ($lat, $lng).");
		} else {
			print "<p>Oops, couldn't get your location. Are cookies enabled?</p>";
		}
		print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
	}

}

if ($action eq "give-cs-ind-data") { 
  print h2("Giving Crowd-sourced Individual Geolocations Is Unimplemented");
}

#
# ADD-USER
#
# User Add functionaltiy 
#
#
#
#
if ($action eq "add-user") { 
  if (!UserCan($user,"add-users") && !UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to add users.');
  } else {
    if (!$run) { 
 
      print start_form(-name=>'AddUser'),
	h2('Add User'),
	  "Name: ", textfield(-name=>'name'),
	    p,
	      "Email: ", textfield(-name=>'email'),
		p,
		  "Password: ", textfield(-name=>'password'),
		    p,
		      hidden(-name=>'run',-default=>['1']),
			hidden(-name=>'act',-default=>['add-user']),
			  submit,
			    end_form,
			      hr;
    } else {
      my $name=param('name');
      my $email=param('email');
      my $password=param('password');
      my $error;
$password=$password.$encrypt;
      $error=UserAdd($name,$password,$email,$user);
      if ($error) { 
	print "Can't add user because: $error";
      } else {
	print "Added user $name $email as referred by $user\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}

#
# DELETE-USER
#
# User Delete functionaltiy 
#
#
#
#
if ($action eq "delete-user") { 
  if (!UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to delete users.');
  } else {
    if (!$run) { 
      #
      # Generate the add form.
      #
      print start_form(-name=>'DeleteUser'),
	h2('Delete User'),
	  "Name: ", textfield(-name=>'name'),
	    p,
	      hidden(-name=>'run',-default=>['1']),
		hidden(-name=>'act',-default=>['delete-user']),
		  submit,
		    end_form,
		      hr;
    } else {
      my $name=param('name');
      my $error;
      $error=UserDel($name);
      if ($error) { 
	print "Can't delete user because: $error";
      } else {
	print "Deleted user $name\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}


#
# ADD-PERM-USER
#
# User Add Permission functionaltiy 
#
#
#
#
if ($action eq "add-perm-user") { 
  if (!UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to manage user permissions.');
  } else {
    if (!$run) { 
      #
      # Generate the add form.
      #
      print start_form(-name=>'AddUserPerm'),
	h2('Add User Permission'),
	  "Name: ", textfield(-name=>'name'),
	    "Permission: ", textfield(-name=>'permission'),
	      p,
		hidden(-name=>'run',-default=>['1']),
		  hidden(-name=>'act',-default=>['add-perm-user']),
		  submit,
		    end_form,
		      hr;
      my ($table,$error);
      ($table,$error)=PermTable();
      if (!$error) { 
	print "<h2>Available Permissions</h2>$table";
      }
    } else {
      my $name=param('name');
      my $perm=param('permission');
      my $error=GiveUserPerm($name,$perm);
      if ($error) { 
	print "Can't add permission to user because: $error";
      } else {
	print "Gave user $name permission $perm\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}


#
# REVOKE-PERM-USER
#
# User Permission Revocation functionaltiy 
#
#
#
#
if ($action eq "revoke-perm-user") { 
  if (!UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to manage user permissions.');
  } else {
    if (!$run) { 
      #
      # Generate the add form.
      #
      print start_form(-name=>'RevokeUserPerm'),
	h2('Revoke User Permission'),
	  "Name: ", textfield(-name=>'name'),
	    "Permission: ", textfield(-name=>'permission'),
	      p,
		hidden(-name=>'run',-default=>['1']),
		  hidden(-name=>'act',-default=>['revoke-perm-user']),
		  submit,
		    end_form,
		      hr;
      my ($table,$error);
      ($table,$error)=PermTable();
      if (!$error) { 
	print "<h2>Available Permissions</h2>$table";
      }
    } else {
      my $name=param('name');
      my $perm=param('permission');
      my $error=RevokeUserPerm($name,$perm);
      if ($error) { 
	print "Can't revoke permission from user because: $error";
      } else {
	print "Revoked user $name permission $perm\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}



#
#
#
#
# Debugging output is the last thing we show, if it is set
#
#
#
#

print "</center>" if !$debug;

#
# Generate debugging output if anything is enabled.
#
#
if ($debug) {
  print hr, p, hr,p, h2('Debugging Output');
  print h3('Parameters');
  print "<menu>";
  print map { "<li>$_ => ".escapeHTML(param($_)) } param();
  print "</menu>";
  print h3('Cookies');
  print "<menu>";
  print map { "<li>$_ => ".escapeHTML(cookie($_))} cookie();
  print "</menu>";
  my $max= $#sqlinput>$#sqloutput ? $#sqlinput : $#sqloutput;
  print h3('SQL');
  print "<menu>";
  for (my $i=0;$i<=$max;$i++) { 
    print "<li><b>Input:</b> ".escapeHTML($sqlinput[$i]);
    print "<li><b>Output:</b> $sqloutput[$i]";
  }
  print "</menu>";
}

print end_html;

#
# The main line is finished at this point. 
# The remainder includes utilty and other functions
#

#select the election cycle results from the rwb_electionresults table
sub Election_results{

my ($cyclelist)=@_;


my $format = "table";


my @rows;



eval { @rows = ExecSQL($dbuser, $dbpasswd, "select * from rwb_electionresults where cycle in ($cyclelist)",undef);};

=pod

my @contrib1;
my @contrib2;
my @contrib3;
my @contrib4;
my @contrib5;
my @contrib6;

eval {@contrib1 = ExecSQL($dbuser, $dbpasswd, "select sum(transaction_amnt) from cs339.comm_to_cand where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('REP','rep','Rep','R')) ",undef);  };
eval {@contrib2 = ExecSQL($dbuser, $dbpasswd, "select sum(transaction_amnt) from cs339.comm_to_comm where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('REP','rep','Rep','R')) ",undef);  };
eval {@contrib3 = ExecSQL($dbuser, $dbpasswd, "select sum(transaction_amnt) from cs339.individual where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('REP','rep','Rep','R'))" ,undef); };

eval {@contrib4 = ExecSQL($dbuser, $dbpasswd, "select sum(transaction_amnt) from cs339.comm_to_cand where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('DEM','dem','Dem','D','d')) ",undef);  };
eval {@contrib5 = ExecSQL($dbuser, $dbpasswd, "select sum(transaction_amnt) from cs339.comm_to_comm where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('DEM','dem','Dem','D','d')) ",undef);  };
eval {@contrib6 = ExecSQL($dbuser, $dbpasswd, "select sum(transaction_amnt) from cs339.individual where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('DEM','dem','Dem','D','d'))",undef); };
my $contrib_rep=$contrib1[0]+$contrib2[0]+$contrib3[0];
my $contrib_dem=$contrib4[0]+$contrib5[0]+$contrib6[0];




my $eleresult=$contest[0];
my $cycleyear=@{$eleresult}[0];
my $people=@{$eleresult}[1];
my $party=@{$eleresult}[2];


print "<div id='ele_result'>";

print "<table><tr>
<td>Cycle:$cycleyear</td>
<td>President:$people</td>
<td>Party:$party</td>
<td>Contrib_REP:$contrib_rep</td>
<td>Contrib_REP:$contrib_dem</td>

</tr></table>";

print "</div>";

=cut

print "<div id='ele_result'>";


my $eleresult=MakeTable("ele_result","2D",["Cycle", "President", "Party"],@rows);

print $eleresult;


print "</div>";

}



#
# Generate a table of nearby committees
# ($table|$raw,$error) = Committees(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Committees {
  my ($latne,$longne,$latsw,$longsw,$cyclelist,$format) = @_;
  my @rows;
  eval { 
    @rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, cmte_nm, cmte_pty_affiliation, cmte_st1, cmte_st2, cmte_city, cmte_st, cmte_zip from cs339.committee_master natural join cs339.cmte_id_to_geo where cycle IN ($cyclelist) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);
  };
  
 
#select the summary of contributions to REP and DEM
  my @rep_cand;
  my @rep_comm;

  eval { @rep_cand = ExecSQL($dbuser, $dbpasswd, "select sum(transaction_amnt), count(transaction_amnt),max(transaction_amnt) from (cs339.comm_to_cand natural join cs339.cmte_id_to_geo) where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('REP','rep','Rep','R')) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);  };

eval { @rep_comm = ExecSQL($dbuser, $dbpasswd, "select sum(transaction_amnt), count(transaction_amnt),max(transaction_amnt) from (cs339.comm_to_comm natural join cs339.cmte_id_to_geo) where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('REP','rep','Rep','R')) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);  };
  
 my @dem_cand;
 my @dem_comm;

eval { @dem_cand = ExecSQL($dbuser,$dbpasswd,"select sum(transaction_amnt), count(transaction_amnt),max(transaction_amnt) from (cs339.comm_to_cand natural join cs339.cmte_id_to_geo) where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('DEM','dem','Dem','D','d')) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };

eval { @dem_comm = ExecSQL($dbuser,$dbpasswd,"select sum(transaction_amnt), count(transaction_amnt),max(transaction_amnt) from (cs339.comm_to_comm natural join cs339.cmte_id_to_geo) where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('DEM','dem','Dem','D','d')) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
  
my ($temp1,$temp2) = ($rep_cand[0],$dem_cand[0]);
my ($temp3,$temp4) = ($rep_comm[0],$dem_comm[0]);

my $contrib_count = @{$temp1}[1] + @{$temp2}[1]+@{$temp3}[1] + @{$temp4}[1];
my $rep_cand_max=@{$temp1}[2];
my $rep_comm_max=@{$temp2}[2];
my $dem_cand_max=@{$temp3}[2];
my $dem_comm_max=@{$temp4}[2];



if ($contrib_count <20) {
		$latne += 0.1;
		$latsw -= 0.1;
		$longne += 0.1;
		$longsw -= 0.1;

eval { @rep_cand = ExecSQL($dbuser, $dbpasswd, "select sum(transaction_amnt), count(transaction_amnt),max(transaction_amnt) from (cs339.comm_to_cand natural join cs339.cmte_id_to_geo) where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('REP','rep','Rep','R')) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);  };

eval { @rep_comm = ExecSQL($dbuser, $dbpasswd, "select sum(transaction_amnt), count(transaction_amnt),max(transaction_amnt) from (cs339.comm_to_comm natural join cs339.cmte_id_to_geo) where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('REP','rep','Rep','R')) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);  };
  

  eval { @dem_cand = ExecSQL($dbuser,$dbpasswd,"select sum(transaction_amnt), count(transaction_amnt),max(transaction_amnt) from (cs339.comm_to_cand natural join cs339.cmte_id_to_geo) where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('DEM','dem','Dem','D','d')) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };

eval { @dem_comm = ExecSQL($dbuser,$dbpasswd,"select sum(transaction_amnt), count(transaction_amnt),max(transaction_amnt) from (cs339.comm_to_comm natural join cs339.cmte_id_to_geo) where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('DEM','dem','Dem','D','d')) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
  
 ($temp1,$temp2) = ($rep_cand[0],$dem_cand[0]);
 ($temp3,$temp4) = ($rep_comm[0],$dem_comm[0]);
 $contrib_count = @{$temp1}[1] + @{$temp2}[1]+@{$temp3}[1] + @{$temp4}[1];
 $rep_cand_max=@{$temp1}[2];
 $rep_comm_max=@{$temp2}[2];
 $dem_cand_max=@{$temp3}[2];
 $dem_comm_max=@{$temp4}[2];
	}


	my $repsum = @{$temp1}[0]+@{$temp3}[0];
        $repsum == '' ? ($repsum = '0') : undef;
	my $demsum = @{$temp2}[0]+@{$temp4}[0];
        $demsum == '' ? ($demsum = '0') : undef;

	my ($diff,$color) = ($repsum - $demsum, 'white');
	if ($diff > 0) {
		$color = 'red';
	} elsif ($diff < 0) {
		$color = 'blue';
	}

print "<div id='sum_comm'>";

print "<table bgcolor='$color'><tr>
<td>COMM-REP-SUM:$repsum</td>
<td>COMM-DEM-SUM:$demsum</td>
<td>Diff-R-D:$diff</td>
<td>REP-CAND-MAX:$rep_cand_max</td>
<td>REP-COMM-MAX:$rep_comm_max</td>
<td>DEM-CAND-MAX:$dem_cand_max</td>
<td>DEM-COMM-MAX:$dem_comm_max</td>
</tr></table>";

print "</div>";




		  
 if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") { 
      return (MakeTable("committee_data","2D",
			["latitude", "longitude", "name", "party", "street1", "street2", "city", "state", "zip"],
			@rows),$@);
    } else {
      return (MakeRaw("committee_data","2D",@rows),$@);
    }
  }




}





#
# Generate a table of nearby candidates
# ($table|$raw,$error) = Committees(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Candidates {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
  my @rows;
  eval { 
    @rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, cand_name, cand_pty_affiliation, cand_st1, cand_st2, cand_city, cand_st, cand_zip from cs339.candidate_master natural join cs339.cand_id_to_geo where cycle=? and latitude>? and latitude<? and longitude>? and longitude<?",undef,$cycle,$latsw,$latne,$longsw,$longne);
  };
  
  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") {
      return (MakeTable("candidate_data", "2D",
			["latitude", "longitude", "name", "party", "street1", "street2", "city", "state", "zip"],
			@rows),$@);
    } else {
      return (MakeRaw("candidate_data","2D",@rows),$@);
    }
  }
}


#
# Generate a table of nearby individuals
#
# Note that the handout version does not integrate the crowd-sourced data
#
# ($table|$raw,$error) = Individuals(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Individuals {
  my ($latne,$longne,$latsw,$longsw,$cyclelist,$format) = @_;
  my @rows;
  eval { 
    @rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, name, city, state, zip_code, employer, transaction_amnt from cs339.individual natural join cs339.ind_to_geo where cycle IN ($cyclelist) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);
  };




#select the summary of contributions to REP and DEM
  my @rep;
  eval { @rep = ExecSQL($dbuser, $dbpasswd, "select sum(transaction_amnt), count(transaction_amnt) from (cs339.individual natural join cs339.ind_to_geo) where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('REP','rep','Rep','R')) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };

  my @dem;
  eval { @dem = ExecSQL($dbuser,$dbpasswd,"select sum(transaction_amnt), count(transaction_amnt) from (cs339.individual natural join cs339.ind_to_geo) where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('DEM','dem','Dem','D','d')) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
  
  my ($temp1,$temp2) = ($rep[0],$dem[0]);
  my $contrib_count = @{$temp1}[1] + @{$temp2}[1];






  if ($contrib_count < 20) {
		$latne += 0.1;
		$latsw -= 0.1;
		$longne += 0.1;
		$longsw -= 0.1;

  eval { @rep = ExecSQL($dbuser, $dbpasswd, "select sum(transaction_amnt), count(transaction_amnt) from (cs339.individual natural join cs339.ind_to_geo) where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('REP','rep','Rep','R')) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };


  eval { @dem = ExecSQL($dbuser,$dbpasswd,"select sum(transaction_amnt), count(transaction_amnt) from (cs339.individual natural join cs339.ind_to_geo) where cycle IN ($cyclelist) and CMTE_ID in (select CMTE_ID from cs339.committee_master where CMTE_PTY_AFFILIATION in ('DEM','dem','Dem','D','d')) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };

		($temp1,$temp2) = ($rep[0],$dem[0]);
		$contrib_count = @{$temp1}[1] + @{$temp2}[1];
	
	}



	my $repsum = @{$temp1}[0];
	$repsum == '' ? ($repsum = '0') : undef;
	my $demsum = @{$temp2}[0];
	$demsum == '' ? ($demsum = '0') : undef;
	my ($diff,$color) = ($repsum - $demsum, 'white');
	if ($diff > 0) {
		$color = 'red';
	} elsif ($diff < 0) {
		$color = 'blue';
	}

print "<div id = 'sum_indi'>";

print "<table bgcolor='$color'><tr>
<td>INDI-REP:$repsum</td>
<td>INDI-DEM:$demsum</td>
<td>Diff-R-D:$diff</td>
</tr></table>";

print "</div>";





  
  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") { 
      return (MakeTable("individual_data", "2D",
			["latitude", "longitude", "name", "city", "state", "zip", "employer", "amount"],
			@rows),$@);
    } else {
      return (MakeRaw("individual_data","2D",@rows),$@);
    }
  }
}


#
# Generate a table of nearby opinions
#
# ($table|$raw,$error) = Opinions(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Opinions {
  my ($latne, $longne, $latsw, $longsw, $cyclelist,$format) = @_;
  my @rows;
  eval { 
    @rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, color from rwb_opinions where latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);
  };


#select the summary of contributions to REP and DEM
  my @rep;
  eval { @rep = ExecSQL($dbuser, $dbpasswd, "select sum(color), count(color) from rwb_opinions where color=-1 and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
  
  my @dem;
  eval { @dem = ExecSQL($dbuser,$dbpasswd,"select sum(color), count(color) from rwb_opinions where color=1 and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
  
  my ($temp1,$temp2) = ($rep[0],$dem[0]);
  my $contrib_count = @{$temp1}[1] + @{$temp2}[1];


  if ($contrib_count < 10) {
		$latne += 0.1;
		$latsw -= 0.1;
		$longne += 0.1;
		$longsw -= 0.1;

  eval { @rep = ExecSQL($dbuser, $dbpasswd, "select sum(color), count(color) from rwb_opinions where color=-1 and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
  

  eval { @dem = ExecSQL($dbuser,$dbpasswd,"select sum(color), count(color) from rwb_opinions where color=1 and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };

		($temp1,$temp2) = ($rep[0],$dem[0]);
		$contrib_count = @{$temp1}[1] + @{$temp2}[1];
	
	}
  


	my $repsum = @{$temp1}[0];
	$repsum == '' ? ($repsum = '0') : undef;
	my $demsum = @{$temp2}[0];
	$demsum == '' ? ($demsum = '0') : undef;
	my ($diff,$color) = ($repsum + $demsum, 'white');
	if ($diff < 0) {
		$color = 'red';
	} elsif ($diff > 0) {
		$color = 'blue';
	}


my @stats;
	eval { @stats = ExecSQL($dbuser, $dbpasswd, "select avg(color), stddev(color) from rwb_opinions where latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
	my $temp3 = $stats[0];
	my $avg = @{$temp3}[0];
        $avg = sprintf "%.3f",$avg;
	my $stddev = @{$temp3}[1];
        $stddev = sprintf "%.3f",$stddev;
        

print "<div id='sum_opin'>";

print "<table bgcolor='$color'><tr>
<td>Opinions to REP:$repsum</td>
<td>Opinions to DEM:$demsum</td>
<td>Diff-R-D:$diff</td>
<td>Average:$avg</td>
<td>Standard deviation:$stddev</td>
</tr></table>";

print "</div>";


  
  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") { 
      return (MakeTable("opinion_data","2D",
			["latitude", "longitude", "name", "city", "state", "zip", "employer", "amount"],
			@rows),$@);
    } else {
      return (MakeRaw("opinion_data","2D",@rows),$@);
    }
  }
}


#
# Generate a table of available permissions
# ($table,$error) = PermTable()
# $error false on success, error string on failure
#
sub PermTable {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select action from rwb_actions"); }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("perm_table",
		      "2D",
		     ["Perm"],
		     @rows),$@);
  }
}



#
# Generate a table of available permissions
# ($table,$error) = PermTable()
# $error false on success, error string on failure
#
sub PermTable {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select action from rwb_actions"); }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("perm_table",
		      "2D",
		     ["Perm"],
		     @rows),$@);
  }
}

#
# Generate a table of users
# ($table,$error) = UserTable()
# $error false on success, error string on failure
#
sub UserTable {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select name, email from rwb_users order by name"); }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("user_table",
		      "2D",
		     ["Name", "Email"],
		     @rows),$@);
  }
}

#
# Generate a table of users and their permissions
# ($table,$error) = UserPermTable()
# $error false on success, error string on failure
#
sub UserPermTable {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select rwb_users.name, rwb_permissions.action from rwb_users, rwb_permissions where rwb_users.name=rwb_permissions.name order by rwb_users.name"); }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("userperm_table",
		      "2D",
		     ["Name", "Permission"],
		     @rows),$@);
  }
}

#
# Add a user
# call with name,password,email
#
# returns false on success, error string on failure.
# 
# UserAdd($name,$password,$email)
#
sub UserAdd { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "insert into rwb_users (name,password,email,referer) values (?,?,?,?)",undef,@_);};
  return $@;
}

#
# Delete a user
# returns false on success, $error string on failure
# 
sub UserDel { 
  eval {ExecSQL($dbuser,$dbpasswd,"delete from rwb_users where name=?", undef, @_);};
  return $@;
}


#
# Give a user a permission
#
# returns false on success, error string on failure.
# 
# GiveUserPerm($name,$perm)
#
sub GiveUserPerm { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "insert into rwb_permissions (name,action) values (?,?)",undef,@_);};
  return $@;
}

#
# Revoke a user's permission
#
# returns false on success, error string on failure.
# 
# RevokeUserPerm($name,$perm)
#
sub RevokeUserPerm { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "delete from rwb_permissions where name=? and action=?",undef,@_);};
  return $@;
}

#
#
# Check to see if user and password combination exist
#
# $ok = ValidUser($user,$password)
#
#
sub ValidUser {
  my ($user,$password)=@_;
  my @col;
  eval {@col=ExecSQL($dbuser,$dbpasswd, "select count(*) from rwb_users where name=? and password=?","COL",$user,$password);};
  if ($@) { 
    return 0;
  } else {
    return $col[0]>0;
  }
}


#
#
# Check to see if user can do some action
#
# $ok = UserCan($user,$action)
#
sub UserCan {
  my ($user,$action)=@_;
  my @col;
  eval {@col= ExecSQL($dbuser,$dbpasswd, "select count(*) from rwb_permissions where name=? and action=?","COL",$user,$action);};
  if ($@) { 
    return 0;
  } else {
    return $col[0]>0;
  }
}





#
# Given a list of scalars, or a list of references to lists, generates
# an html table
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
# $headerlistref points to a list of header columns
#
#
# $html = MakeTable($id, $type, $headerlistref,@list);
#
sub MakeTable {
  my ($id,$type,$headerlistref,@list)=@_;
  my $out;
  #
  # Check to see if there is anything to output
  #
  if ((defined $headerlistref) || ($#list>=0)) {
    # if there is, begin a table
    #
    $out="<table id=\"$id\" border>";
    #
    # if there is a header list, then output it in bold
    #
    if (defined $headerlistref) { 
      $out.="<tr>".join("",(map {"<td><b>$_</b></td>"} @{$headerlistref}))."</tr>";
    }
    #
    # If it's a single row, just output it in an obvious way
    #
    if ($type eq "ROW") { 
      #
      # map {code} @list means "apply this code to every member of the list
      # and return the modified list.  $_ is the current list member
      #
      $out.="<tr>".(map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>" } @list)."</tr>";
    } elsif ($type eq "COL") { 
      #
      # ditto for a single column
      #
      $out.=join("",map {defined($_) ? "<tr><td>$_</td></tr>" : "<tr><td>(null)</td></tr>"} @list);
    } else { 
      #
      # For a 2D table, it's a bit more complicated...
      #
      $out.= join("",map {"<tr>$_</tr>"} (map {join("",map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>"} @{$_})} @list));
    }
    $out.="</table>";
  } else {
    # if no header row or list, then just say none.
    $out.="(none)";
  }
  return $out;
}


#
# Given a list of scalars, or a list of references to lists, generates
# an HTML <pre> section, one line per row, columns are tab-deliminted
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
#
# $html = MakeRaw($id, $type, @list);
#
sub MakeRaw {
  my ($id, $type,@list)=@_;
  my $out;
  #
  # Check to see if there is anything to output
  #
  $out="<pre id=\"$id\">\n";
  #
  # If it's a single row, just output it in an obvious way
  #
  if ($type eq "ROW") { 
    #
    # map {code} @list means "apply this code to every member of the list
    # and return the modified list.  $_ is the current list member
    #
    $out.=join("\t",map { defined($_) ? $_ : "(null)" } @list);
    $out.="\n";
  } elsif ($type eq "COL") { 
    #
    # ditto for a single column
    #
    $out.=join("\n",map { defined($_) ? $_ : "(null)" } @list);
    $out.="\n";
  } else {
    #
    # For a 2D table
    #
    foreach my $r (@list) { 
      $out.= join("\t", map { defined($_) ? $_ : "(null)" } @{$r});
      $out.="\n";
    }
  }
  $out.="</pre>\n";
  return $out;
}

#
# @list=ExecSQL($user, $password, $querystring, $type, @fill);
#
# Executes a SQL statement.  If $type is "ROW", returns first row in list
# if $type is "COL" returns first column.  Otherwise, returns
# the whole result table as a list of references to row lists.
# @fill are the fillers for positional parameters in $querystring
#
# ExecSQL executes "die" on failure.
#
sub ExecSQL {
  my ($user, $passwd, $querystring, $type, @fill) =@_;
  if ($debug) { 
    # if we are recording inputs, just push the query string and fill list onto the 
    # global sqlinput list
    push @sqlinput, "$querystring (".join(",",map {"'$_'"} @fill).")";
  }
  my $dbh = DBI->connect("DBI:Oracle:",$user,$passwd);
  if (not $dbh) { 
    # if the connect failed, record the reason to the sqloutput list (if set)
    # and then die.
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't connect to the database because of ".$DBI::errstr."</b>";
    }
    die "Can't connect to database because of ".$DBI::errstr;
  }
  my $sth = $dbh->prepare($querystring);
  if (not $sth) { 
    #
    # If prepare failed, then record reason to sqloutput and then die
    #
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't prepare '$querystring' because of ".$DBI::errstr."</b>";
    }
    my $errstr="Can't prepare $querystring because of ".$DBI::errstr;
    $dbh->disconnect();
    die $errstr;
  }
  if (not $sth->execute(@fill)) { 
    #
    # if exec failed, record to sqlout and die.
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't execute '$querystring' with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr."</b>";
    }
    my $errstr="Can't execute $querystring with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr;
    $dbh->disconnect();
    die $errstr;
  }
  #
  # The rest assumes that the data will be forthcoming.
  #
  #
  my @data;
  if (defined $type and $type eq "ROW") { 
    @data=$sth->fetchrow_array();
    $sth->finish();
    if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","ROW",undef,@data);}
    $dbh->disconnect();
    return @data;
  }
  my @ret;
  while (@data=$sth->fetchrow_array()) {
    push @ret, [@data];
  }
  if (defined $type and $type eq "COL") { 
    @data = map {$_->[0]} @ret;
    $sth->finish();
    if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","COL",undef,@data);}
    $dbh->disconnect();
    return @data;
  }
  $sth->finish();
  if ($debug) {push @sqloutput, MakeTable("debug_sql_output","2D",undef,@ret);}
  $dbh->disconnect();
  return @ret;
}


######################################################################
#
# Nothing important after this
#
######################################################################

# The following is necessary so that DBD::Oracle can
# find its butt
#
BEGIN {
  unless ($ENV{BEGIN_BLOCK}) {
    use Cwd;
    $ENV{ORACLE_BASE}="/raid/oracle11g/app/oracle/product/11.2.0.1.0";
    $ENV{ORACLE_HOME}=$ENV{ORACLE_BASE}."/db_1";
    $ENV{ORACLE_SID}="CS339";
    $ENV{LD_LIBRARY_PATH}=$ENV{ORACLE_HOME}."/lib";
    $ENV{BEGIN_BLOCK} = 1;
    exec 'env',cwd().'/'.$0,@ARGV;
  }
}

