var centre_lat, centre_long, map, map_div_id;
var positions = [], markers = [];

var gicon = L.Icon.extend( {
    iconUrl: 'http://maps.google.com/mapfiles/ms/micons/red-dot.png',
    shadowUrl: null,
    iconSize: new L.Point( 32, 32 ),
    iconAnchor: new L.Point( 15, 32 ),
    popupAnchor: new L.Point( 0, -40 )
} );

$(
  function() {
    if ( map_div_id && centre_lat && centre_long ) {
      map = new L.Map( map_div_id );
      var map_centre = new L.LatLng( centre_lat, centre_long );

      var mq_url = 'http://{s}.mqcdn.com/tiles/1.0.0/osm/{z}/{x}/{y}.png';
      var subdomains = [ 'otile1', 'otile2', 'otile3', 'otile4' ];
      var attrib = 'Data, imagery and map information provided by <a href="http://open.mapquest.co.uk" target="_blank">MapQuest</a>, <a href="http://www.openstreetmap.org/" target="_blank">OpenStreetMap</a> and contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/" target="_blank">CC-BY-SA</a>';

      var tile_layer = new L.TileLayer( mq_url, { maxZoom: 18, attribution: attrib, subdomains: subdomains } );

      map.setView( map_centre, 13 ).addLayer( tile_layer );

      add_markers();
    }
  }
);

function add_marker( i, node ) {
  var content, marker, position;

  // This should have already been checked, but no harm in checking again.
  if ( !node.lat || !node.long ) {
    return;
  }

  position = new L.LatLng( node.lat, node.long );

  marker = new L.Marker( position, { icon: new gicon() } );
  map.addLayer( marker );

  content = '<a href="?' + node.param + '">' + node.name + '</a><br />' + node.address;
  marker.bindPopup( content );

  markers[ i ] = marker;
  positions[ i ] = position;
}

function show_marker( i ) {
  markers[ i ].openPopup();
  map.panTo( positions[ i ] );
  return false;
}
