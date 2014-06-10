//
// Global state
//
// map     - the map object
// usermark- marks the user's position on the map
// markers - list of markers on the current map (not including the user position)
// 
//

//
// First time run: request current location, with callback to Start
//
if (navigator.geolocation)  {
    navigator.geolocation.getCurrentPosition(Start);
}


function UpdateMapById(id, tag) {

    var target = document.getElementById(id);
    var data = target.innerHTML;

    var rows  = data.split("\n");
   
    for (i in rows) {
	var cols = rows[i].split("\t");
	var lat = cols[0];
	var long = cols[1];

	markers.push(new google.maps.Marker({ map:map,
						    position: new google.maps.LatLng(lat,long),
						    title: tag+"\n"+cols.join("\n")}));
	
    }
}

function ClearMarkers()
{
    // clear the markers
    while (markers.length>0) { 
	markers.pop().setMap(null);
    }
}


function UpdateMap()
{
    var color = document.getElementById("color");
    
    color.innerHTML="<b><blink>Updating Display...</blink></b>";
    color.style.backgroundColor='white';

    ClearMarkers();
    
    if (checkbox1.checked)
    UpdateMapById("committee_data","COMMITTEE");
    if (checkbox2.checked)
    UpdateMapById("candidate_data","CANDIDATE");
    if (checkbox3.checked)
    UpdateMapById("individual_data", "INDIVIDUAL");
    if (checkbox4.checked)
    UpdateMapById("opinion_data","OPINION");


    color.innerHTML="Ready";
    

	$('#comm_sum').html($('#sum_comm').html());
	$('#indi_sum').html($('#sum_indi').html());
	$('#opin_sum').html($('#sum_opin').html());
$('#result_ele').html($('#ele_result').html());
}

function NewData(data)
{
  var target = document.getElementById("data");
  
  target.innerHTML = data;

  UpdateMap();

}




//Get the cycles that user select
function GetCycles() {
  var cycle_get = document.getElementById('selectcycle');
  var x = 0;
  var arr = [];
  for (x=0;x<cycle_get.options.length;x++) {
    if (cycle_get.options[x].selected == true) {
      arr.push(cycle_get.options[x].value);
    }
  }
  var strs = arr.toString(); 
  console.log(strs);
  return strs;
}


function ViewShift()
{
    var bounds = map.getBounds();

    var ne = bounds.getNorthEast();
    var sw = bounds.getSouthWest();

    var color = document.getElementById("color");

    color.innerHTML="<b><blink>Querying...("+ne.lat()+","+ne.lng()+") to ("+sw.lat()+","+sw.lng()+")</blink></b>";
    color.style.backgroundColor='white';
    
    //Check what does the user select and add them to string1 used to set &what
    var string1 = "";  
    if (checkbox1.checked)
    string1 += "committees,";
    if (checkbox2.checked)
    string1 += "candidates,";
    if (checkbox3.checked)
    string1 += "individuals,";
    if (checkbox4.checked)
    string1 += "opinions,";
   
    //Get rid of the last comma
    string1 = string1.substring(0,string1.length - 1) ; 
   
    //Pass the selected cycle to cycle1 whose value will be used in SQL queries
    var cycle1 = GetCycles();
    console.log(cycle1);
 
    // debug status flows through by cookie
    $.get("rwb.pl?act=near&latne="+ne.lat()+"&longne="+ne.lng()+"&latsw="+sw.lat()+"&longsw="+sw.lng()+"&format=raw&what="+string1+"&cycle="+cycle1, NewData);
}

/*
function Setpos(pos)
{
  var lat=pos.coords.latitude;
  var long=pos.coords.longitude;
  if ($('#lat').length ==0 ){
      $('#lat').valur=lat;
  }
  if ($('#long').length ==0 ){
      $('#long').value=long;
  }
}
*/
function Reposition(pos)
{
    var lat=pos.coords.latitude;
    var long=pos.coords.longitude;

    map.setCenter(new google.maps.LatLng(lat,long));
    usermark.setPosition(new google.maps.LatLng(lat,long));

    document.cookie = 'Location=' + lat +'/'+long;
}


function Start(location) 
{
  var lat = location.coords.latitude;
  var long = location.coords.longitude;
  var acc = location.coords.accuracy;
  
  var mapc = $( "#map");

  map = new google.maps.Map(mapc[0], 
			    { zoom:16, 
				center:new google.maps.LatLng(lat,long),
				mapTypeId: google.maps.MapTypeId.HYBRID
				} );

  usermark = new google.maps.Marker({ map:map,
					    position: new google.maps.LatLng(lat,long),
					    title: "You are here"});

  document.cookie = 'Location=' + lat +'/'+long;

  markers = new Array;

  var color = document.getElementById("color");
  color.style.backgroundColor='white';
  color.innerHTML="<b><blink>Waiting for first position</blink></b>";

  google.maps.event.addListener(map,"bounds_changed",ViewShift);
  google.maps.event.addListener(map,"center_changed",ViewShift);
  google.maps.event.addListener(map,"zoom_changed",ViewShift);

  navigator.geolocation.watchPosition(Reposition);
 // navigator.geolocation.watchPosition(Setpos);

}


